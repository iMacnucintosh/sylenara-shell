pragma ComponentBehavior: Bound

import QtQuick
import "../../../utils/scripts/displaylayout.js" as Layout

// The displays drawn where they are on the desk, to be dragged into the arrangement they really have. It knows nothing
// of the theme: colours, fonts and texts come from outside (the Display page), so it can also be tried on its own
// (tests/qml/tst_displaycanvas.qml).
//   layout  [{ name, x, y, w, h }]  what is drawn, in the logical pixels Hyprland positions use
//   labels  { name: { number, title, detail } }
Item {
    id: root

    property var layout: []
    property var labels: ({})
    property string selected
    // The main display, with a star
    property string primary
    property color starColor: "#ffd54f"

    property color canvasColor: "#202020"
    property color tileColor: "#303030"
    property color tileBorderColor: "#707070"
    property color selectedColor: "#5060a0"
    property color selectedBorderColor: "#9fb0ff"
    property color textColor: "#ffffff"
    property color detailColor: "#c0c0c0"
    property color ghostColor: "#9fb0ff"
    property font numberFont
    property font titleFont
    property font detailFont
    property real tileRadius: 12
    property real padding: 16
    property real minimumHeight: 150
    property real maximumHeight: 330

    // Picked: pressed without being moved. Dropped: left at (x, y), the corner of the display in logical pixels.
    signal picked(string name)
    signal primaryPicked(string name)
    signal dropped(string name, real x, real y)

    // The view is fixed while a display is being dragged, so what is under the pointer does not move away
    property string dragName
    property real dragX
    property real dragY
    property var frozen: null

    readonly property var bounds: {
        const list = root.layout ?? [];
        if (list.length === 0)
            return { x: 0, y: 0, w: 1, h: 1 };
        const b = Layout.bounds(list);
        const room = Math.max(...list.map(d => Math.max(d.w, d.h))) * 0.28;
        return { x: b.x - room, y: b.y - room, w: b.w + room * 2, h: b.h + room * 2 };
    }
    readonly property var view: {
        if (root.frozen)
            return root.frozen;
        const wide = Math.max(1, root.width - root.padding * 2);
        const tall = Math.max(1, root.maximumHeight - root.padding * 2);
        const k = Math.min(wide / root.bounds.w, tall / root.bounds.h);
        return { k: k, x: root.bounds.x, y: root.bounds.y, h: root.bounds.h * k + root.padding * 2, w: root.bounds.w * k };
    }

    // Where a dragged display would land if it were dropped now
    readonly property var ghost: {
        if (!root.dragName)
            return null;
        const list = root.layout ?? [];
        const index = list.findIndex(d => d.name === root.dragName);
        return index < 0 ? null : Layout.snap(list, index, root.dragX, root.dragY);
    }

    implicitHeight: Math.max(root.minimumHeight, Math.min(root.maximumHeight, root.view.h))

    function toPixelsX(lx: real): real {
        return (lx - root.view.x) * root.view.k + (root.width - root.view.w) / 2;
    }

    function toPixelsY(ly: real): real {
        return (ly - root.view.y) * root.view.k + (root.height - root.view.h) / 2 + root.padding;
    }

    Rectangle {
        anchors.fill: parent
        radius: root.tileRadius
        color: root.canvasColor
    }

    Rectangle {
        id: ghostTile

        visible: root.ghost !== null
        x: root.ghost ? root.toPixelsX(root.ghost.x) : 0
        y: root.ghost ? root.toPixelsY(root.ghost.y) : 0
        width: ghostTile.tileFor(root.dragName).w * root.view.k
        height: ghostTile.tileFor(root.dragName).h * root.view.k
        radius: root.tileRadius
        color: "transparent"
        border.width: 2
        border.color: root.ghostColor
        opacity: 0.6

        function tileFor(name) {
            return (root.layout ?? []).find(d => d.name === name) ?? { w: 0, h: 0 };
        }
    }

    Repeater {
        model: root.layout

        Rectangle {
            id: tile

            required property var modelData

            readonly property bool dragging: root.dragName === tile.modelData.name
            readonly property bool isSelected: root.selected === tile.modelData.name
            readonly property var info: root.labels[tile.modelData.name] ?? ({})

            objectName: `tile-${tile.modelData.name}`
            x: root.toPixelsX(tile.dragging ? root.dragX : tile.modelData.x)
            y: root.toPixelsY(tile.dragging ? root.dragY : tile.modelData.y)
            width: Math.max(8, tile.modelData.w * root.view.k - 4)
            height: Math.max(8, tile.modelData.h * root.view.k - 4)
            z: tile.dragging ? 2 : 0
            radius: root.tileRadius * 0.7
            color: tile.isSelected ? root.selectedColor : root.tileColor
            border.width: tile.isSelected ? 2 : 1
            border.color: tile.isSelected ? root.selectedBorderColor : root.tileBorderColor
            opacity: tile.dragging ? 0.85 : 1

            Behavior on x {
                enabled: !tile.dragging
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on y {
                enabled: !tile.dragging
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 12
                spacing: 2

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.info.number ?? ""
                    color: root.textColor
                    font: root.numberFont
                    visible: tile.height > 34
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tile.info.title ?? tile.modelData.name
                    color: root.textColor
                    font: root.titleFont
                    visible: tile.height > 62 && tile.width > 50
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tile.info.detail ?? ""
                    color: root.detailColor
                    font: root.detailFont
                    visible: tile.height > 84 && tile.width > 80
                }
            }

            // The star: filled on the main display; a click on another one makes it the main
            Text {
                id: star

                objectName: `star-${tile.modelData.name}`
                z: 3
                visible: tile.height > 34 && tile.width > 34
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                text: root.primary === tile.modelData.name ? "★" : "☆"
                color: root.primary === tile.modelData.name ? root.starColor : root.detailColor
                font.pixelSize: 18

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: star.visible
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.primaryPicked(tile.modelData.name)
                }
            }

            MouseArea {
                id: area

                property point start
                property real startX
                property real startY
                property bool moved

                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                acceptedButtons: Qt.LeftButton
                // The page of Settings scrolls by dragging: once a display is pressed, the drag is the display's
                preventStealing: true

                onPressed: mouse => {
                    area.start = area.mapToItem(root, mouse.x, mouse.y);
                    area.startX = tile.modelData.x;
                    area.startY = tile.modelData.y;
                    area.moved = false;
                    root.frozen = root.view;
                    root.dragX = tile.modelData.x;
                    root.dragY = tile.modelData.y;
                }

                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    const p = area.mapToItem(root, mouse.x, mouse.y);
                    const dx = (p.x - area.start.x) / root.view.k;
                    const dy = (p.y - area.start.y) / root.view.k;
                    if (!area.moved && Math.hypot(p.x - area.start.x, p.y - area.start.y) < 6)
                        return;
                    area.moved = true;
                    root.dragName = tile.modelData.name;
                    root.dragX = area.startX + dx;
                    root.dragY = area.startY + dy;
                }

                onReleased: {
                    const name = tile.modelData.name;
                    const wasMoved = area.moved;
                    const x = root.dragX;
                    const y = root.dragY;
                    root.dragName = "";
                    root.frozen = null;
                    if (wasMoved)
                        root.dropped(name, x, y);
                    else
                        root.picked(name);
                }

                onCanceled: {
                    root.dragName = "";
                    root.frozen = null;
                }
            }
        }
    }
}
