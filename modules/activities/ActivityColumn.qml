pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Sylphrena.Config
import Sylphrena.I18n
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    required property ShellScreen screen
    required property var activity
    required property real cardWidth

    readonly property bool isCurrent: Activities.currentActivity?.id === activity?.id

    spacing: Tokens.spacing.medium

    Item {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Tokens.padding.small * 2

        RowLayout {
            id: headerRow

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.small
            anchors.topMargin: Tokens.padding.small
            anchors.bottomMargin: Tokens.padding.small
            spacing: Tokens.spacing.small
            // Above the header's click area, so the button gets its own clicks
            z: 1

            MaterialIcon {
                text: root.activity?.icon || "dashboard"
                color: root.isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.large
            }

            StyledText {
                Layout.fillWidth: true
                text: root.activity?.name ? Tr.trMarked(root.activity.name) : ""
                color: root.isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
                font: Tokens.font.title.medium
                elide: Text.ElideRight
            }

            // One more desktop at the end of this activity
            IconButton {
                id: addDesktop

                readonly property bool atMax: (root.activity?.workspaceCount ?? 1) >= Activities.maxDesktops

                icon: "add"
                type: IconButton.Tonal
                isRound: true
                opacity: atMax ? 0.38 : 1
                stateLayer.disabled: atMax
                onClicked: Activities.addDesktop(root.activity.id)

                StyledToolTip {
                    shown: addDesktop.hovered
                    text: Tr.tr("Add desktop")
                }
            }
        }

        StateLayer {
            anchors.fill: parent
            radius: Tokens.rounding.large
            onClicked: {
                if (root.activity)
                    Activities.focusActivity(root.activity.id);
                Activities.closeOverview();
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        Repeater {
            model: root.activity?.workspaceIds ?? []

            WorkspaceCard {
                required property var modelData

                screen: root.screen
                wsId: modelData
                cardWidth: root.cardWidth
            }
        }
    }
}
