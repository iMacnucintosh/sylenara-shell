pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Sylenara.Config
import qs.components
import qs.components.containers
import qs.services

// The number of every display, big on it for a few seconds, to tell which is which on the desk. Every real output gets
// one, also those the shell does not draw its panels on.
Scope {
    id: root

    // { "DP-1": { number: "1", title: "MSI MAG 274" } }
    property var labels: ({})
    property bool showing

    function show(): void {
        root.showing = true;
        hide.restart();
    }

    Timer {
        id: hide

        interval: 3500
        onTriggered: root.showing = false
    }

    Variants {
        model: root.showing ? Quickshell.screens : []

        StyledWindow {
            id: win

            required property ShellScreen modelData
            readonly property var info: root.labels[modelData.name] ?? ({})

            screen: modelData
            name: "display-identify"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // Nothing under the pointer: it goes through to what is behind
            mask: empty

            implicitWidth: card.implicitWidth
            implicitHeight: card.implicitHeight

            Region {
                id: empty
            }

            StyledRect {
                id: card

                anchors.fill: parent
                implicitWidth: Math.max(260, column.implicitWidth + Tokens.padding.extraLarge * 2)
                implicitHeight: column.implicitHeight + Tokens.padding.extraLarge * 2
                radius: Tokens.rounding.extraLarge
                color: Colours.palette.m3inverseSurface

                ColumnLayout {
                    id: column

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: win.info.number ?? ""
                        color: Colours.palette.m3inverseOnSurface
                        font.pointSize: 64
                        font.weight: Font.Medium
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: win.info.title ?? win.modelData.name
                        color: Colours.palette.m3inverseOnSurface
                        font: Tokens.font.title.medium
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: win.modelData.name
                        color: Colours.palette.m3inverseOnSurface
                        opacity: 0.7
                        font: Tokens.font.label.medium
                    }
                }
            }
        }
    }
}
