pragma Singleton

import QtQuick
import Quickshell
import Sylenara
import Sylenara.Config
import Sylenara.I18n

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string pictures: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`
    readonly property string videos: Quickshell.env("XDG_VIDEOS_DIR") || `${home}/Videos`

    readonly property string data: `${Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`}/sylenara`
    readonly property string state: `${Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`}/sylenara`
    readonly property string cache: `${Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`}/sylenara`
    readonly property string config: `${Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`}/sylenara`

    readonly property string imagecache: `${cache}/imagecache`
    readonly property string notifimagecache: `${imagecache}/notifs`
    readonly property string wallsdir: envVar("WALLPAPERS_DIR") || absolutePath(GlobalConfig.paths.wallpaperDir)
    // Captures and recordings: env override, else the folder chosen in Nexus (pinned on first use), else the
    // XDG pictures/videos folder plus a name in the shell's language
    readonly property string shotsdir: envVar("SCREENSHOTS_DIR") || configDir(GlobalConfig.paths.screenshotsDir) || `${pictures}/${Tr.tr("Screenshots")}`
    readonly property string recsdir: envVar("RECORDINGS_DIR") || configDir(GlobalConfig.paths.recordingsDir) || `${videos}/${Tr.tr("Screen recordings")}`

    function configDir(path: string): string {
        return path ? absolutePath(path) : "";
    }

    // Write the folder in use to the config the first time one is used: the name was picked in one language
    function pinShotsDir(): void {
        if (!envVar("SCREENSHOTS_DIR") && !GlobalConfig.paths.screenshotsDir)
            GlobalConfig.paths.screenshotsDir = shortenHome(shotsdir);
    }

    function pinRecsDir(): void {
        if (!envVar("RECORDINGS_DIR") && !GlobalConfig.paths.recordingsDir)
            GlobalConfig.paths.recordingsDir = shortenHome(recsdir);
    }
    readonly property string libdir: envVar("LIB_DIR") || `${home}/.local/lib`

    function envVar(name: string): string {
        // Unset is null, and the string return type would turn it into "null" (screenshots went to ~/null)
        return Quickshell.env(`SYLENARA_${name}`) ?? "";
    }

    function toLocalFile(path: url): string {
        path = Qt.resolvedUrl(path);
        return path.toString() ? CUtils.toLocalFile(path) : "";
    }

    function absolutePath(path: string): string {
        return toLocalFile(path.replace(/~|(\$({?)HOME(}?))+/, home));
    }

    function shortenHome(path: string): string {
        return path.replace(home, "~");
    }
}
