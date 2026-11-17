pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Sylenara
import qs.utils
import qs.modules.welcome

// The welcome assistant: a window that introduces Sylenara and offers its companion apps. It opens
// by itself the first time the shell runs (until it is finished or skipped) and can be opened again
// from the wand button of the Sylenara card in Nexus → About, or with `qs -c sylenara ipc call welcome open`.
//
// What's new: after an update, the highlights of the versions it brought (whatsnew/whatsnew.json, with their
// screenshots) and their CHANGELOG sections, once. `newsSeen` in the state is the last version shown; without it,
// the version the welcome was seen with. Again from Nexus → About, or `ipc call welcome whatsnew`.
Singleton {
    id: root

    readonly property string statePath: `${Paths.state}/welcome.json`

    // Loaded once from disk; null until then
    property var state: null
    readonly property bool open: window !== null
    property var window: null

    function show(): void {
        if (root.window)
            return;
        root.window = windowComp.createObject(root);
    }

    function close(): void {
        root.window?.dismiss();
    }

    // The assistant was finished or skipped: do not open it by itself again (nor the news of this version)
    function markSeen(): void {
        root.saveState({ seen: true, version: CUtils.version, newsSeen: CUtils.version });
    }

    function saveState(changes: var): void {
        root.state = Object.assign({}, root.state ?? {}, changes);
        stateFile.setText(JSON.stringify(root.state) + "\n");
    }

    // ---- What's new ---------------------------------------------------------------------
    property var newsWindow: null
    // whatsnew.json → versions, oldest first; null until read
    property var news: null

    // -1, 0 or 1, comparing dotted versions ("0.10.0" after "0.9.2")
    function compareVersions(a: string, b: string): int {
        const pa = String(a).split(/[.-]/).map(n => parseInt(n) || 0);
        const pb = String(b).split(/[.-]/).map(n => parseInt(n) || 0);
        for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
            const d = (pa[i] ?? 0) - (pb[i] ?? 0);
            if (d !== 0)
                return d < 0 ? -1 : 1;
        }
        return 0;
    }

    // The versions with news after the last one shown, up to the one running
    function pendingNews(): var {
        if (!root.news || !root.state?.seen)
            return [];
        const seen = root.state.newsSeen ?? root.state.version ?? "0";
        return root.news.filter(v => root.compareVersions(v.version, seen) > 0 && root.compareVersions(v.version, CUtils.version) <= 0);
    }

    // The CHANGELOG sections ("## 0.6.0 (date)") of these versions, newest first, as Markdown
    function changelogFor(versions: var): string {
        const wanted = versions.map(v => v.version);
        const sections = (changelogFile.text() || "").split(/^## /m).slice(1);
        const found = sections.filter(sec => wanted.includes(sec.split(/\s/)[0]));
        // A version not released yet (a build from main) has its changes under "Sin publicar"
        const pending = sections.filter(sec => /^(Sin publicar|Unreleased)/.test(sec));
        return (found.length < wanted.length ? [...pending, ...found] : found).map(sec => "## " + sec.trim()).join("\n\n");
    }

    function showNews(versions: var): void {
        if (root.newsWindow || !versions.length)
            return;
        // A plain copy, detached from the file's data
        const copy = JSON.parse(JSON.stringify(versions));
        root.newsWindow = newsComp.createObject(root, { versions: copy, changelog: root.changelogFor(copy) });
    }

    // The latest news again, whatever was seen
    function showLatestNews(): void {
        if (root.news?.length)
            root.showNews([root.news[root.news.length - 1]]);
    }

    Component {
        id: windowComp

        WelcomeWindow {
            onFinished: {
                root.markSeen();
                root.window = null;
            }
        }
    }

    Component {
        id: newsComp

        WhatsNewWindow {
            onFinished: {
                const shown = versions.map(v => v.version).reduce((a, b) => root.compareVersions(a, b) >= 0 ? a : b, root.state?.newsSeen ?? "0");
                if (root.compareVersions(shown, root.state?.newsSeen ?? "0") > 0)
                    root.saveState({ newsSeen: shown });
                root.newsWindow = null;
            }
        }
    }

    FileView {
        id: newsFile

        path: Quickshell.shellPath("whatsnew/whatsnew.json")
        printErrors: false
        onLoaded: {
            try {
                root.news = (JSON.parse(text()).versions ?? []).sort((a, b) => root.compareVersions(a.version, b.version));
            } catch (e) {
                root.news = [];
            }
        }
        onLoadFailed: root.news = []
    }

    FileView {
        id: changelogFile

        path: Quickshell.shellPath("CHANGELOG.md")
        printErrors: false
        blockLoading: true
    }

    // After an update: once the shell has been up for a moment, and never over the welcome
    Timer {
        interval: 5000
        running: root.news !== null && root.state !== null && root.state.seen === true && !root.window && !root.newsWindow
                 && root.pendingNews().length > 0
        onTriggered: root.showNews(root.pendingNews())
    }

    FileView {
        id: stateFile

        path: root.statePath
        printErrors: false
        onLoaded: {
            try {
                root.state = JSON.parse(text());
            } catch (e) {
                root.state = {};
            }
        }
        onLoadFailed: root.state = {}
    }

    // First run: once the shell has been up for a moment (so it does not fight the startup)
    Timer {
        interval: 4000
        running: root.state !== null && !root.state.seen && !root.window
        onTriggered: root.show()
    }

    IpcHandler {
        target: "welcome"

        function open(): void {
            root.show();
        }

        function close(): void {
            root.close();
        }

        // The news of the latest version, whatever was seen
        function whatsnew(): void {
            root.showLatestNews();
        }

        function closeNews(): void {
            root.newsWindow?.dismiss();
        }

        // Forget which news were shown (to test an update)
        function resetNews(): void {
            const s = Object.assign({}, root.state ?? {});
            delete s.newsSeen;
            s.version = "0";
            root.state = s;
            stateFile.setText(JSON.stringify(s) + "\n");
        }

        // Forget that it was seen (to test the first run)
        function reset(): void {
            stateFile.setText("{}\n");
            root.state = {};
        }
    }
}
