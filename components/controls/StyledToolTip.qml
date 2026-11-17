import QtQuick
import QtQuick.Controls
import Sylenara.Config
import qs.components
import qs.services

// Material You plain tooltip, the one every tooltip of the shell uses: a short label on the inverse surface, small
// text, gently rounded, that fades in after the pointer has rested a while (at once if another one was showing: see
// TooltipGroup).
// Buttons have it built in (`tooltip: Tr.tr("…")`); for anything else, put it inside the control:
//     StyledToolTip { shown: parent.hovered; text: Tr.tr("…") }
ToolTip {
    id: root

    property bool shown
    // Where it goes around its control: "top", "bottom", "left" or "right" (the bar, on the left edge, uses "right")
    property string side: "top"
    property real maxWidth: 240
    // How long the pointer rests on the control before the first tooltip shows
    property int initialDelay: 1000

    // A popup is not an item: it does not inherit the screen of the control it belongs to, and reading Tokens on
    // itself before that screen is known warns (once per property, at every creation). What it needs of Tokens is
    // read through the control, which is an item and tells when its screen arrives
    readonly property var tk: parent?.Tokens ?? null
    readonly property real gap: tk?.spacing.small ?? 0
    readonly property real anchorWidth: parent?.width ?? 0
    readonly property real anchorHeight: parent?.height ?? 0

    visible: shown && text.length > 0
    delay: TooltipGroup.warm ? 0 : initialDelay
    timeout: -1
    // Long labels wrap instead of growing without end
    width: Math.min(implicitWidth, maxWidth)
    x: side === "left" ? -width - gap : side === "right" ? anchorWidth + gap : (anchorWidth - width) / 2
    y: side === "top" ? -height - gap : side === "bottom" ? anchorHeight + gap : (anchorHeight - height) / 2
    margins: tk?.padding.small ?? 0
    padding: 0
    topPadding: tk?.padding.extraSmall ?? 0
    bottomPadding: tk?.padding.extraSmall ?? 0
    leftPadding: tk?.padding.small ?? 0
    rightPadding: tk?.padding.small ?? 0

    onOpened: TooltipGroup.opened()
    onClosed: TooltipGroup.closed()
    Component.onDestruction: {
        if (visible)
            TooltipGroup.closed();
    }

    contentItem: StyledText {
        Tokens.screen: root.parent?.Tokens.screen ?? ""

        text: root.text
        color: Colours.palette.m3inverseOnSurface
        font: root.tk ? root.tk.font.body.small : Qt.application.font
        wrapMode: Text.Wrap
    }

    background: StyledRect {
        Tokens.screen: root.parent?.Tokens.screen ?? ""

        radius: root.tk?.rounding.extraSmall ?? 0
        color: Colours.palette.m3inverseSurface
    }

    // Fades in and settles from a slightly smaller size, quick on the way out
    enter: Transition {
        Anim {
            property: "opacity"
            from: 0
            to: 1
            duration: Tokens.anim.durations.small
        }

        Anim {
            property: "scale"
            from: 0.92
            to: 1
            duration: Tokens.anim.durations.small
        }
    }

    exit: Transition {
        Anim {
            property: "opacity"
            from: 1
            to: 0
            duration: Tokens.anim.durations.small / 2
        }
    }
}
