import QtQuick
import QtQuick.Controls
import Sylphrena.Config
import qs.components
import qs.services

// Material You plain tooltip: a short label on the inverse surface, small text, gently rounded, fading in after a
// moment of hover. Put it inside the control: StyledToolTip { shown: parent.hovered; text: … }
ToolTip {
    id: root

    property bool shown

    // A popup is not an item: it does not inherit the screen of the control it belongs to, and reading Tokens on
    // itself before that screen is known warns (once per property, at every creation). What it needs of Tokens is
    // read through the control, which is an item and tells when its screen arrives
    readonly property var tk: parent?.Tokens ?? null

    visible: shown && text.length > 0
    delay: 500
    timeout: -1
    y: -implicitHeight - (tk?.spacing.small ?? 0)
    x: (parent ? parent.width - implicitWidth : 0) / 2
    margins: tk?.padding.small ?? 0
    padding: 0
    topPadding: tk?.padding.extraSmall ?? 0
    bottomPadding: tk?.padding.extraSmall ?? 0
    leftPadding: tk?.padding.small ?? 0
    rightPadding: tk?.padding.small ?? 0

    contentItem: StyledText {
        Tokens.screen: root.parent?.Tokens.screen ?? ""

        text: root.text
        color: Colours.palette.m3inverseOnSurface
        font: root.tk ? root.tk.font.body.small : Qt.application.font
    }

    background: StyledRect {
        Tokens.screen: root.parent?.Tokens.screen ?? ""

        radius: root.tk?.rounding.extraSmall ?? 0
        color: Colours.palette.m3inverseSurface
    }

    enter: Transition {
        Anim {
            property: "opacity"
            from: 0
            to: 1
            duration: Tokens.anim.durations.small
        }
    }

    exit: Transition {
        Anim {
            property: "opacity"
            from: 1
            to: 0
            duration: Tokens.anim.durations.small
        }
    }
}
