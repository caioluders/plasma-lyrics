# Synced Lyrics

A KDE Plasma 6 widget that shows time-synced lyrics for whatever is playing.

- **In a panel** it shows the line being sung right now.
- **On the desktop, or in the panel popup,** it shows the full lyrics, scrolling with the song.

It follows the same player as Plasma's own Media Player widget, so it works with
anything that speaks MPRIS: Spotify, browsers, mpv, VLC, Elisa, Strawberry and so on.
Lyrics come from [LRCLIB](https://lrclib.net) — no account or API key needed.

<!-- Add a screenshot here before publishing: ![Screenshot](screenshot.png) -->

## Features

- Synced lyrics with the current line highlighted and kept centred
- Click any line to jump to that point in the song
- Falls back to plain lyrics when no synced version exists
- Cleans up messy browser titles (`Artist - Song (Official Video)`) before searching
- Middle-click the panel text to play/pause
- Copy lyrics to the clipboard
- Settings for panel width, alignment, text size, accent colour and timing offset

## Install

Requires Plasma 6.

```sh
git clone https://github.com/caioluders/plasma-lyrics
cd plasma-lyrics
make install
```

Then right-click the desktop or a panel → *Add or Manage Widgets* → search for
**Synced Lyrics**. To remove it: `make uninstall`.

Without `make`:

```sh
kpackagetool6 -t Plasma/Applet -i package
```

## Settings

Right-click the widget → *Configure Synced Lyrics…*

| Setting | What it does |
| --- | --- |
| Show | Current lyric line, or just an icon, in the panel |
| Width | Space the lyric line takes in the panel |
| Show the track title… | What to display between lines or when there are no synced lyrics |
| Alignment / Text size | Layout of the full lyrics view |
| Use the accent colour | Colour the current line with your accent colour |
| Offset | Shift lyrics earlier (positive) or later (negative), e.g. for Bluetooth delay |

## Privacy

To find lyrics, the widget sends the title, artist, album and length of each
track to lrclib.net. Nothing else is sent, and nothing is stored on disk.

## Limitations

- Lyrics are only as good as LRCLIB's database; some tracks have plain lyrics only, or none.
- Browser playback reports whatever the site calls the video, so matches for
  uploads with unusual titles can miss.
- Vertical panels show an icon rather than the lyric line.

## Development

```sh
make run       # install and open in a standalone window
make test      # unit tests for the matching/parsing code (needs Node.js)
make package   # build the .plasmoid file for store.kde.org
```

QML errors are logged to the journal: `journalctl --user -f`.

Layout:

- `package/contents/ui/main.qml` — player tracking, lyric fetching, timing
- `package/contents/ui/CompactRepresentation.qml` — panel view
- `package/contents/ui/FullRepresentation.qml` — desktop / popup view
- `package/contents/ui/ConfigGeneral.qml` — settings page
- `package/contents/code/lyrics.js` — LRC parsing, title cleanup, result matching

## License

MIT — see [LICENSE](LICENSE).
