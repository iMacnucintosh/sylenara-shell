import QtQuick
import Sylenara.Config
import Sylenara.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property ScreenState screenState

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight

    StateLayer {
        id: layer

        // Cursed workaround to make the height larger than the parent
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: root.screenState.session = !root.screenState.session
    }

    StyledToolTip {
        shown: layer.containsMouse && !root.screenState.session
        text: Updates.rebootRecommended ? Tr.tr("Power · restart recommended after the update") : Tr.tr("Power")
        side: "right"
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent

        text: "power_settings_new"
        color: Colours.palette.m3error
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
    }

    // A restart is recommended (a new kernel or system pieces from the last update): a small dot on the icon, ringed
    // with the bar's colour so it reads as part of it; it goes away after restarting
    Rectangle {
        // Clear of the glyph: at the top right corner of the button, not over the icon
        anchors.horizontalCenter: icon.right
        anchors.verticalCenter: icon.top
        anchors.horizontalCenterOffset: 2
        anchors.verticalCenterOffset: -1
        width: 8
        height: 8
        radius: width / 2
        color: Colours.palette.m3primary
        border.width: 2
        border.color: Colours.tPalette.m3surfaceContainer
        visible: opacity > 0
        opacity: Updates.rebootRecommended ? 1 : 0
        scale: Updates.rebootRecommended ? 1 : 0.4

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }
}
