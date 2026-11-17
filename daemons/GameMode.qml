import QtQuick
import Quickshell
import Quickshell.Io
import Sylenara
import Sylenara.Config
import Sylenara.I18n
import Sylenara.State
import qs.services

Scope {
    id: root

    function applyGameMode(): void {
        // Compact layout only: maximise screen use. Keep animations, blur, shadows, wobble.
        Hypr.extras.applyOptions({
            "general:gaps_in": 0,
            "general:gaps_out": 0,
            "general:border_size": 0,
            "decoration:rounding": 0
        });
    }

    function syncState(enableDisable: bool): void {
        if (RuntimeState.gameMode) {
            root.applyGameMode();
            // Only when it is switched on: at startup (a shell reload) it is already on, and the notice
            // landed on top of the reload's
            if (enableDisable && GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Compact layout enabled"), Tr.tr("Left bar only; no frame, gaps or window rounding"), "fit_screen");
        } else if (enableDisable) {
            Hypr.extras.message("reload");
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Compact layout disabled"), Tr.tr("Hyprland settings restored"), "fit_screen");
        }
    }

    Component.onCompleted: syncState(false)

    // Once more when the shell has settled: the first request at startup can go out before Hyprland's
    // socket answers, or be undone by the shell's own startup reloads (a reload left the gaps back)
    Timer {
        running: RuntimeState.gameMode
        interval: 2500
        onTriggered: root.applyGameMode()
    }

    Connections {
        function onGameModeChanged(): void {
            root.syncState(true);
        }

        target: RuntimeState
    }

    Connections {
        function onConfigReloaded(): void {
            if (RuntimeState.gameMode)
                root.applyGameMode();
        }

        target: Hypr
    }

    IpcHandler {
        function isEnabled(): bool {
            return RuntimeState.gameMode;
        }

        function toggle(): void {
            RuntimeState.gameMode = !RuntimeState.gameMode;
        }

        function enable(): void {
            RuntimeState.gameMode = true;
        }

        function disable(): void {
            RuntimeState.gameMode = false;
        }

        target: "gameMode"
    }
}
