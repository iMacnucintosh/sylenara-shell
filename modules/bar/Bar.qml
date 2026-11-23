pragma ComponentBehavior: Bound

import "components"
import "components/workspaces"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Sylenara.Config
import qs.components
import qs.services
import qs.modules.bar.popouts as BarPopouts

ColumnLayout {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int vPadding: Tokens.padding.large

    // The tray and the status icons collapse into one button when the bar does not fit the screen (or always,
    // or never: bar.tray.collapse)
    readonly property string collapseMode: Config.bar.tray.collapse
    // What the entries need, the tray and the status icons counted at their full height
    readonly property real neededHeight: {
        let total = vPadding * 2;
        let shown = 0;
        for (let i = 0; i < repeater.count; i++) {
            const entry = repeater.itemAt(i) as EntryWrapper;
            if (!entry || entry.entryId === "spacer")
                continue;
            const h = entry.fullHeight;
            if (h > 0) {
                total += h;
                shown++;
            }
        }
        return total + Math.max(0, shown - 1) * spacing;
    }
    property bool overflowing: false
    readonly property bool trayCollapsed: collapseMode === "always" || (collapseMode === "auto" && overflowing)
    // The collapsed tray unfolded over the bar (hovering its button); closes when the pointer leaves the bar
    property bool trayOpen: false
    // The status icons' entry, where the collapsed tray's button is and the unfolded tray ends
    readonly property Item statusEntry: {
        for (let i = 0; i < repeater.count; i++) {
            const entry = repeater.itemAt(i) as EntryWrapper;
            if (entry?.entryId === "statusIcons")
                return entry;
        }
        return null;
    }

    onTrayCollapsedChanged: trayOpen = false

    // With some room to spare before expanding again, so it does not flip at the edge
    function updateOverflow(): void {
        if (height <= 0)
            return;
        if (neededHeight > height)
            overflowing = true;
        else if (neededHeight < height - Tokens.sizes.bar.innerWidth)
            overflowing = false;
    }

    onNeededHeightChanged: updateOverflow()
    onHeightChanged: updateOverflow()

    function closeTray(): void {
        trayOpen = false;
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const tray = (repeater.itemAt(i) as EntryWrapper)?.item as Tray;
            if (tray)
                tray.expanded = false;
        }
    }

    // Hovering the status icons at y (bar coordinates): the popout of the icon there
    function hoverStatus(status: StatusIcons, y: real): void {
        const items = status.items;
        const icon = items.childAt(items.width / 2, mapToItem(items, 0, y).y);
        if (!icon)
            return;
        // Keep dialogs open while hovering their parent icon (extension popouts declare it)
        if (Extensions.popouts.some(p => p.dialog && p.parentIcon === icon.name && p.name === popouts.currentName))
            return;
        if (icon.name === "updates" && popouts.currentName === "updatesPassword")
            return;
        popouts.currentName = icon.name;
        popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, 0, icon.implicitHeight / 2).y);
        popouts.hasCurrent = true;
    }

    // Hovering the tray at y (bar coordinates): the menu of the app there
    function hoverTrayItem(tray: Tray, y: real): void {
        const ly = mapToItem(tray, 0, y).y;
        const index = Math.floor(((ly - tray.padding * 2 + tray.spacing) / tray.layout.implicitHeight) * tray.items.count);
        const trayItem = tray.items.itemAt(index);
        if (trayItem) {
            popouts.currentName = `traymenu${index}`;
            popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y);
            popouts.hasCurrent = true;
        } else {
            popouts.hasCurrent = false;
        }
    }

    function checkPopout(y: real): void {
        if (popouts.sticky)
            return;

        // The collapsed tray, unfolded over the bar: its icons work as in the bar
        if (trayCollapsed && trayOpen) {
            const over = mapToItem(trayOverlay, width / 2, y);
            // From the top of the unfolded column down to the end of the button: one area, no gap between them
            const buttonEnd = statusEntry ? statusEntry.y + statusEntry.height : height;
            if (over.y >= 0 && y <= buttonEnd) {
                if (over.y > trayOverlay.height) {
                    // On the button (or between it and the column): stays open, no popout
                    popouts.hasCurrent = false;
                } else if (mapToItem(overlayTray, 0, y).y < overlayTray.height) {
                    if (Config.bar.popouts.tray)
                        hoverTrayItem(overlayTray, y);
                } else if (Config.bar.popouts.statusIcons) {
                    hoverStatus(overlayStatus, y);
                }
                return;
            }
            trayOpen = false;
        }

        const ch = childAt(width / 2, y) as EntryWrapper;

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;
        const top = ch.y;

        if (id === "statusIcons" && root.trayCollapsed) {
            // The collapsed tray's button: unfold the tray and the status icons over the bar
            popouts.hasCurrent = false;
            trayOpen = true;
        } else if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            hoverStatus(ch.item as StatusIcons, y);
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as Tray;
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mapToItem(tray.expandIcon, tray.implicitWidth / 2, y)))) {
                hoverTrayItem(tray, y);
            } else {
                popouts.hasCurrent = false;
                tray.expanded = true;
            }
        } else if (id === "clock") {
            popouts.currentName = "clock";
            popouts.currentCenter = Qt.binding(() => (ch.item as Item).mapToItem(root, 0, (ch.item as Item).implicitHeight / 2).y);
            popouts.hasCurrent = true;
        } else if (id === "workspaces" && GlobalConfig.activities.windowPreview) {
            // An app icon of a desktop: a live thumbnail of that window
            const icon = BarWindowIcons.at(root, width / 2, y);
            if (icon?.toplevel?.wayland) {
                popouts.previewToplevel = icon.toplevel;
                popouts.previewToplevels = icon.toplevels?.length ? icon.toplevels : [icon.toplevel];
                popouts.currentName = "windowpreview";
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, 0, icon.height / 2).y);
                popouts.hasCurrent = true;
            } else if (popouts.currentName === "windowpreview") {
                popouts.hasCurrent = false;
            }
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            popouts.currentName = id.toLowerCase();
            popouts.currentCenter = (ch.item as Item).mapToItem(root, 0, (ch.item as Item).implicitHeight / 2).y ?? 0;
            popouts.hasCurrent = true;
        }
    }

    function handleWheel(y: real, angleDelta: point): void {
        const ch = childAt(width / 2, y) as EntryWrapper;
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon = Hypr.monitorFor(screen);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0) {
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            } else {
                // Stay within the current activity; activity switching uses dedicated shortcuts
                Activities.focusNextInActivity(angleDelta.y > 0 ? -1 : 1);
            }
        } else if (y < screen.height / 2 && Config.bar.scrollActions.volume) {
            // Volume scroll on top half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on bottom half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    spacing: Tokens.spacing.medium

    Repeater {
        id: repeater

        model: ScriptModel {
            values: root.Config.bar.entries.values.filter(e => e.enabled)
        }

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: EntryWrapper {
                    Layout.fillHeight: true
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: EntryWrapper {
                    OsIcon {
                        objectName: "taskbarLogo"
                    }
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: EntryWrapper {
                    Loader {
                        objectName: "taskbarWorkspaces"
                        active: true
                        sourceComponent: activitiesComp
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: EntryWrapper {
                    ActiveWindow {
                        objectName: "taskbarActiveWindow"
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: EntryWrapper {
                    Tray {
                        objectName: "taskbarTray"
                        popouts: root.popouts
                        collapsed: root.trayCollapsed
                    }
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: EntryWrapper {
                    Column {
                        objectName: "taskbarClockColumn"
                        spacing: Tokens.spacing.medium

                        Clock {
                            objectName: "taskbarClock"
                            popouts: root.popouts
                        }

                        // Persistent while recording — survives utilities panel closing on workspace switch
                        Loader {
                            active: Recorder.running
                            visible: active
                            asynchronous: false
                            width: Tokens.sizes.bar.innerWidth

                            sourceComponent: RecordingIndicator {
                                objectName: "taskbarRecording"
                                screenState: root.screenState
                            }
                        }
                    }
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: EntryWrapper {
                    StatusIcons {
                        objectName: "taskbarStatusIcons"
                        popouts: root.popouts
                        bar: root
                        trayCollapsed: root.trayCollapsed
                        trayOpen: root.trayOpen
                    }
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: EntryWrapper {
                    Power {
                        objectName: "taskbarPowerButton"
                        screenState: root.screenState
                    }
                }
            }
        }
    }

    // The collapsed tray unfolded over the bar: the tray and the status icons in one column, growing up from the
    // button over the desktops. Not part of the column layout (it lives in the bar's parent).
    Item {
        id: trayOverlay

        // 0 folded, 1 unfolded: the column grows up from the button
        property real reveal: root.trayCollapsed && root.trayOpen ? 1 : 0
        readonly property real fullHeight: overlayColumn.implicitHeight + Tokens.padding.small * 2
        // Right on top of the status icons' pill (the button stays visible below it), never above the top of the bar
        readonly property real foldEdge: {
            const entry = root.statusEntry;
            return entry ? root.y + entry.y : root.y + root.height;
        }

        parent: root.parent
        visible: reveal > 0
        z: 10
        x: root.x
        width: root.width
        height: Math.min(fullHeight, foldEdge - root.y) * reveal
        y: foldEdge - height
        clip: true

        Behavior on reveal {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: Colours.palette.m3surface
        }

        Column {
            id: overlayColumn

            // Pinned to the bottom, so unfolding uncovers it from the button upwards
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.padding.small
            spacing: root.spacing
            opacity: trayOverlay.reveal

            Tray {
                id: overlayTray

                anchors.horizontalCenter: parent.horizontalCenter
                popouts: root.popouts
            }

            StatusIcons {
                id: overlayStatus

                anchors.horizontalCenter: parent.horizontalCenter
                popouts: root.popouts
                bar: root
            }
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id
        // The tray and the status icons tell their full height, also while collapsed
        readonly property real fullHeight: item?.fullHeight !== undefined ? item.fullHeight : implicitHeight

        Layout.topMargin: index === 0 ? root.vPadding : 0
        Layout.bottomMargin: index === repeater.count - 1 ? root.vPadding : 0
        Layout.alignment: Qt.AlignHCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0
        // An entry with nothing to show (the collapsed tray) leaves no gap
        visible: entryId === "spacer" || implicitHeight > 0

        children: item
    }

    Component {
        id: activitiesComp

        ActivitiesStrip {
            screen: root.screen
            fullscreen: root.fullscreen
            popouts: root.popouts
            barItem: root
        }
    }
}
