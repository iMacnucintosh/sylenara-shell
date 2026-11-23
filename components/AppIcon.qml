import QtQuick
import Quickshell.Widgets
import Sylenara.Config
import qs.services
import qs.utils

// A window's icon: its app's icon, or, for the shell's own windows, a Material gear in the accent colour
Item {
    id: root

    required property string appClass
    property real size: 24
    property color tint: Colours.palette.m3primary

    implicitWidth: size
    implicitHeight: size

    MaterialIcon {
        anchors.centerIn: parent
        visible: Icons.isShellWindow(root.appClass)
        text: "settings"
        fill: 1
        color: root.tint
        fontStyle: Tokens.font.icon.size(Math.max(1, root.size * 0.75)).build()
    }

    IconImage {
        anchors.centerIn: parent
        visible: !Icons.isShellWindow(root.appClass)
        asynchronous: true
        implicitSize: root.size
        source: visible ? Icons.getAppIcon(root.appClass, "image-missing") : ""
    }
}
