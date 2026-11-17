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

// What one monitor shows on one desktop, drawn to scale: its windows where they are on the screen. A card of the
// overview has one of these for each monitor, placed as the monitors are in Settings → Display.
Item {
    id: root

    required property var monitor // HyprlandMonitor
    required property int desktop
    // More than one monitor in the card: each pane gets its own frame and a number
    property bool multi: false
    property int number: 1

    // The workspace this desktop has on this monitor
    readonly property int wsId: Activities.wsFor(desktop, monitor?.name ?? "")
    readonly property var windows: Hypr.toplevelsForWs(wsId)
    readonly property bool dropHover: Activities.overviewDropTargetWs === wsId
    readonly property var rect: Activities.logicalRect(monitor)
    readonly property real mx: rect.x
    readonly property real my: rect.y
    readonly property real lw: rect.w
    readonly property real lh: rect.h

    function containsDragPoint(globalPos: point): bool {
        const local = mapFromGlobal(globalPos.x, globalPos.y);
        return local.x >= 0 && local.y >= 0 && local.x <= width && local.y <= height;
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.multi ? 1 : 0
        radius: root.multi ? Tokens.rounding.small : 0
        color: root.dropHover ? Colours.palette.m3tertiaryContainer : (root.multi ? Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.35) : "transparent")
        border.width: root.multi ? 1 : 0
        border.color: root.dropHover ? Colours.palette.m3tertiary : Qt.alpha(Colours.palette.m3outlineVariant, 0.8)

        Behavior on color {
            CAnim {}
        }
    }

    MaterialIcon {
        visible: root.multi && root.windows.length === 0
        anchors.centerIn: parent
        text: "desktop_windows"
        color: Colours.palette.m3outline
        fontStyle: Tokens.font.icon.large
        opacity: 0.5
    }

    // The number of the monitor, as Identify shows it
    StyledText {
        visible: root.multi
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Tokens.padding.small
        z: 5
        text: String(root.number)
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
    }

    Item {
        id: stage

        anchors.fill: parent
        anchors.margins: root.multi ? 2 : Tokens.padding.extraSmall
        clip: true
        z: 1

        Repeater {
            model: root.windows

            Item {
                id: winItem

                required property var modelData

                readonly property var toplevel: modelData
                readonly property var ipc: modelData.lastIpcObject
                readonly property bool pinned: Activities.isWindowPinned(modelData)
                readonly property int clientPid: Number(ipc?.pid) || 0
                readonly property string clientClass: String(ipc?.class || "")
                // Depend on Audio.streams so mute chips refresh when apps start/stop audio.
                readonly property var audioStreams: {
                    const _ = Audio.streams;
                    return Audio.streamsForClient(clientPid, clientClass);
                }
                readonly property bool hasAudio: audioStreams.length > 0
                readonly property bool audioMuted: {
                    const streams = audioStreams;
                    if (streams.length === 0)
                        return false;
                    // Read each stream's muted so the binding tracks PipeWire updates.
                    for (let i = 0; i < streams.length; i++) {
                        if (!streams[i]?.audio?.muted)
                            return false;
                    }
                    return true;
                }
                readonly property real monX: root.mx
                readonly property real monY: root.my
                readonly property real monW: Math.max(1, root.lw)
                readonly property real monH: Math.max(1, root.lh)
                readonly property real layoutX: ((ipc?.at?.[0] ?? 0) - monX) / monW * stage.width
                readonly property real layoutY: ((ipc?.at?.[1] ?? 0) - monY) / monH * stage.height

                property bool dragging
                property bool didDrag
                property Item homeParent: stage

                width: Math.max(8, ((ipc?.size?.[0] ?? monW) / monW) * stage.width)
                height: Math.max(8, ((ipc?.size?.[1] ?? monH) / monH) * stage.height)
                z: dragging ? 100 : (dragArea.containsMouse ? 10 : 1)
                opacity: dragging ? 0.9 : (pinned ? 0.88 : 1)
                scale: dragging ? 1.06 : (dragArea.containsMouse ? 1.04 : 1)

                Binding on x {
                    when: !winItem.dragging
                    value: winItem.layoutX
                }

                Binding on y {
                    when: !winItem.dragging
                    value: winItem.layoutY
                }

                Behavior on scale {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                function beginDrag(): void {
                    if (pinned)
                        return;
                    const layer = Activities.overviewDragLayer;
                    if (!layer)
                        return;
                    const pos = mapToItem(layer, 0, 0);
                    homeParent = parent;
                    parent = layer;
                    x = pos.x;
                    y = pos.y;
                    dragging = true;
                }

                function updateDropTarget(): void {
                    const layer = Activities.overviewDragLayer;
                    if (!layer)
                        return;
                    const center = Qt.point(winItem.x + winItem.width / 2, winItem.y + winItem.height / 2);
                    const global = layer.mapToGlobal(center.x, center.y);
                    // Walk overview cards via drag layer siblings' content — use registered cards
                    Activities.overviewDropTargetWs = Activities.hitTestOverviewWorkspace(global) ?? -1;
                }

                function endDrag(): void {
                    const tl = winItem.toplevel;
                    dragging = false;
                    if (homeParent)
                        parent = homeParent;
                    if (didDrag)
                        Activities.finishWindowDrag(tl);
                    Activities.overviewDropTargetWs = -1;
                }

                ClipRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.extraSmall
                    color: Colours.tPalette.m3surfaceContainerLowest

                    ScreencopyView {
                        anchors.centerIn: parent
                        captureSource: winItem.modelData?.wayland ?? null
                        live: Activities.overviewOpen && root.visible && !winItem.dragging
                        constraintSize.width: winItem.width
                        constraintSize.height: winItem.height
                    }

                    // Soft hover glow
                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.rounding.extraSmall
                        color: Colours.palette.m3primary
                        opacity: dragArea.containsMouse && !winItem.dragging ? 0.16 : 0

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }

                    MaterialIcon {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 2
                        visible: winItem.pinned
                        text: "push_pin"
                        fill: 1
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small

                        // A little shadow, so it stands out over any window preview
                        layer.enabled: visible
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Colours.palette.m3shadow
                            shadowOpacity: 0.75
                            shadowBlur: 0.5
                            shadowVerticalOffset: 1
                        }
                    }
                }

                MouseArea {
                    id: dragArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: winItem.pinned ? Qt.ForbiddenCursor : (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                    preventStealing: true

                    property real pressX
                    property real pressY
                    property real grabOffsetX
                    property real grabOffsetY
                    readonly property real dragThreshold: 10

                    function moveToCursor(mouse: var): void {
                        const layer = Activities.overviewDragLayer;
                        if (!layer || !winItem.dragging)
                            return;
                        const p = mapToItem(layer, mouse.x, mouse.y);
                        winItem.x = p.x - grabOffsetX;
                        winItem.y = p.y - grabOffsetY;
                        winItem.updateDropTarget();
                    }

                    onPressed: mouse => {
                        winItem.didDrag = false;
                        pressX = mouse.x;
                        pressY = mouse.y;
                        grabOffsetX = mouse.x;
                        grabOffsetY = mouse.y;
                    }

                    onPositionChanged: mouse => {
                        if (winItem.pinned || !pressed)
                            return;
                        if (!winItem.dragging) {
                            const dist = Math.hypot(mouse.x - pressX, mouse.y - pressY);
                            if (dist <= dragThreshold)
                                return;
                            winItem.didDrag = true;
                            winItem.beginDrag();
                        }
                        moveToCursor(mouse);
                    }

                    onReleased: {
                        if (winItem.pinned) {
                            Activities.selectWorkspace(root.desktop);
                            return;
                        }
                        const moved = winItem.didDrag;
                        winItem.endDrag();
                        if (!moved)
                            Activities.selectWorkspace(root.desktop);
                        winItem.didDrag = false;
                    }

                    onCanceled: {
                        winItem.dragging = false;
                        if (winItem.homeParent)
                            winItem.parent = winItem.homeParent;
                        Activities.overviewDropTargetWs = -1;
                        winItem.didDrag = false;
                    }
                }

                // Above dragArea so mute clicks are not eaten by window drag.
                Rectangle {
                    id: muteChip

                    // Flush to the thumbnail corner: square on the outer edges
                    // (a bottom-left radius left a 1px preview hairline under the chip).
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -1
                    anchors.leftMargin: -1
                    width: muteIcon.implicitWidth + 5
                    height: muteIcon.implicitHeight + 5
                    topRightRadius: Tokens.rounding.small
                    visible: winItem.hasAudio && !winItem.dragging
                    color: winItem.audioMuted
                           ? Colours.palette.m3errorContainer
                           : Colours.palette.m3secondaryContainer
                    opacity: (dragArea.containsMouse || muteMa.containsMouse) ? 1 : 0.88
                    z: 20

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Behavior on color {
                        CAnim {}
                    }

                    MaterialIcon {
                        id: muteIcon

                        anchors.centerIn: parent
                        text: winItem.audioMuted ? "volume_off" : "volume_up"
                        color: winItem.audioMuted
                               ? Colours.palette.m3onErrorContainer
                               : Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.small
                    }

                    MouseArea {
                        id: muteMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: Audio.toggleClientMuted(winItem.clientPid, winItem.clientClass)
                    }
                }
            }
        }

    }

    Component.onCompleted: Activities.registerOverviewCard(root)
    Component.onDestruction: Activities.unregisterOverviewCard(root)
}
