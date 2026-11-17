pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Sylenara.Config
import qs.components.containers
import qs.components.misc
import qs.services

Scope {
    id: root

    // The monitor with the focus when the overview opened
    property string focusedName: ""

    LazyLoader {
        id: loader

        activeAsync: Activities.overviewOpen && Activities.enabled

        Variants {
            // Only on the monitor that has the focus
            model: Screens.screens.filter(s => s.name === root.focusedName)

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: "activities-overview"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                // Exclusive: OnDemand leaves keyboard/pointer with a fullscreen game.
                WlrLayershell.keyboardFocus: Activities.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                OverviewContent {
                    anchors.fill: parent
                    screen: win.modelData
                }
            }
        }
    }

    Connections {
        target: Activities

        function onOverviewOpenChanged(): void {
            if (!Activities.overviewOpen)
                return;
            root.focusedName = Hypr.focusedMonitor?.name ?? Screens.screens[0]?.name ?? "";
            // Close competing drawers on the active screen
            const st = ShellState.forActive();
            if (!st)
                return;
            st.launcher = false;
            st.session = false;
            st.dashboard = false;
            st.sidebar = false;
            st.utilities = false;
        }
    }

    IpcHandler {
        function toggle(): void {
            Activities.toggleOverview();
        }

        function open(): void {
            if (Activities.enabled)
                Activities.overviewOpen = true;
        }

        function close(): void {
            Activities.closeOverview();
        }

        function isOpen(): string {
            return Activities.overviewOpen ? "1" : "0";
        }

        target: "activitiesOverview"
    }
}
