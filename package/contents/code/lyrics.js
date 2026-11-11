.pragma library

// Pure helpers: no QML access, so they can be unit-tested outside Plasma.
// Keep to conservative JavaScript — the QML engine lacks some newer
// built-ins (e.g. String.prototype.matchAll).

var API = "https://lrclib.net/api/";

// "[01:23.45] text" -> [{ t: seconds, text }], sorted by time.
// A line may carry several timestamps (repeated chorus).
function parseLrc(lrc) {
    var out = [];
    var rows = String(lrc).split(/\r?\n/);
    for (var i = 0; i < rows.length; i++) {
        var raw = rows[i];
        var text = raw.replace(/\[[^\]]*\]/g, "").replace(/<\d+:\d+(\.\d+)?>/g, "").trim();
        var stamp = /\[(\d+):(\d+(?:[.:]\d+)?)\]/g;
        var m;
        while ((m = stamp.exec(raw)) !== null)
            out.push({ t: parseInt(m[1], 10) * 60 + parseFloat(m[2].replace(":", ".")), text: text });
    }
    out.sort(function (a, b) { return a.t - b.t; });
    return out;
}

function parsePlain(text) {
    return String(text).split(/\r?\n/).map(function (line) {
        return { t: -1, text: line.trim() };
    });
}

// Index of the last line starting at or before `position` (seconds), or -1.
function lineAt(lines, position) {
    var lo = 0, hi = lines.length - 1, found = -1;
    while (lo <= hi) {
        var mid = (lo + hi) >> 1;
        if (lines[mid].t <= position) {
            found = mid;
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }
    return found;
}

// Strip the noise browsers and streaming sites add to titles:
// "Song (Official Video) [4K]" -> "Song"
function cleanTitle(title) {
    var noise = "official|video|audio|lyric|visuali[sz]er|remaster|\\bhd\\b|\\bhq\\b|\\b4k\\b|\\bmv\\b|explicit|clip officiel|videoclipe|legendado";
    return String(title)
        .replace(new RegExp("\\s*[\\(\\[][^\\)\\]]*(" + noise + ")[^\\)\\]]*[\\)\\]]", "gi"), "")
        .replace(/\s*[\(\[]\s*(feat|ft|with)\b\.?[^\)\]]*[\)\]]/gi, "")
        .replace(/\s+(feat|ft)\.?\s.*$/i, "")
        .replace(/\s+-\s+(remaster(ed)?|single version|radio edit|mono|stereo)\b.*$/i, "")
        .replace(/\s*\|.*$/, "")
        .replace(/\s+/g, " ")
        .trim();
}

// "Queen - Topic" / "QueenVEVO" -> "Queen"
function cleanArtist(artist) {
    return String(artist)
        .replace(/\s+-\s+Topic$/i, "")
        .replace(/\s*VEVO$/i, "")
        .replace(/\s+/g, " ")
        .trim();
}

function normalize(text) {
    return String(text).toLowerCase().replace(/[\s\-_.,!?'"`´’‘“”()\[\]{}:;&\/\\|*#~]+/g, "");
}

function encode(params) {
    var parts = [];
    for (var key in params) {
        if (params[key] !== "" && params[key] !== undefined)
            parts.push(key + "=" + encodeURIComponent(params[key]));
    }
    return parts.join("&");
}

// Ordered lookups, most precise first. Each is { url, title } where `title`
// (if set) is what a result's track name must resemble to be accepted.
function buildRequests(track, artist, album, duration) {
    var requests = [];
    var seen = {};
    function add(path, params, title) {
        var url = API + path + "?" + encode(params);
        if (!seen[url]) {
            seen[url] = true;
            requests.push({ url: url, title: title });
        }
    }

    var title = cleanTitle(track) || track;
    var by = cleanArtist(artist);

    // 1. Exact signature, as tagged music players report it
    if (artist && duration > 0)
        add("get", { track_name: track, artist_name: artist, album_name: album, duration: Math.round(duration) }, "");

    // 2. Cleaned-up fields
    if (by)
        add("search", { track_name: title, artist_name: by }, title);

    // 3. Video-style "Artist - Song" titles, where the "artist" is a channel
    var dash = title.split(/\s+[-–—]\s+/);
    if (dash.length === 2 && dash[0] && dash[1])
        add("search", { track_name: dash[1], artist_name: dash[0] }, dash[1]);

    // 4. Free-text fallback
    add("search", { q: by && normalize(title).indexOf(normalize(by)) < 0 ? title + " " + by : title }, title);

    return requests;
}

function resembles(a, b) {
    var x = normalize(a), y = normalize(b);
    if (x.length < 2 || y.length < 2)
        return x === y;
    return x.indexOf(y) >= 0 || y.indexOf(x) >= 0;
}

// Pick the best record from a /get object or a /search array.
// Synced lyrics win unless their duration is clearly a different recording.
function pickBest(data, duration, title) {
    if (!data)
        return null;
    var list = Array.isArray(data) ? data : [data];
    var best = null, bestScore = Infinity;
    for (var i = 0; i < list.length; i++) {
        var r = list[i];
        if (!r || !(r.syncedLyrics || r.plainLyrics || r.instrumental))
            continue;
        if (title && !resembles(r.trackName || r.name || "", title))
            continue;
        var off = duration > 0 && r.duration > 0 ? Math.abs(r.duration - duration) : 0;
        var score = off + (r.syncedLyrics ? 0 : 15) + (r.instrumental ? 30 : 0) + i * 0.01;
        if (score < bestScore) {
            best = r;
            bestScore = score;
        }
    }
    if (!best)
        return null;
    // Timestamps from a different cut would be worse than no timestamps
    var usableSync = best.syncedLyrics && !(duration > 0 && best.duration > 0 && Math.abs(best.duration - duration) > 10);
    if (usableSync)
        return { kind: "synced", lines: parseLrc(best.syncedLyrics) };
    if (best.plainLyrics)
        return { kind: "plain", lines: parsePlain(best.plainLyrics) };
    if (best.syncedLyrics)
        return { kind: "plain", lines: parseLrc(best.syncedLyrics).map(function (l) { return { t: -1, text: l.text }; }) };
    return { kind: "instrumental", lines: [] };
}

function toText(lines) {
    return lines.map(function (l) { return l.text; }).join("\n");
}
