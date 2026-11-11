import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_panelMode: panelMode.currentIndex
    property alias cfg_panelWidth: panelWidth.value
    property alias cfg_showTitleFallback: showTitleFallback.checked
    property alias cfg_alignment: alignment.currentIndex
    property alias cfg_fontScale: fontScale.value
    property alias cfg_accentHighlight: accentHighlight.checked
    property alias cfg_offsetMs: offsetMs.value

    // Plasma hands every page the defaults too; declaring them keeps the log quiet
    property int cfg_panelModeDefault
    property int cfg_panelWidthDefault
    property bool cfg_showTitleFallbackDefault
    property int cfg_alignmentDefault
    property int cfg_fontScaleDefault
    property bool cfg_accentHighlightDefault
    property int cfg_offsetMsDefault

    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Panel")
        }

        QQC2.ComboBox {
            id: panelMode
            Kirigami.FormData.label: i18n("Show:")
            model: [i18n("Current lyric line"), i18n("Icon only")]
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Width:")
            enabled: panelMode.currentIndex === 0

            QQC2.SpinBox {
                id: panelWidth
                from: 6
                to: 80
            }
            QQC2.Label {
                text: i18n("grid units")
                opacity: 0.7
            }
        }

        QQC2.CheckBox {
            id: showTitleFallback
            enabled: panelMode.currentIndex === 0
            text: i18n("Show the track title when there is no lyric line")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Lyrics view")
        }

        QQC2.ComboBox {
            id: alignment
            Kirigami.FormData.label: i18n("Alignment:")
            model: [i18n("Left"), i18n("Centre"), i18n("Right")]
        }

        QQC2.SpinBox {
            id: fontScale
            Kirigami.FormData.label: i18n("Text size:")
            from: 70
            to: 250
            stepSize: 10
            textFromValue: (value, locale) => i18n("%1%", value)
            valueFromText: (text, locale) => parseInt(text)
        }

        QQC2.CheckBox {
            id: accentHighlight
            text: i18n("Use the accent colour for the current line")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Timing")
        }

        QQC2.SpinBox {
            id: offsetMs
            Kirigami.FormData.label: i18n("Offset:")
            from: -10000
            to: 10000
            stepSize: 100
            textFromValue: (value, locale) => i18n("%1 ms", value)
            valueFromText: (text, locale) => parseInt(text)
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Positive values show lyrics earlier. Useful for Bluetooth audio delay.")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Lyrics are provided by LRCLIB (lrclib.net). The title, artist, album and length of each track are sent there to look them up.")
        }
    }
}
