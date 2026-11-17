.pragma library

// Reading and writing the monitor rules of ~/.config/hypr/sylenara-monitors.lua (hl.monitor({ … })), without anything
// of Qt: the Displays service uses it and tests/qml/tst_displaylua.qml checks it.
// A rule here is { name, mode, x, y, scale, transform, vrr, mirror, disabled }; x and y are null while the position
// is "auto".

function luaString(s) {
    return String(s === undefined || s === null ? "" : s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n");
}

function numberOr(value, fallback) {
    const n = Number(value);
    return Number.isFinite(n) ? n : fallback;
}

function positionOf(rule) {
    return Number.isFinite(Number(rule.x)) && Number.isFinite(Number(rule.y)) && rule.x !== null && rule.y !== null
        ? `${Math.round(rule.x)}x${Math.round(rule.y)}`
        : "auto";
}

// One rule as the text of the Lua file
function block(rule) {
    let out = "hl.monitor({\n";
    out += `    output   = "${luaString(rule.name)}",\n`;
    if (rule.disabled) {
        out += `    disabled = true,\n`;
        return out + "})\n";
    }
    out += `    mode     = "${luaString(rule.mode)}",\n`;
    out += `    position = "${positionOf(rule)}",\n`;
    out += `    scale    = ${numberOr(rule.scale, 1) || 1},\n`;
    out += `    transform = ${Math.round(numberOr(rule.transform, 0))},\n`;
    if (rule.mirror)
        out += `    mirror   = "${luaString(rule.mirror)}",\n`;
    out += `    bitdepth = 8,\n`;
    out += `    vrr      = ${Math.round(numberOr(rule.vrr, 0))},\n`;
    return out + "})\n";
}

// The same rule on one line, for `hyprctl eval`
function inline(rule) {
    return block(rule).replace(/\n\s*/g, " ").replace("({ ", "({ ").replace(/, \}\)\s*$/, " })").replace(/,\s*$/, "");
}

// The rules written in a Lua file, in order
function parse(text) {
    const out = [];
    const rx = /hl\.monitor\s*\(\s*\{([^}]*)\}\s*\)/g;
    let m;
    while ((m = rx.exec(String(text || ""))) !== null) {
        const body = m[1];
        const str = key => {
            const k = body.match(new RegExp(`\\b${key}\\s*=\\s*"((?:[^"\\\\]|\\\\.)*)"`));
            return k ? k[1].replace(/\\"/g, "\"").replace(/\\\\/g, "\\") : null;
        };
        const num = key => {
            const k = body.match(new RegExp(`\\b${key}\\s*=\\s*(-?[0-9.]+)`));
            return k ? Number(k[1]) : null;
        };
        const name = str("output");
        if (!name)
            continue;
        const position = str("position") || "";
        const p = position.match(/^(-?\d+)x(-?\d+)$/);
        out.push({
            name: name,
            mode: str("mode"),
            x: p ? Number(p[1]) : null,
            y: p ? Number(p[2]) : null,
            scale: num("scale"),
            transform: num("transform") ?? 0,
            vrr: num("vrr"),
            mirror: str("mirror"),
            disabled: /\bdisabled\s*=\s*true\b/.test(body),
            text: m[0]
        });
    }
    return out;
}

function find(rules, name) {
    return rules.find(r => r.name === name) || null;
}

// The rules of outputs that are not plugged now, kept so what they remember (VRR, position…) survives
function unplugged(text, currentNames) {
    return parse(text).filter(r => !currentNames.includes(r.name));
}

// A mirror needs the output it copies to be there and to not be a mirror itself
function validMirror(name, target, monitors) {
    if (!target || target === name)
        return false;
    const other = monitors.find(m => m.name === target);
    return !!other && !other.disabled && !other.mirror;
}
