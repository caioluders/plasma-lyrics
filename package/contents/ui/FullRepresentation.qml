import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: full

    property var widget

    readonly property real fontSize: Kirigami.Theme.defaultFont.pointSize * Plasmoid.configuration.fontScale / 100
    readonly property int textAlignment: [Text.AlignLeft, Text.AlignHCenter, Text.AlignRight][Plasmoid.configuration.alignment] ?? Text.AlignHCenter

    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 28
    Layout.minimumWidth: Kirigami.Units.gridUnit * 10
    Layout.minimumHeight: Kirigami.Units.gridUnit * 6
    spacing: Kirigami.Units.smallSpacing

    // ---- Header: what's playing, plus quick actions ----
    RowLayout {
        Layout.fillWidth: true
        visible: full.widget.track !== ""
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 4
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: full.widget.track
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: text !== ""
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: full.widget.artist
            }
        }

        PlasmaComponents.ToolButton {
            icon.name: "edit-copy"
            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Copy Lyrics")
            visible: full.widget.lines.length > 0
            onClicked: full.widget.copyLyrics()
            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
        PlasmaComponents.ToolButton {
            icon.name: "view-refresh"
            display: PlasmaComponents.AbstractButton.IconOnly
            text: i18n("Refresh Lyrics")
            onClicked: full.widget.reload(true)
            PlasmaComponents.ToolTip.text: text
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }

    // ---- Lyrics ----
    PlasmaComponents.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: list

            clip: true
            model: full.widget.lines
            spacing: Kirigami.Units.smallSpacing
            currentIndex: full.widget.currentLine
            reuseItems: false

            // Keep the current line centred while still allowing manual scrolling
            highlightRangeMode: full.widget.synced ? ListView.ApplyRange : ListView.NoHighlightRange
            preferredHighlightBegin: height / 2 - Kirigami.Units.gridUnit
            preferredHighlightEnd: height / 2 + Kirigami.Units.gridUnit
            highlightMoveDuration: Kirigami.Units.veryLongDuration
            highlightFollowsCurrentItem: true

            delegate: PlasmaComponents.Label {
                id: line

                required property var modelData
                required property int index
                readonly property bool current: full.widget.synced && index === full.widget.currentLine
                readonly property bool seekable: full.widget.synced && full.widget.canSeek

                width: ListView.view.width
                leftPadding: Kirigami.Units.largeSpacing
                rightPadding: Kirigami.Units.largeSpacing
                horizontalAlignment: full.textAlignment
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                text: modelData.text || (full.widget.synced ? "♪" : " ")
                font.pointSize: full.fontSize
                font.bold: current
                color: current && Plasmoid.configuration.accentHighlight ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                opacity: !full.widget.synced || current ? 1 : (hover.hovered && seekable ? 0.8 : 0.5)

                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }

                HoverHandler {
                    id: hover
                    cursorShape: line.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
                TapHandler {
                    enabled: line.seekable
                    onTapped: full.widget.seekToLine(line.index)
                }
            }

            PlasmaComponents.BusyIndicator {
                anchors.centerIn: parent
                visible: full.widget.lyricsState === "loading"
                running: visible
            }

            PlasmaExtras.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 2
                visible: ["idle", "notfound", "error", "instrumental"].includes(full.widget.lyricsState)
                iconName: full.widget.lyricsState === "error" ? "network-disconnect" : "view-media-lyrics"
                text: {
                    switch (full.widget.lyricsState) {
                    case "idle": return i18n("Nothing is playing");
                    case "notfound": return i18n("No lyrics found");
                    case "error": return i18n("Couldn't reach LRCLIB");
                    case "instrumental": return i18n("Instrumental");
                    default: return "";
                    }
                }
                explanation: {
                    switch (full.widget.lyricsState) {
                    case "idle": return i18n("Lyrics appear here when a media player starts.");
                    case "notfound": return i18n("LRCLIB has no match for this title and artist.");
                    case "error": return i18n("Check your connection and try again.");
                    default: return "";
                    }
                }
                helpfulAction: QQC2.Action {
                    enabled: ["notfound", "error"].includes(full.widget.lyricsState)
                    icon.name: "view-refresh"
                    text: i18n("Try Again")
                    onTriggered: full.widget.reload(true)
                }
            }
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: full.widget.lyricsState === "plain"
        horizontalAlignment: Text.AlignHCenter
        font: Kirigami.Theme.smallFont
        opacity: 0.6
        text: i18n("Time-synced lyrics aren't available for this track")
    }
}
