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

    visible: shown && text.length > 0
    delay: 500
    timeout: -1
    y: -implicitHeight - Tokens.spacing.small
    x: (parent ? parent.width - implicitWidth : 0) / 2
    margins: Tokens.padding.small
    padding: 0
    topPadding: Tokens.padding.extraSmall
    bottomPadding: Tokens.padding.extraSmall
    leftPadding: Tokens.padding.small
    rightPadding: Tokens.padding.small

    contentItem: StyledText {
        text: root.text
        color: Colours.palette.m3inverseOnSurface
        font: Tokens.font.body.small
    }

    background: StyledRect {
        radius: Tokens.rounding.extraSmall
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
