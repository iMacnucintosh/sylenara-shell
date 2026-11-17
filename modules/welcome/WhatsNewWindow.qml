pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Sylenara.Config
import Sylenara.I18n
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

// What's new after an update (see services/Welcome.qml): a cover, one page per highlight of the versions it brings
// (screenshot, title and two lines) and, last, every change of those versions from CHANGELOG.md.
FloatingWindow {
    id: win

    // [{ version, highlights: [{ icon, image, title: {en, es}, text: {en, es} }] }], oldest first
    required property var versions
    // The CHANGELOG sections of those versions, Markdown
    required property string changelog
    property bool done: false

    // (no flatMap in Qt's JavaScript)
    readonly property var highlights: {
        const out = [];
        for (let i = 0; i < (versions?.length ?? 0); i++) {
            const list = versions[i].highlights ?? [];
            for (let j = 0; j < list.length; j++)
                out.push(list[j]);
        }
        return out;
    }
    readonly property string latest: versions?.length ? versions[versions.length - 1].version : ""
    // cover + highlights + every change
    readonly property int stepCount: highlights.length + 2
    property int step: 0

    signal finished

    // A text of the catalogue in the language of the shell (English when it has no translation)
    function localised(texts: var): string {
        if (!texts)
            return "";
        const lang = (Tr.language || Qt.locale().name).split(/[_-]/)[0];
        return texts[lang] ?? texts.en ?? "";
    }

    function dismiss(): void {
        if (win.done)
            return;
        win.done = true;
        win.finished();
        win.destroy();
    }

    // TRANSLATORS: %1 = the version, e.g. 0.6.0
    title: Tr.tr("What's new in Sylenara %1").arg(win.latest)
    color: Colours.tPalette.m3surface
    surfaceFormat.opaque: false
    // A small window of fixed size: Hyprland floats those (and centres them) instead of tiling them
    readonly property int windowWidth: 960
    readonly property int windowHeight: 720
    implicitWidth: windowWidth
    implicitHeight: windowHeight
    minimumSize.width: windowWidth
    minimumSize.height: windowHeight
    maximumSize.width: windowWidth
    maximumSize.height: windowHeight

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    onVisibleChanged: {
        if (!visible)
            win.dismiss();
    }

    // Keyboard: the arrows go through the pages, Escape closes
    Shortcut {
        sequences: ["Right", "PgDown"]
        onActivated: win.step = Math.min(win.stepCount - 1, win.step + 1)
    }

    Shortcut {
        sequences: ["Left", "PgUp"]
        onActivated: win.step = Math.max(0, win.step - 1)
    }

    Shortcut {
        sequence: "Escape"
        onActivated: win.dismiss()
    }

    // The whole window takes the mouse wheel: it goes through the pages (over the list of changes it scrolls the list)
    Item {
        anchors.fill: parent

        // One page per notch; a touchpad's stream of small steps adds up to one page, with a pause after it
        WheelHandler {
            property real pending: 0

            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (wheelPause.running)
                    return;
                const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
                pending += delta;
                if (Math.abs(pending) < 120)
                    return;
                win.step = pending < 0 ? Math.min(win.stepCount - 1, win.step + 1) : Math.max(0, win.step - 1);
                pending = 0;
                wheelPause.restart();
            }
        }

        Timer {
            id: wheelPause

            interval: 280
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.extraLarge
            spacing: Tokens.spacing.large

            Loader {
                id: pages

                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: win.step === 0 ? coverPage : (win.step <= win.highlights.length ? highlightPage : changesPage)

                onLoaded: fade.restart()

                NumberAnimation {
                    id: fade

                    target: pages.item
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Tokens.anim.durations.normal
                }
            }

            // ---- Footer ---------------------------------------------------------------------
            Item {
                Layout.fillWidth: true
                implicitHeight: buttons.implicitHeight

                Row {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: win.stepCount

                        Rectangle {
                            required property int index

                            anchors.verticalCenter: parent.verticalCenter
                            width: index === win.step ? Tokens.padding.large : Tokens.padding.small
                            height: Tokens.padding.small
                            radius: height / 2
                            color: index === win.step ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                            Behavior on width {
                                Anim {}
                            }
                        }
                    }
                }

                RowLayout {
                    id: buttons

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Tokens.spacing.medium

                    TextButton {
                        visible: win.step < win.stepCount - 1
                        text: Tr.tr("Close")
                        type: TextButton.Text
                        isRound: true
                        horizontalPadding: Tokens.padding.large
                        verticalPadding: Tokens.padding.small
                        onClicked: win.dismiss()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    TextButton {
                        visible: win.step > 0
                        text: Tr.tr("Back")
                        type: TextButton.Tonal
                        isRound: true
                        horizontalPadding: Tokens.padding.extraLarge
                        verticalPadding: Tokens.padding.medium
                        onClicked: win.step--
                    }

                    TextButton {
                        text: win.step < win.stepCount - 1 ? Tr.tr("Next") : Tr.tr("Done")
                        isRound: true
                        horizontalPadding: Tokens.padding.extraLarge
                        verticalPadding: Tokens.padding.medium
                        onClicked: win.step < win.stepCount - 1 ? win.step++ : win.dismiss()
                    }
                }
            }
        }
    }

    // ── Cover ─────────────────────────────────────────────────────────────────────────────
    Component {
        id: coverPage

        ColumnLayout {
            spacing: Tokens.spacing.large

            Item {
                Layout.fillHeight: true
            }

            SylenaraOrb {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 130 * 1.55
                Layout.preferredHeight: 130 * 1.55
                orbSize: 130
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("What's new")
                font: Tokens.font.headline.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                // TRANSLATORS: %1 = the version Sylenara was updated to
                text: Tr.tr("Sylenara was updated to %1").arg(win.latest)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.large
            }

            // What comes next, at a glance
            Flow {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 720
                Layout.preferredWidth: 720
                Layout.topMargin: Tokens.spacing.large
                spacing: Tokens.spacing.small

                Repeater {
                    model: win.highlights

                    StyledRect {
                        id: chip

                        required property var modelData
                        required property int index

                        implicitWidth: chipRow.implicitWidth + Tokens.padding.large * 2
                        implicitHeight: chipRow.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh

                        RowLayout {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: chip.modelData.icon || "auto_awesome"
                                color: Colours.palette.m3primary
                                fill: 1
                            }

                            StyledText {
                                text: win.localised(chip.modelData.title)
                                font: Tokens.font.label.large
                            }
                        }

                        StateLayer {
                            onClicked: win.step = chip.index + 1
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    // ── One highlight ─────────────────────────────────────────────────────────────────────
    Component {
        id: highlightPage

        ColumnLayout {
            id: page

            readonly property var item: win.highlights[win.step - 1] ?? {}
            readonly property bool hasImage: !!page.item.image

            spacing: Tokens.spacing.large

            Item {
                Layout.fillHeight: true
                visible: !page.hasImage
            }

            // The screenshot, or a large icon when there is none
            ClippingRectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: page.hasImage
                Layout.fillHeight: page.hasImage
                Layout.maximumWidth: shot.status === Image.Ready ? shot.implicitWidth : 860
                implicitHeight: page.hasImage ? 0 : 140
                implicitWidth: page.hasImage ? 0 : 140
                radius: page.hasImage ? Tokens.rounding.large : Tokens.rounding.extraLarge
                color: page.hasImage ? Colours.tPalette.m3surfaceContainer : Colours.palette.m3primaryContainer

                Image {
                    id: shot

                    anchors.fill: parent
                    visible: page.hasImage
                    source: page.hasImage ? `file://${Quickshell.shellPath(`whatsnew/${page.item.image}`)}` : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !page.hasImage
                    text: page.item.icon || "auto_awesome"
                    color: Colours.palette.m3onPrimaryContainer
                    // Outlined: filled glyphs this large show their outline as a line inside the fill
                    fill: 0
                    // Drawn at its size (a scaled small glyph came out blurred)
                    fontStyle: Tokens.font.icon.size(64).build()
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 760
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    Layout.alignment: Qt.AlignTop
                    visible: page.hasImage
                    text: page.item.icon || "auto_awesome"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.extraLarge
                    fill: 1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: page.hasImage ? Text.AlignLeft : Text.AlignHCenter
                        text: win.localised(page.item.title)
                        font: Tokens.font.headline.small
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: page.hasImage ? Text.AlignLeft : Text.AlignHCenter
                        text: win.localised(page.item.text)
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.large
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item {
                Layout.fillHeight: true
                visible: !page.hasImage
            }
        }
    }

    // ── Every change ──────────────────────────────────────────────────────────────────────
    Component {
        id: changesPage

        ColumnLayout {
            spacing: Tokens.spacing.large

            StyledText {
                text: Tr.tr("Every change")
                font: Tokens.font.headline.medium
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainer

                StyledFlickable {
                    id: flick

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    clip: true
                    contentHeight: notes.implicitHeight
                    flickableDirection: Flickable.VerticalFlick

                    StyledText {
                        id: notes

                        width: flick.width
                        text: win.changelog || Tr.tr("The list of changes is not available.")
                        textFormat: Text.MarkdownText
                        wrapMode: Text.WordWrap
                        font: Tokens.font.body.medium
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }
            }
        }
    }
}
