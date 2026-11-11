import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact

    property var widget

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconOnly: vertical || Plasmoid.configuration.panelMode === 1
    readonly property real textWidth: Plasmoid.configuration.panelWidth * Kirigami.Units.gridUnit

    Layout.minimumWidth: iconOnly ? Kirigami.Units.iconSizes.small : Kirigami.Units.gridUnit * 4
    Layout.preferredWidth: iconOnly ? (vertical ? width : height) : textWidth
    Layout.maximumWidth: iconOnly ? Layout.preferredWidth : textWidth
    Layout.minimumHeight: Kirigami.Units.iconSizes.small
    Layout.preferredHeight: vertical ? width : Kirigami.Units.iconSizes.medium

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) {
            if (widget.player)
                widget.player.PlayPause();
        } else {
            widget.expanded = !widget.expanded;
        }
    }

    Kirigami.Icon {
        anchors.fill: parent
        visible: compact.iconOnly
        source: Plasmoid.icon
        active: compact.containsMouse
    }

    PlasmaComponents.Label {
        id: label

        readonly property string target: compact.widget.panelText

        anchors.fill: parent
        visible: !compact.iconOnly
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
        maximumLineCount: 1

        Component.onCompleted: text = target
        onTargetChanged: {
            if (visible)
                swap.restart();
            else
                text = target;
        }

        // Cross-fade between lines (instant when animations are disabled)
        SequentialAnimation {
            id: swap
            NumberAnimation {
                target: label
                property: "opacity"
                to: 0
                duration: Kirigami.Units.shortDuration
            }
            ScriptAction {
                script: label.text = label.target
            }
            NumberAnimation {
                target: label
                property: "opacity"
                to: 1
                duration: Kirigami.Units.shortDuration
            }
        }
    }
}
