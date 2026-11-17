pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Sylenara.Config
import Sylenara.I18n
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen

    readonly property int activityCount: Math.max(1, Activities.mappedActivities.length)
    // Larger previews: use most of the available width across activities
    readonly property real cardWidth: {
        const sidePad = Tokens.padding.extraLarge * 4;
        const gaps = Tokens.spacing.large * Math.max(0, activityCount - 1);
        const perAct = (width - sidePad - gaps) / activityCount;
        // As large as the width allows, but the desktops of the busiest activity must fit in the height
        const byWidth = perAct * 0.85 - Tokens.padding.large * 2;
        let most = 1;
        for (const a of Activities.mappedActivities)
            most = Math.max(most, a.workspaceCount);
        const aspect = Activities.monitorBounds.w / Math.max(1, Activities.monitorBounds.h);
        const avail = height * 0.88 - Tokens.padding.large * 4 - 120;
        const byHeight = (avail / most - 40) * aspect;
        return Math.max(220, Math.min(720, byWidth, byHeight));
    }

    // Same translucent surface + Hyprland blur as shell drawers with Transparency on.
    // No hover tint — it would shift the whole backdrop when moving over cards/windows.
    StyledRect {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3surface, Colours.transparency.base)

        MouseArea {
            anchors.fill: parent
            onClicked: Activities.closeOverview()
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Tokens.padding.extraLarge * 2, row.implicitWidth)
        spacing: Tokens.spacing.large

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            // No close button: a click outside the activities (or Esc) closes it
            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Activities overview")
                font: Tokens.font.headline.small
                color: Colours.palette.m3onSurface
            }
        }

        Row {
            id: row

            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.large

            Repeater {
                model: Activities.mappedActivities

                StyledRect {
                    id: actCard

                    required property var modelData
                    readonly property bool isCurrent: Activities.currentActivity?.id === modelData?.id

                    width: root.cardWidth + Tokens.padding.large * 2
                    height: actCol.implicitHeight + Tokens.padding.large * 2
                    radius: Tokens.rounding.extraLarge
                    // Current activity: soft primaryContainer; others stay surface.
                    color: actCard.isCurrent
                           ? Colours.layer(Colours.palette.m3primaryContainer, 1)
                           : Colours.tPalette.m3surfaceContainerHigh
                    border.width: 1
                    border.color: actCard.isCurrent ? Qt.alpha(Colours.palette.m3primary, 0.45) : Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

                    Behavior on color {
                        CAnim {}
                    }

                    // Grows when a desktop is added
                    Behavior on height {
                        Anim {}
                    }

                    ActivityColumn {
                        id: actCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.large
                        screen: root.screen
                        activity: actCard.modelData
                        cardWidth: root.cardWidth
                    }
                }
            }
        }
    }

    // Reparented window previews live here while dragging between desktops
    Item {
        id: dragLayer

        anchors.fill: parent
        z: 1000
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            Activities.closeOverview();
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        Activities.overviewDragLayer = dragLayer;
        forceActiveFocus();
    }

    Component.onDestruction: {
        if (Activities.overviewDragLayer === dragLayer)
            Activities.overviewDragLayer = null;
    }
}
