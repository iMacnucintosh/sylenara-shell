pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Icons for windows of class steam_app_<appid>: Steam's own games (steam_icon_<appid> in the icon theme) and the
// non-Steam shortcuts, whose icon scripts/steam-app-icons.py reads from Steam (the one chosen for the shortcut,
// or its library artwork). Read at start and again, at most once a minute, when an unknown appid shows up.
Singleton {
    id: root

    property var shortcuts: ({})
    property real lastRead: 0

    // "" when the class is not a Steam game or it has no icon (the caller keeps its fallback)
    function iconFor(cls: string): string {
        const m = /^steam_app_(\d+)$/.exec(cls ?? "");
        if (!m)
            return "";
        const appid = m[1];
        if (Quickshell.hasThemeIcon(`steam_icon_${appid}`))
            return Quickshell.iconPath(`steam_icon_${appid}`);
        const path = root.shortcuts[appid];
        if (path)
            return `file://${path}`;
        Qt.callLater(root.reread);
        return "";
    }

    function reread(): void {
        if (reader.running || Date.now() - root.lastRead < 60000)
            return;
        root.lastRead = Date.now();
        reader.running = true;
    }

    Component.onCompleted: reread()

    Process {
        id: reader

        command: ["python3", `${Quickshell.shellDir}/scripts/steam-app-icons.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.shortcuts = JSON.parse(text) ?? {};
                } catch (e) {
                    console.warn("SteamAppIcons:", e);
                }
            }
        }
    }
}
