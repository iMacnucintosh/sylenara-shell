pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Sylphrena
import Sylphrena.Config
import Sylphrena.I18n
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.utils

// What a region capture shows before it goes anywhere: the image, a few marks to draw on it (free line, arrow,
// rectangle, eraser) and copy, save or discard. Each of the three closes it.
StyledWindow {
    id: win

    required property string path
    property bool done

    // Drawing: "pen", "arrow", "rect" or "eraser"; shapes in the capture's own pixels
    property string tool: "pen"
    property color penColour: win.colours[0]
    property var shapes: []
    property var history: []
    property var current: null

    readonly property list<color> colours: ["#e53935", "#fdd835", "#43a047", "#1e88e5", "#ffffff", "#212121"]
    // The capture on screen: at most 70 % of the screen, never bigger than itself
    readonly property real viewScale: Math.min(1, win.width * 0.7 / Math.max(1, shot.sourceSize.width), (win.height * 0.7 - 120) / Math.max(1, shot.sourceSize.height))
    // Marks are as thick on screen whatever the zoom
    readonly property real strokeWidth: 4 / Math.max(0.01, win.viewScale)

    signal finished

    function finish(): void {
        if (win.done)
            return;
        win.done = true;
        win.finished();
    }

    // The marks go into the file itself before it is copied or saved
    function flatten(): void {
        if (win.shapes.length > 0 && !canvas.save(win.path))
            console.warn(`ShotPreview: could not write the marks to ${win.path}`);
    }

    function copy(): void {
        win.flatten();
        // Paths via argv, never interpolated into the shell string
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"; rm -f "$1"', "_", win.path]);
        Toaster.toast(Tr.tr("Screenshot copied"), Tr.tr("Copied to the clipboard"), "content_copy");
        win.finish();
    }

    function save(): void {
        win.flatten();
        Paths.pinShotsDir();
        const dir = Paths.shotsdir;
        const name = `${Tr.tr("Screenshot")}_${Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss")}.png`;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && mv "$2" "$1/$3"', "_", dir, win.path, name]);
        // TRANSLATORS: %1 = folder the screenshot was saved to
        const where = Tr.tr("In %1").arg(Paths.shortenHome(dir));
        Toaster.toast(Tr.tr("Screenshot saved"), where, "save");
        win.finish();
    }

    function discard(): void {
        Quickshell.execDetached(["rm", "-f", win.path]);
        win.finish();
    }

    function remember(): void {
        win.history = [...win.history, win.shapes];
    }

    function undo(): void {
        if (!win.history.length)
            return;
        win.shapes = win.history[win.history.length - 1];
        win.history = win.history.slice(0, -1);
        canvas.requestPaint();
    }

    // Distance from p to the segment a-b
    function segDist(px: real, py: real, ax: real, ay: real, bx: real, by: real): real {
        const dx = bx - ax;
        const dy = by - ay;
        const len = dx * dx + dy * dy;
        const t = len ? Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / len)) : 0;
        return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
    }

    function hits(s: var, x: real, y: real): bool {
        const reach = s.width / 2 + 8 / win.viewScale;
        const p = s.points;
        if (s.type === "pen") {
            for (let i = 0; i < p.length; i++) {
                const q = p[Math.min(i + 1, p.length - 1)];
                if (win.segDist(x, y, p[i].x, p[i].y, q.x, q.y) <= reach)
                    return true;
            }
            return false;
        }
        const a = p[0];
        const b = p[p.length - 1];
        if (s.type === "arrow")
            return win.segDist(x, y, a.x, a.y, b.x, b.y) <= reach;
        return win.segDist(x, y, a.x, a.y, b.x, a.y) <= reach || win.segDist(x, y, b.x, a.y, b.x, b.y) <= reach || win.segDist(x, y, b.x, b.y, a.x, b.y) <= reach || win.segDist(x, y, a.x, b.y, a.x, a.y) <= reach;
    }

    // The eraser takes whole marks: the topmost one under the pointer
    function eraseAt(x: real, y: real): void {
        for (let i = win.shapes.length - 1; i >= 0; i--) {
            if (win.hits(win.shapes[i], x, y)) {
                win.remember();
                win.shapes = win.shapes.filter((_, j) => j !== i);
                canvas.requestPaint();
                return;
            }
        }
    }

    function drawShape(ctx: var, s: var): void {
        const p = s.points;
        ctx.strokeStyle = s.colour;
        ctx.lineWidth = s.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();
        if (s.type === "pen") {
            ctx.moveTo(p[0].x, p[0].y);
            for (let i = 1; i < p.length; i++)
                ctx.lineTo(p[i].x, p[i].y);
            if (p.length === 1)
                ctx.lineTo(p[0].x + 0.1, p[0].y);
        } else {
            const a = p[0];
            const b = p[p.length - 1];
            if (s.type === "rect") {
                ctx.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
            } else {
                const angle = Math.atan2(b.y - a.y, b.x - a.x);
                const head = Math.min(s.width * 4 + 10, Math.hypot(b.x - a.x, b.y - a.y) * 0.6);
                ctx.moveTo(a.x, a.y);
                ctx.lineTo(b.x, b.y);
                ctx.moveTo(b.x - head * Math.cos(angle - Math.PI / 6), b.y - head * Math.sin(angle - Math.PI / 6));
                ctx.lineTo(b.x, b.y);
                ctx.lineTo(b.x - head * Math.cos(angle + Math.PI / 6), b.y - head * Math.sin(angle + Math.PI / 6));
            }
        }
        ctx.stroke();
    }

    name: "screenshot-preview"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: win.done ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Item {
        id: content

        anchors.fill: parent
        focus: true
        opacity: 0

        Component.onCompleted: {
            opacity = 1;
            forceActiveFocus();
        }

        Behavior on opacity {
            Anim {}
        }

        Keys.onEscapePressed: win.discard()
        Keys.onReturnPressed: win.copy()
        Keys.onEnterPressed: win.copy()
        Keys.onPressed: event => {
            if (!(event.modifiers & Qt.ControlModifier))
                return;
            if (event.key === Qt.Key_C)
                win.copy();
            else if (event.key === Qt.Key_S)
                win.save();
            else if (event.key === Qt.Key_Z)
                win.undo();
            else
                return;
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3scrim, 0.5)
        }

        // Swallows clicks outside the card: a stray click must not lose the capture
        MouseArea {
            anchors.fill: parent
        }

        StyledRect {
            id: card

            anchors.centerIn: parent
            implicitWidth: column.implicitWidth + Tokens.padding.large * 2
            implicitHeight: column.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.large
            // Over a scrim the translucent surface vanished: keep it mostly opaque
            color: Qt.alpha(Colours.palette.m3surfaceContainer, Math.max(0.9, Colours.tPalette.m3surface.a))

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
            }

            ColumnLayout {
                id: column

                anchors.centerIn: parent
                spacing: Tokens.spacing.large

                ClippingRectangle {
                    id: view

                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Math.max(1, shot.sourceSize.width * win.viewScale)
                    implicitHeight: Math.max(1, shot.sourceSize.height * win.viewScale)
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainer

                    // Only for its size; the canvas draws the capture and the marks at full size, so saving it
                    // keeps every pixel
                    Image {
                        id: shot

                        visible: false
                        source: win.path ? `file://${win.path}` : ""
                        cache: false
                    }

                    Canvas {
                        id: canvas

                        readonly property string url: win.path ? `file://${win.path}` : ""

                        width: shot.sourceSize.width
                        height: shot.sourceSize.height
                        transformOrigin: Item.TopLeft
                        scale: win.viewScale
                        renderTarget: Canvas.Image

                        Component.onCompleted: loadImage(url)
                        onImageLoaded: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            if (isImageLoaded(url))
                                ctx.drawImage(url, 0, 0);
                            for (const s of win.shapes)
                                win.drawShape(ctx, s);
                            if (win.current)
                                win.drawShape(ctx, win.current);
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: win.tool === "eraser" ? Qt.PointingHandCursor : Qt.CrossCursor
                        preventStealing: true

                        function at(mouse: var): var {
                            return Qt.point(mouse.x / win.viewScale, mouse.y / win.viewScale);
                        }

                        onPressed: mouse => {
                            const p = at(mouse);
                            if (win.tool === "eraser") {
                                win.eraseAt(p.x, p.y);
                                return;
                            }
                            win.current = {
                                type: win.tool,
                                colour: win.penColour.toString(),
                                width: win.strokeWidth,
                                points: [{ x: p.x, y: p.y }]
                            };
                            canvas.requestPaint();
                        }
                        onPositionChanged: mouse => {
                            const p = at(mouse);
                            if (win.tool === "eraser") {
                                if (pressed)
                                    win.eraseAt(p.x, p.y);
                                return;
                            }
                            if (!win.current)
                                return;
                            const pts = win.current.points;
                            if (win.current.type === "pen")
                                pts.push({ x: p.x, y: p.y });
                            else
                                pts[1] = { x: p.x, y: p.y };
                            canvas.requestPaint();
                        }
                        onReleased: {
                            const s = win.current;
                            win.current = null;
                            // A click without a drag leaves no arrow or rectangle
                            if (s && (s.type === "pen" || s.points.length > 1)) {
                                win.remember();
                                win.shapes = [...win.shapes, s];
                            }
                            canvas.requestPaint();
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: [
                            { id: "pen", icon: "draw", label: Tr.tr("Free line") },
                            { id: "arrow", icon: "north_east", label: Tr.tr("Arrow") },
                            { id: "rect", icon: "rectangle", label: Tr.tr("Rectangle") },
                            { id: "eraser", icon: "ink_eraser", label: Tr.tr("Eraser") }
                        ]

                        IconButton {
                            required property var modelData

                            icon: modelData.icon
                            type: IconButton.Tonal
                            isToggle: true
                            checked: win.tool === modelData.id
                            onClicked: win.tool = modelData.id
                            ToolTip.visible: hovered
                            ToolTip.text: modelData.label
                        }
                    }

                    Rectangle {
                        Layout.leftMargin: Tokens.spacing.small
                        Layout.rightMargin: Tokens.spacing.small
                        implicitWidth: 1
                        implicitHeight: 24
                        color: Colours.palette.m3outlineVariant
                    }

                    Repeater {
                        model: win.colours

                        Rectangle {
                            id: swatch

                            required property color modelData
                            readonly property bool selected: Qt.colorEqual(win.penColour, modelData)

                            implicitWidth: 24
                            implicitHeight: 24
                            radius: width / 2
                            color: modelData
                            border.width: selected ? 3 : 1
                            border.color: selected ? Colours.palette.m3primary : Colours.palette.m3outline

                            Behavior on border.width {
                                Anim {}
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    win.penColour = swatch.modelData;
                                    if (win.tool === "eraser")
                                        win.tool = "pen";
                                }
                            }
                        }
                    }

                    IconButton {
                        Layout.leftMargin: Tokens.spacing.small
                        icon: "undo"
                        type: IconButton.Text
                        disabled: !win.history.length
                        onClicked: win.undo()
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: Tokens.spacing.large
                    }

                    IconTextButton {
                        icon: "delete"
                        text: Tr.tr("Discard")
                        type: IconButton.Text
                        onClicked: win.discard()
                    }

                    IconTextButton {
                        icon: "save"
                        text: Tr.tr("Save")
                        type: IconButton.Tonal
                        onClicked: win.save()
                    }

                    IconTextButton {
                        icon: "content_copy"
                        text: Tr.tr("Copy")
                        type: IconButton.Filled
                        onClicked: win.copy()
                    }
                }
            }
        }
    }
}
