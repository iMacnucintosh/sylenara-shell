pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Sylenara.Config
import Sylenara.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Tray")
    isSubPage: true

    // bar.tray.collapse: the tray and the status icons in one button that opens them beside the bar
    readonly property list<MenuItem> collapseItems: [
        MenuItem {
            value: "auto"
            text: Tr.trCtx("When it does not fit", "taskbar tray: collapse")
        },
        MenuItem {
            value: "always"
            text: Tr.trCtx("Always", "taskbar tray: collapse")
        },
        MenuItem {
            value: "never"
            text: Tr.trCtx("Never", "taskbar tray: collapse")
        }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SelectRow {
            first: true
            label: Tr.tr("Collapse")
            subtext: Tr.tr("The tray and the status icons in one button that shows them beside the bar")
            menuItems: root.collapseItems
            active: root.collapseItems.find(i => i.value === Config.bar.tray.collapse) ?? root.collapseItems[0]
            onSelected: item => GlobalConfig.bar.tray.collapse = item.value
        }

        ToggleRow {
            text: Tr.trCtx("Background", "taskbar tray: draw a background behind the tray")
            checked: Config.bar.tray.background
            onToggled: GlobalConfig.bar.tray.background = checked
        }

        ToggleRow {
            // TRANSLATORS: tint system tray icons with the theme accent colour
            text: Tr.tr("Recolour icons")
            checked: Config.bar.tray.recolour
            onToggled: GlobalConfig.bar.tray.recolour = checked
        }

        ToggleRow {
            text: Tr.trCtx("Compact", "taskbar tray layout")
            checked: Config.bar.tray.compact
            onToggled: GlobalConfig.bar.tray.compact = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Popout on hover")
            subtext: Tr.tr("Show the tray menu popout when hovering")
            checked: Config.bar.popouts.tray
            onToggled: GlobalConfig.bar.popouts.tray = checked
        }
    }
}
