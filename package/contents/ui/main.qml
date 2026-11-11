import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import "../code/lyrics.js" as Lyrics

PlasmoidItem {
    id: root

    // ---- Player (whichever one Plasma's own Media Player widget follows) ----
    readonly property var player: mpris.currentPlayer
    readonly property string track: player ? player.track : ""
    readonly property string artist: player ? player.artist : ""
    readonly property string album: player ? player.album : ""
    readonly property real duration: player ? player.length / 1e6 : 0
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool canSeek: !!player && player.canSeek
    readonly property real playerPosition: player ? player.position / 1e6 : 0

    // ---- Lyrics ----
    // idle | loading | synced | plain | instrumental | notfound | error
    property string lyricsState: "idle"
    property var lines: []              // [{ t: seconds or -1, text }]
    property int currentLine: -1
    readonly property bool synced: lyricsState === "synced"
    readonly property real offset: Plasmoid.configuration.offsetMs / 1000

    // ---- Clock: MPRIS only reports position on request, so interpolate ----
    property real position: 0           // seconds, smoothed
    property real basePosition: 0
    property double baseTime: 0

    // ---- Internals ----
    property int serial: 0              // discards replies for a previous track
    property real loadedDuration: 0
    property var cache: ({})
    property int cacheSize: 0

    readonly property string panelText: {
        if (synced && currentLine >= 0)
            return lines[currentLine].text || "♪";
        if (track && Plasmoid.configuration.showTitleFallback)
            return "♪ " + track;
        return "♪";
    }

    Plasmoid.icon: "view-media-lyrics"
    toolTipMainText: track || Plasmoid.title
    toolTipSubText: {
        switch (lyricsState) {
        case "idle": return i18n("Nothing is playing");
        case "loading": return i18n("Looking for lyrics…");
        case "notfound": return i18n("No lyrics found");
        case "error": return i18n("Couldn't reach LRCLIB");
        default: return artist;
        }
    }

    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 6

    compactRepresentation: CompactRepresentation {
        widget: root
    }
    fullRepresentation: FullRepresentation {
        widget: root
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh Lyrics")
            icon.name: "view-refresh"
            enabled: root.track !== ""
            onTriggered: root.reload(true)
        },
        PlasmaCore.Action {
            text: i18n("Copy Lyrics")
            icon.name: "edit-copy"
            enabled: root.lines.length > 0
            onTriggered: root.copyLyrics()
        }
    ]

    Mpris.Mpris2Model {
        id: mpris
    }

    onTrackChanged: debounce.restart()
    onArtistChanged: debounce.restart()
    onDurationChanged: {
        // Players often announce the length a moment after the title
        if (track && (loadedDuration <= 0 || lyricsState === "loading"))
            debounce.restart();
    }
    onPlayerPositionChanged: resync()
    onPlayingChanged: {
        // Freeze (or resume from) the smoothed position, then ask for the real one
        basePosition = position;
        baseTime = Date.now();
        if (player)
            player.updatePosition();
    }
    onOffsetChanged: tick()
    Component.onCompleted: debounce.restart()

    // Title, artist and length arrive as separate signals; let them settle
    Timer {
        id: debounce
        interval: 400
        onTriggered: root.reload(false)
    }

    Timer {
        interval: 100
        repeat: true
        running: root.playing && root.synced
        onTriggered: root.tick()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.playing && root.synced
        triggeredOnStart: true
        onTriggered: root.player.updatePosition()
    }

    // Offscreen helper: QML has no clipboard API of its own
    TextEdit {
        id: clipboard
        visible: false
    }

    function resync() {
        basePosition = playerPosition;
        baseTime = Date.now();
        tick();
    }

    function tick() {
        let now = basePosition;
        if (playing)
            now += (Date.now() - baseTime) / 1000 * (player.rate > 0 ? player.rate : 1);
        position = now;
        currentLine = synced ? Lyrics.lineAt(lines, now + offset) : -1;
    }

    function seekToLine(index) {
        if (!synced || !canSeek || index < 0 || index >= lines.length)
            return;
        player.Seek(Math.round((lines[index].t - offset - position) * 1e6));
        player.updatePosition();
    }

    function copyLyrics() {
        clipboard.text = Lyrics.toText(lines);
        clipboard.selectAll();
        clipboard.copy();
        clipboard.text = "";
    }

    function reload(force) {
        const id = ++serial;
        lines = [];
        currentLine = -1;
        loadedDuration = duration;
        if (!track) {
            lyricsState = "idle";
            return;
        }

        const key = [track, artist, album, Math.round(duration)].join("\u0000");
        if (!force && cache[key]) {
            apply(cache[key]);
            return;
        }

        player.updatePosition(); // the last known position may belong to the previous track
        lyricsState = "loading";
        attempt(id, key, Lyrics.buildRequests(track, artist, album, duration), 0);
    }

    // One request at a time, as LRCLIB asks of its clients
    function attempt(id, key, requests, index) {
        if (index >= requests.length) {
            remember(key, { kind: "notfound", lines: [] });
            apply(cache[key]);
            return;
        }
        const wantedDuration = duration;
        request(requests[index].url, (status, data) => {
            if (id !== serial)
                return;
            if (status !== 200 && status !== 404) {
                lyricsState = "error";
                return;
            }
            const found = Lyrics.pickBest(data, wantedDuration, requests[index].title);
            if (found) {
                remember(key, found);
                apply(found);
            } else {
                attempt(id, key, requests, index + 1);
            }
        });
    }

    function request(url, callback) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let data = null;
            if (xhr.status === 200) {
                try {
                    data = JSON.parse(xhr.responseText);
                } catch (e) {
                    data = null;
                }
            }
            callback(xhr.status, data);
        };
        xhr.open("GET", url);
        xhr.timeout = 15000;
        // LRCLIB asks clients to identify themselves
        const agent = "SyncedLyricsPlasmoid/" + Plasmoid.metaData.version;
        xhr.setRequestHeader("User-Agent", agent);
        xhr.setRequestHeader("X-User-Agent", agent);
        xhr.send();
    }

    function remember(key, result) {
        if (cacheSize >= 200) {
            cache = ({});
            cacheSize = 0;
        }
        if (!cache[key])
            cacheSize++;
        cache[key] = result;
    }

    function apply(result) {
        lines = result.lines;
        lyricsState = result.kind;
        resync();
    }
}
