import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Widgets
import Sylenara.Config
import qs.components
import qs.services
import qs.utils

// Live thumbnails of the windows whose app icon is hovered in the bar (an icon stands for every window of its app
// on that monitor and desktop); a click goes to that window
Item {
    id: root

    required property PopoutState popouts
    readonly property var toplevels: (popouts.previewToplevels ?? []).filter(t => !!t)
    readonly property bool several: toplevels.length > 1
    // Smaller thumbnails when there are several, so they fit one above the other
    readonly property real thumbSize: Tokens.sizes.bar.windowPreviewSize * (several ? 0.6 : 1)

    // As wide as the widest thumbnail (a window fits a square: a tall one makes a narrow thumbnail), never narrower
    // than a readable title
    readonly property real contentWidth: Math.max(Tokens.sizes.bar.windowPreviewSize * 0.6, ...toplevels.map(t => {
        const size = t.lastIpcObject?.size ?? [1, 1];
        return root.thumbSize * Math.min(1, size[0] / Math.max(1, size[1]));
    }))

    implicitWidth: toplevels.length > 0 ? contentWidth : -Tokens.padding.extraLargeIncreased
    implicitHeight: child.implicitHeight

    Column {
        id: child

        anchors.centerIn: parent
        width: root.contentWidth
        spacing: Tokens.spacing.large

        Repeater {
            model: root.toplevels

            Column {
                id: entry

                required property var modelData

                width: child.width
                spacing: Tokens.spacing.medium

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Tokens.spacing.medium

                    AppIcon {
                        Layout.alignment: Qt.AlignVCenter
                        appClass: entry.modelData?.lastIpcObject?.class ?? ""
                        size: details.implicitHeight
                    }

                    ColumnLayout {
                        id: details

                        spacing: 0
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: entry.modelData?.title ?? ""
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: !root.several
                            text: entry.modelData?.lastIpcObject?.class ?? ""
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                ClippingWrapperRectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "transparent"
                    radius: Tokens.rounding.medium

                    ScreencopyView {
                        captureSource: entry.modelData?.wayland ?? null
                        live: visible

                        constraintSize.width: root.thumbSize
                        constraintSize.height: root.thumbSize

                        StateLayer {
                            anchors.fill: parent
                            radius: Tokens.rounding.medium
                            onClicked: {
                                Hypr.focusToplevel(entry.modelData, false);
                                root.popouts.hasCurrent = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
