pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Sylenara.I18n
import qs.utils
import "../utils/scripts/displaylayout.js" as Layout
import "../utils/scripts/displaylua.js" as Lua

Singleton {
    id: root

    property list<var> monitors: []
    property bool loading: false
    property string lastError: ""
    // Per-output Adaptive Sync policy (0 never, 1 always, 2 automatic).
    // hyprctl only exposes whether VRR is currently asserted on the CRTC.
    property var vrrPolicies: ({})

    // The arrangement being edited on the canvas ([{ name, x, y, w, h }]); nothing changes on the screens until it is
    // applied
    property var draft: null
    readonly property bool hasDraftChanges: root.draft !== null && !Layout.samePositions(root.draft, root.layoutOf(root.monitors))
    // A change that could leave a screen unusable is undone by itself if nobody confirms it
    property var previous: null
    property int revertIn: 0
    readonly property bool confirming: root.previous !== null
    readonly property int confirmSeconds: 15
    readonly property int activeCount: root.monitors.filter(m => !m.disabled).length

    readonly property string luaPath: `${Quickshell.env("HOME")}/.config/hypr/sylenara-monitors.lua`
    readonly property list<real> scaleOptions: [1, 1.25, 1.5, 1.75, 2]
    // Plasma-style default when we have no saved policy for an output.
    readonly property int defaultVrrPolicy: 2

    function refresh(): void {
        if (fetchProc.running)
            return;
        root.loading = true;
        fetchProc.running = true;
    }

    function rememberVrr(name: string, vrr: int): void {
        if (!name)
            return;
        const next = Object.assign({}, root.vrrPolicies);
        next[name] = vrr;
        root.vrrPolicies = next;
    }

    function policyVrr(name: string, fallback: int): int {
        if (name && root.vrrPolicies[name] !== undefined)
            return Number(root.vrrPolicies[name]);
        return fallback;
    }

    function normalizeVrr(v: int): int {
        if (v === 1 || v === 2 || v === 3)
            return v === 3 ? 2 : v; // treat content-type (3) as automatic in UI
        return 0;
    }

    function ingestLuaPolicies(text: string): void {
        const next = Object.assign({}, root.vrrPolicies);
        for (const rule of Lua.parse(text)) {
            if (rule.vrr !== null && !rule.disabled)
                next[rule.name] = root.normalizeVrr(rule.vrr);
        }
        root.vrrPolicies = next;
    }

    function parseMode(modeStr: string): var {
        const m = String(modeStr || "").match(/^(\d+)x(\d+)@([\d.]+)/i);
        if (!m)
            return null;
        return {
            w: Number(m[1]),
            h: Number(m[2]),
            hz: Number(m[3])
        };
    }

    function modeForHypr(modeStr: string): string {
        const p = root.parseMode(modeStr);
        if (!p)
            return String(modeStr || "").replace(/Hz$/i, "").trim();
        const rounded = Math.round(p.hz);
        const hzStr = Math.abs(p.hz - rounded) < 0.051 ? String(rounded) : String(Math.round(p.hz * 100) / 100);
        return `${p.w}x${p.h}@${hzStr}`;
    }

    function dedupeModes(availableModes: list<string>): list<string> {
        const seen = ({});
        const out = [];
        for (let i = 0; i < availableModes.length; i++) {
            const key = root.modeForHypr(availableModes[i]);
            if (!key || seen[key])
                continue;
            seen[key] = true;
            out.push(availableModes[i]);
        }
        out.sort((a, b) => {
            const pa = root.parseMode(a);
            const pb = root.parseMode(b);
            if (!pa || !pb)
                return 0;
            if (pa.w !== pb.w)
                return pb.w - pa.w;
            if (pa.h !== pb.h)
                return pb.h - pa.h;
            return pb.hz - pa.hz;
        });
        return out;
    }

    function matchCurrentMode(width: int, height: int, refreshRate: real, availableModes: list<string>): string {
        let best = "";
        let bestDiff = Number.POSITIVE_INFINITY;
        for (let i = 0; i < availableModes.length; i++) {
            const mode = availableModes[i];
            const p = root.parseMode(mode);
            if (!p || p.w !== width || p.h !== height)
                continue;
            const d = Math.abs(p.hz - refreshRate);
            if (d < bestDiff) {
                bestDiff = d;
                best = mode;
            }
        }
        if (best.length > 0)
            return best;
        return `${width}x${height}@${refreshRate}`;
    }

    function maxAvailableHz(availableModes: list<string>): real {
        let max = 0;
        for (let i = 0; i < availableModes.length; i++) {
            const p = root.parseMode(availableModes[i]);
            if (p && p.hz > max)
                max = p.hz;
        }
        return max;
    }

    // Unique "WxH" keys, largest first — for the Resolution select.
    function resolutionsFromModes(availableModes: list<string>): list<string> {
        const seen = ({});
        const out = [];
        for (let i = 0; i < availableModes.length; i++) {
            const p = root.parseMode(availableModes[i]);
            if (!p)
                continue;
            const key = `${p.w}x${p.h}`;
            if (seen[key])
                continue;
            seen[key] = true;
            out.push(key);
        }
        out.sort((a, b) => {
            const pa = a.split("x");
            const pb = b.split("x");
            const aw = Number(pa[0]);
            const ah = Number(pa[1]);
            const bw = Number(pb[0]);
            const bh = Number(pb[1]);
            if (aw !== bw)
                return bw - aw;
            return bh - ah;
        });
        return out;
    }

    // Mode strings for one resolution, highest Hz first.
    function ratesForResolution(availableModes: list<string>, resKey: string): list<string> {
        const parts = String(resKey || "").split("x");
        const w = Number(parts[0]);
        const h = Number(parts[1]);
        const out = [];
        for (let i = 0; i < availableModes.length; i++) {
            const mode = availableModes[i];
            const p = root.parseMode(mode);
            if (p && p.w === w && p.h === h)
                out.push(mode);
        }
        out.sort((a, b) => {
            const pa = root.parseMode(a);
            const pb = root.parseMode(b);
            return (pb?.hz ?? 0) - (pa?.hz ?? 0);
        });
        return out;
    }

    function formatResolutionLabel(resKey: string): string {
        const parts = String(resKey || "").split("x");
        if (parts.length !== 2)
            return resKey;
        return Tr.tr("%1×%2").arg(parts[0]).arg(parts[1]);
    }

    function formatRateLabel(modeStr: string): string {
        const p = root.parseMode(modeStr);
        if (!p)
            return modeStr;
        const rounded = Math.round(p.hz);
        const hz = Math.abs(p.hz - rounded) < 0.051 ? rounded : Math.round(p.hz * 100) / 100;
        return Tr.tr("%1 Hz").arg(hz);
    }

    function resolutionKeyOf(modeStr: string): string {
        const p = root.parseMode(modeStr);
        if (!p)
            return "";
        return `${p.w}x${p.h}`;
    }

    function vrrLabel(vrr: int): string {
        const v = root.normalizeVrr(vrr);
        if (v === 1)
            return Tr.tr("Always");
        if (v === 2)
            return Tr.tr("Automatic");
        return Tr.tr("Never");
    }

    function vrrHint(vrr: int): string {
        const v = root.normalizeVrr(vrr);
        if (v === 1)
            return Tr.tr("Adaptive Sync stays on, including the desktop");
        if (v === 2)
            return Tr.tr("Adaptive Sync only while a window is fullscreen");
        return Tr.tr("Fixed refresh rate; least flicker on flaky HDMI FreeSync");
    }

    function findMonitor(name: string): var {
        for (let i = 0; i < root.monitors.length; i++) {
            if (root.monitors[i].name === name)
                return root.monitors[i];
        }
        return null;
    }

    function patchMonitor(name: string, patch: var): var {
        const next = [];
        let updated = null;
        for (let i = 0; i < root.monitors.length; i++) {
            const m = root.monitors[i];
            if (m.name === name) {
                updated = Object.assign({}, m, patch);
                next.push(updated);
            } else {
                next.push(m);
            }
        }
        root.monitors = next;
        return updated;
    }

    // The rule of Hyprland for a monitor of this list
    function ruleOf(mon: var): var {
        return {
            name: mon.name,
            mode: mon.disabled ? "" : root.modeForHypr(mon.mode),
            x: mon.x ?? null,
            y: mon.y ?? null,
            scale: Number(mon.scale) || 1,
            transform: Number(mon.transform) || 0,
            vrr: root.normalizeVrr(Number.isFinite(Number(mon.vrr)) ? Number(mon.vrr) : root.policyVrr(mon.name, root.defaultVrrPolicy)),
            mirror: mon.mirror || null,
            disabled: !!mon.disabled
        };
    }

    function applyLive(mon: var): void {
        if (!mon?.name)
            return;
        Quickshell.execDetached(["hyprctl", "eval", Lua.inline(root.ruleOf(mon))]);
    }

    // Every monitor again (after a change that moves several, or an undo)
    function applyAll(): void {
        for (let i = 0; i < root.monitors.length; i++)
            root.applyLive(root.monitors[i]);
    }

    function generateLua(): string {
        let out = "-- Auto-generated by Sylenara Displays. Do not edit.\n";
        out += "-- Managed from Settings → Display. Per-output Adaptive Sync: 0 never, 1 always, 2 automatic.\n\n";
        for (let i = 0; i < root.monitors.length; i++)
            out += Lua.block(root.ruleOf(root.monitors[i])) + "\n";
        if (root.monitors.length === 0) {
            out += `-- Fallback until hyprctl reports outputs\n`;
            out += `hl.monitor({\n`;
            out += `    output   = "",\n`;
            out += `    mode     = "preferred",\n`;
            out += `    position = "auto",\n`;
            out += `    scale    = "auto",\n`;
            out += `})\n`;
        }
        return out;
    }

    function persist(): void {
        let text = root.generateLua();
        const currentNames = root.monitors.map(m => String(m.name));
        // Re-append blocks for outputs that are currently unplugged so their remembered policy (Adaptive Sync,
        // position…) is not forgotten; fresh data (re-attach) wins later.
        const keep = Lua.unplugged(luaFile.text() ?? "", currentNames);
        if (keep.length > 0) {
            if (!text.endsWith("\n"))
                text += "\n";
            text += "\n-- Hot-unplugged outputs: blocks kept so their remembered policy survives\n";
            for (let i = 0; i < keep.length; i++)
                text += keep[i].text + "\n\n";
        }
        luaFile.setText(text);
    }

    // ── What the canvas works with ──────────────────────────────────────────────────────────────
    // The displays that take part in the arrangement: on, and not a copy of another one
    function layoutOf(list: var): var {
        return list.filter(m => !m.disabled && !m.mirror).map(m => ({
                    name: m.name,
                    x: Number(m.x) || 0,
                    y: Number(m.y) || 0,
                    w: m.lw,
                    h: m.lh
                }));
    }

    function currentLayout(): var {
        return root.draft ?? root.layoutOf(root.monitors);
    }

    function dropMonitor(name: string, x: real, y: real): void {
        const list = Layout.copy(root.currentLayout());
        const index = list.findIndex(d => d.name === name);
        if (index < 0)
            return;
        root.draft = Layout.drop(list, index, x, y);
    }

    function discardDraft(): void {
        root.draft = null;
    }

    function applyDraft(): void {
        if (!root.draft)
            return;
        const placed = {};
        for (const d of root.draft)
            placed[d.name] = d;
        const before = root.snapshot();
        root.monitors = root.monitors.map(m => placed[m.name] ? Object.assign({}, m, { x: placed[m.name].x, y: placed[m.name].y }) : m);
        root.draft = null;
        root.applyAll();
        root.persist();
        root.startConfirming(before);
        postApplyRefresh.restart();
    }

    // ── Changes that wait for an answer ─────────────────────────────────────────────────────────
    function snapshot(): var {
        return root.monitors.map(m => Object.assign({}, m));
    }

    function startConfirming(before: var): void {
        // The first state is the one to go back to, even when several changes come one after another
        if (root.previous === null)
            root.previous = before;
        root.revertIn = root.confirmSeconds;
        confirmTimer.restart();
    }

    function confirm(): void {
        confirmTimer.stop();
        root.previous = null;
        root.revertIn = 0;
    }

    function revert(): void {
        confirmTimer.stop();
        if (root.previous) {
            root.monitors = root.previous;
            root.applyAll();
            root.persist();
            postApplyRefresh.restart();
        }
        root.previous = null;
        root.revertIn = 0;
        root.draft = null;
    }

    // A change of `name` in its size or shape moves what is next to it: it is placed again where it stands, so it
    // does not end up on top of another one or apart from the rest
    function replace(name: string): void {
        const list = root.layoutOf(root.monitors);
        const index = list.findIndex(d => d.name === name);
        if (index < 0)
            return;
        const placed = Layout.drop(list, index, list[index].x, list[index].y);
        const byName = {};
        for (const d of placed)
            byName[d.name] = d;
        root.monitors = root.monitors.map(m => byName[m.name] ? Object.assign({}, m, { x: byName[m.name].x, y: byName[m.name].y }) : m);
    }

    // The patch of a monitor plus what follows from its new size
    function change(name: string, patch: var): void {
        const before = root.snapshot();
        const old = root.findMonitor(name);
        if (!old)
            return;
        const next = Object.assign({}, old, patch);
        const size = Layout.logicalSize(next.modeW ?? 0, next.modeH ?? 0, next.scale, next.transform);
        root.patchMonitor(name, Object.assign({}, patch, { lw: size.w || old.lw, lh: size.h || old.lh }));
        root.replace(name);
        root.draft = null;
        root.applyAll();
        root.persist();
        root.startConfirming(before);
        // eval is async; refreshing immediately re-reads the old CRTC mode and makes the page look like the click
        // did nothing.
        postApplyRefresh.restart();
    }

    function setMode(name: string, modeStr: string): void {
        const p = root.parseMode(modeStr);
        root.change(name, {
            mode: modeStr,
            modeW: p ? p.w : 0,
            modeH: p ? p.h : 0
        });
    }

    function setScale(name: string, scale: real): void {
        root.change(name, {
            scale: scale
        });
    }

    function setTransform(name: string, transform: int): void {
        root.change(name, {
            transform: transform
        });
    }

    // Off: the last one that is on cannot be turned off. On: it comes back where Hyprland puts it
    function setEnabled(name: string, enabled: bool): void {
        const mon = root.findMonitor(name);
        if (!mon || (!enabled && root.activeCount <= 1))
            return;
        const before = root.snapshot();
        const patch = enabled ? {
            disabled: false,
            x: null,
            y: null,
            mode: mon.availableModes[0] ?? "preferred"
        } : {
            disabled: true
        };
        root.patchMonitor(name, patch);
        // What copied it stops doing so
        root.monitors = root.monitors.map(m => m.mirror === name && !enabled ? Object.assign({}, m, { mirror: "" }) : m);
        root.draft = null;
        root.applyAll();
        root.persist();
        root.startConfirming(before);
        postApplyRefresh.restart();
    }

    function setMirror(name: string, target: string): void {
        if (target && !Lua.validMirror(name, target, root.monitors))
            return;
        const before = root.snapshot();
        root.patchMonitor(name, {
            mirror: target
        });
        root.draft = null;
        root.applyAll();
        root.persist();
        root.startConfirming(before);
        postApplyRefresh.restart();
    }

    function setResolution(name: string, resKey: string): void {
        const mon = root.findMonitor(name);
        if (!mon)
            return;
        const rates = root.ratesForResolution(mon.availableModes, resKey);
        if (rates.length === 0)
            return;
        // Keep current Hz when the new resolution offers it; else take the max.
        const cur = root.parseMode(mon.mode);
        let pick = rates[0];
        if (cur) {
            for (let i = 0; i < rates.length; i++) {
                const p = root.parseMode(rates[i]);
                if (p && Math.abs(p.hz - cur.hz) < 0.6) {
                    pick = rates[i];
                    break;
                }
            }
        }
        root.setMode(name, pick);
    }

    function setVrr(name: string, vrr: int): void {
        const policy = root.normalizeVrr(vrr);
        root.rememberVrr(name, policy);
        root.patchMonitor(name, {
                vrr: policy
            });
        // Persist first so hyprctl reload re-reads the authoritative Lua seed.
        // eval alone can leave DRM VRR_ENABLED stuck; reload commits Adaptive Sync.
        root.persist();
        Quickshell.execDetached(["hyprctl", "reload"]);
        postVrrRefresh.restart();
    }

    // The mode of a monitor as hyprctl reports it: the size comes as the panel has it or already turned, so a sideways
    // monitor is also looked up the other way round
    function modeOfMonitor(m: var, modes: var): var {
        const exact = root.matchCurrentMode(m.width, m.height, m.refreshRate, modes);
        if (root.parseMode(exact) && modes.includes(exact))
            return exact;
        if (Layout.isSideways(m.transform)) {
            const turned = root.matchCurrentMode(m.height, m.width, m.refreshRate, modes);
            if (modes.includes(turned))
                return turned;
        }
        return exact;
    }

    function ingestJson(raw: string): void {
        root.loading = false;
        root.lastError = "";
        try {
            const data = JSON.parse(raw || "[]");
            if (!Array.isArray(data)) {
                root.lastError = Tr.tr("Could not read monitor list");
                return;
            }
            const next = [];
            for (let i = 0; i < data.length; i++) {
                const m = data[i];
                if (!m)
                    continue;
                const modes = root.dedupeModes(Array.isArray(m.availableModes) ? m.availableModes.slice() : []);
                const disabled = !!m.disabled;
                // An output that is off reports nothing about its size: its biggest mode stands for it
                const mode = disabled ? (modes[0] ?? "") : root.modeOfMonitor(m, modes);
                const parsed = root.parseMode(mode);
                const name = m.name || "";
                const prev = root.findMonitor(name);
                // Never trust hyprctl's boolean as the policy; default to Automatic (Plasma-like).
                const fallback = prev && prev.vrr !== undefined ? root.normalizeVrr(Number(prev.vrr)) : root.defaultVrrPolicy;
                const vrr = root.normalizeVrr(root.policyVrr(name, fallback));
                if (name && root.vrrPolicies[name] === undefined)
                    root.rememberVrr(name, vrr);
                const size = Layout.logicalSize(parsed ? parsed.w : (m.width || 0), parsed ? parsed.h : (m.height || 0), m.scale || 1, m.transform || 0);
                next.push({
                        name: name,
                        description: m.description || m.model || m.name || "",
                        make: m.make || "",
                        model: m.model || "",
                        width: m.width || 0,
                        height: m.height || 0,
                        modeW: parsed ? parsed.w : 0,
                        modeH: parsed ? parsed.h : 0,
                        // Where it is, how big it is for the pointer (the mode over the scale, turned if sideways)
                        x: disabled ? null : (Number.isFinite(Number(m.x)) ? Number(m.x) : 0),
                        y: disabled ? null : (Number.isFinite(Number(m.y)) ? Number(m.y) : 0),
                        lw: size.w,
                        lh: size.h,
                        transform: Number(m.transform) || 0,
                        mirror: m.mirrorOf && m.mirrorOf !== "none" ? String(m.mirrorOf) : "",
                        refreshRate: m.refreshRate || 0,
                        scale: m.scale || 1,
                        vrr: vrr,
                        vrrActive: !!m.vrr,
                        mode: mode,
                        availableModes: modes,
                        maxHz: root.maxAvailableHz(modes),
                        disabled: disabled
                    });
            }
            const prevNames = root.monitors.map(m => String(m.name));
            root.monitors = next;
            const nextNames = next.map(m => String(m.name));
            // Other screens than before: what was being arranged no longer fits
            if (prevNames.join("\n") !== nextNames.join("\n")) {
                root.draft = null;
                // HDMI→DP (or any connector rename) must rewrite sylenara-monitors.lua
                // so the live output keeps mode/VRR; unplugged blocks are still kept.
                Qt.callLater(() => root.persist());
            }
        } catch (e) {
            root.lastError = Tr.tr("Could not read monitor list");
            console.warn("[Displays] parse failed", e);
        }
    }

    Timer {
        id: confirmTimer

        interval: 1000
        repeat: true
        onTriggered: {
            root.revertIn = Math.max(0, root.revertIn - 1);
            if (root.revertIn === 0)
                root.revert();
        }
    }

    Timer {
        id: postVrrRefresh

        interval: 700
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: postApplyRefresh

        interval: 350
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: fetchProc

        command: ["hyprctl", "monitors", "all", "-j"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.ingestJson(text)
        }

        onExited: code => {
            root.loading = false;
            if (code !== 0 && root.monitors.length === 0)
                root.lastError = Tr.tr("Could not read monitor list");
        }
    }

    FileView {
        id: luaFile

        printErrors: false
        path: root.luaPath
        onLoaded: {
            root.ingestLuaPolicies(text());
            root.refresh();
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.refresh();
        }
    }

    Connections {
        target: Hyprland

        // Hot-attach/removal must refresh the parsed list so the Nexus page
        // (and persist's merge) see the new/old output without a manual open.
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name || "";
            if (n.endsWith("v2"))
                return;
            if (n === "monitoradded" || n === "monitorremoved")
                root.refresh();
        }
    }
}
