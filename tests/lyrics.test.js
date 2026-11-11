// Run with: node tests/lyrics.test.js
const fs = require("fs");
const path = require("path");
const assert = require("assert");

const file = path.join(__dirname, "../package/contents/code/lyrics.js");
const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
const L = new Function(source + "; return { parseLrc, parsePlain, lineAt, cleanTitle, cleanArtist, buildRequests, pickBest, resembles, toText };")();

// parseLrc
const lrc = "[ti:Song]\n[00:01.50] one\n[00:10.00][00:30.00] chorus\n[00:20.00]\n[01:00:50] colon form";
const lines = L.parseLrc(lrc);
assert.deepStrictEqual(lines.map(l => l.t), [1.5, 10, 20, 30, 60.5]);
assert.deepStrictEqual(lines.map(l => l.text), ["one", "chorus", "", "chorus", "colon form"]);

// lineAt
assert.strictEqual(L.lineAt(lines, 0), -1);
assert.strictEqual(L.lineAt(lines, 1.5), 0);
assert.strictEqual(L.lineAt(lines, 25), 2);
assert.strictEqual(L.lineAt(lines, 999), 4);
assert.strictEqual(L.lineAt([], 5), -1);

// cleaning
assert.strictEqual(L.cleanTitle("Bohemian Rhapsody (Official Video Remastered)"), "Bohemian Rhapsody");
assert.strictEqual(L.cleanTitle("Song [Official Audio] (feat. Someone)"), "Song");
assert.strictEqual(L.cleanTitle("Song ft. Someone"), "Song");
assert.strictEqual(L.cleanTitle("Song - Remastered 2011"), "Song");
assert.strictEqual(L.cleanTitle("Song (Live at Wembley)"), "Song (Live at Wembley)");
assert.strictEqual(L.cleanTitle("Artist - Song (Lyric Video) | Label"), "Artist - Song");
assert.strictEqual(L.cleanArtist("Queen - Topic"), "Queen");
assert.strictEqual(L.cleanArtist("QueenVEVO"), "Queen");

// buildRequests
const tagged = L.buildRequests("Song", "Band", "Album", 200.4);
assert.ok(tagged[0].url.includes("/get?") && tagged[0].url.includes("duration=200"));
assert.ok(tagged.length >= 3);
const video = L.buildRequests("Band - Song (Official Video)", "BandVEVO", "", 200);
assert.ok(video.some(r => r.url.includes("track_name=Song&artist_name=Band") && r.title === "Song"));
assert.strictEqual(new Set(video.map(r => r.url)).size, video.length);
const bare = L.buildRequests("Song", "", "", 0);
assert.strictEqual(bare.length, 1);
assert.ok(bare[0].url.includes("search?q=Song"));

// pickBest
const synced = { trackName: "Song", duration: 200, syncedLyrics: "[00:01.00] a", plainLyrics: "a" };
const plain = { trackName: "Song", duration: 200, plainLyrics: "a\nb" };
const other = { trackName: "Different", duration: 200, syncedLyrics: "[00:01.00] x" };
const longCut = { trackName: "Song", duration: 260, syncedLyrics: "[00:01.00] a", plainLyrics: "a" };
assert.strictEqual(L.pickBest(null, 200, "Song"), null);
assert.strictEqual(L.pickBest([], 200, "Song"), null);
assert.strictEqual(L.pickBest([other], 200, "Song"), null);
assert.strictEqual(L.pickBest([plain, synced], 200, "Song").kind, "synced");
assert.strictEqual(L.pickBest([plain], 200, "Song").lines.length, 2);
assert.strictEqual(L.pickBest([longCut], 200, "Song").kind, "plain");
assert.strictEqual(L.pickBest([longCut, synced], 200, "Song").kind, "synced");
assert.strictEqual(L.pickBest(synced, 0, "").kind, "synced");
assert.strictEqual(L.pickBest({ trackName: "Song", instrumental: true }, 200, "").kind, "instrumental");
assert.strictEqual(L.pickBest([{ trackName: "Song", instrumental: true }, plain], 200, "Song").kind, "plain");

assert.strictEqual(L.toText(L.parsePlain("a\nb")), "a\nb");

console.log("all tests passed");
