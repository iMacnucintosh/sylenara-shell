pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Sylenara.Config
import Sylenara.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property int wsId
    required property real cardWidth

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool isActive: Activities.activeDesktop === wsId
    // The windows on this desktop, on any monitor
    readonly property var windows: Hypr.toplevels.values.filter(t => t.workspace && Activities.desktopOf(t.workspace.id) === wsId && !Hypr.isToplevelIgnored(t, GlobalConfig.bar.workspaces.ignoredTags))
    // The shape of all the monitors together, as they are placed in Settings
    readonly property real aspect: Activities.monitorBounds.w / Math.max(1, Activities.monitorBounds.h)

    // An empty desktop can be removed, unless an app is pinned to it (open or not) or it is the last one of its
    // activity
    readonly property bool canRemove: windows.length === 0 && !Activities.wsHasRule(wsId) && (Activities.activityForWs(wsId)?.workspaceCount ?? 1) > 1

    implicitWidth: cardWidth
    implicitHeight: cardWidth / Math.max(0.5, aspect)

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.extraSmall

        Rectangle {
            id: cardFrame

            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            color: "transparent"
            border.width: root.isActive ? 2 : 1
            border.color: root.isActive ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

            Behavior on border.color {
                CAnim {}
            }

            ClipRect {
                id: card

                anchors.fill: parent
                anchors.margins: cardFrame.border.width
                radius: Math.max(0, Tokens.rounding.large - anchors.margins)
                color: (root.isActive ? Colours.layer(Colours.palette.m3secondaryContainer, 1)
                       : Colours.tPalette.m3surfaceContainerHighest)

                Behavior on color {
                    CAnim {}
                }

                MouseArea {
                    anchors.fill: parent
                    z: 0
                    onClicked: Activities.selectWorkspace(root.wsId)
                }

                Item {
                    id: board

                    anchors.fill: parent
                    z: 1

                    // Pixels of the card for each pixel of the screens
                    readonly property real unit: width / Math.max(1, Activities.monitorBounds.w)

                    Repeater {
                        model: Activities.monitorRects

                        MonitorPane {
                            required property var modelData
                            required property int index

                            monitor: modelData.monitor
                            desktop: root.wsId
                            multi: Activities.monitorRects.length > 1
                            number: index + 1
                            x: (modelData.x - Activities.monitorBounds.x) * board.unit
                            y: (modelData.y - Activities.monitorBounds.y) * board.unit
                            width: modelData.w * board.unit
                            height: modelData.h * board.unit
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: root.windows.length === 0 && Activities.monitorRects.length < 2
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "desktop_windows"
                            color: Colours.palette.m3outline
                            fontStyle: Tokens.font.icon.large
                            opacity: 0.85
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Tr.tr("Empty")
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.medium
                        }
                    }
                }
            }
        }
    }

    HoverHandler {
        id: cardHover
    }

    // Remove badge (a minus): on the top right corner, a little outside of the card, like a notification badge. Only on hover,
    // and only when the desktop has no windows
    IconButton {
        id: removeBadge

        readonly property bool shown: root.canRemove && (cardHover.hovered || hovered)

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -Math.round(implicitHeight / 3)
        anchors.rightMargin: -Math.round(implicitWidth / 3)
        z: 20
        icon: "remove"
        tooltip: Tr.tr("Remove desktop")
        type: IconButton.Filled
        isRound: true
        font: Tokens.font.icon.small
        padding: Tokens.padding.extraSmall
        // Discreet: a neutral surface with a hairline, not an alarm colour
        inactiveColour: Colours.palette.m3surfaceContainerHighest
        inactiveOnColour: Colours.palette.m3onSurfaceVariant
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outline, 0.5)
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.6
        visible: opacity > 0
        onClicked: {
            const act = Activities.activityForWs(root.wsId);
            if (act)
                Activities.removeDesktop(act.id, root.wsId);
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    // A desktop just added from the overview grows in
    ParallelAnimation {
        id: enterAnim

        Anim {
            target: root
            property: "opacity"
            from: 0
            to: 1
            type: Anim.DefaultEffects
        }

        Anim {
            target: root
            property: "scale"
            from: 0.82
            to: 1
        }
    }

    Component.onCompleted: {
        if (Activities.addedWs === root.wsId)
            enterAnim.start();
    }
}
