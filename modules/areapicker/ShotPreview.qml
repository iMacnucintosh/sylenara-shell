pragma ComponentBehavior: Bound

import QtQuick
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

// What a region capture shows before it goes anywhere: the image, and copy, save or discard. Each one closes it.
StyledWindow {
    id: win

    required property string path
    property bool done

    signal finished

    // Pictures/Screenshots, by its name in the user's language (Imágenes/Capturas de pantalla)
    readonly property string saveDir: Paths.envVar("SCREENSHOTS_DIR") || `${Paths.pictures}/${Tr.tr("Screenshots")}`

    function finish(): void {
        if (win.done)
            return;
        win.done = true;
        win.finished();
    }

    function copy(): void {
        // Paths via argv, never interpolated into the shell string
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"; rm -f "$1"', "_", win.path]);
        Toaster.toast(Tr.tr("Screenshot copied"), Tr.tr("Copied to the clipboard"), "content_copy");
        win.finish();
    }

    function save(): void {
        const name = `${Tr.tr("Screenshot")}_${Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss")}.png`;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && mv "$2" "$1/$3"', "_", win.saveDir, win.path, name]);
        // TRANSLATORS: %1 = folder the screenshot was saved to
        const where = Tr.tr("In %1").arg(Paths.shortenHome(win.saveDir));
        Toaster.toast(Tr.tr("Screenshot saved"), where, "save");
        win.finish();
    }

    function discard(): void {
        Quickshell.execDetached(["rm", "-f", win.path]);
        win.finish();
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
            if (event.key === Qt.Key_C) {
                win.copy();
                event.accepted = true;
            } else if (event.key === Qt.Key_S) {
                win.save();
                event.accepted = true;
            }
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
                    // Fits in 70 % of the screen, never bigger than the capture itself
                    readonly property real scale: Math.min(1, win.width * 0.7 / Math.max(1, shot.sourceSize.width), win.height * 0.7 / Math.max(1, shot.sourceSize.height))

                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Math.max(1, shot.sourceSize.width * scale)
                    implicitHeight: Math.max(1, shot.sourceSize.height * scale)
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainer

                    Image {
                        id: shot

                        anchors.fill: parent
                        source: win.path ? `file://${win.path}` : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        cache: false
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Tokens.spacing.small

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
