.pragma library

// Geometry of the arrangement of displays, without anything of Qt: Settings → Display (the canvas where the displays
// are dragged) and the Displays service use it, and tests/qml/tst_displaylayout.qml checks it.
// A display here is { name, x, y, w, h } in logical pixels, the units Hyprland positions use: the mode divided by
// the scale, and turned when the display is rotated.

// Hyprland transforms 1, 3, 5 and 7 turn the display a quarter (5 and 7 also flip it)
function isSideways(transform) {
    return Math.abs(Math.round(Number(transform) || 0)) % 2 === 1;
}

function logicalSize(width, height, scale, transform) {
    const s = Number(scale) > 0 ? Number(scale) : 1;
    const w = Math.round((Number(width) || 0) / s);
    const h = Math.round((Number(height) || 0) / s);
    return isSideways(transform) ? { w: h, h: w } : { w: w, h: h };
}

function overlaps(a, b) {
    return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

// Two displays touch when they share a piece of an edge: the pointer can cross from one to the other there
function touches(a, b) {
    const across = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x);
    const along = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y);
    const stacked = across > 0 && (a.y + a.h === b.y || b.y + b.h === a.y);
    const sideBySide = along > 0 && (a.x + a.w === b.x || b.x + b.w === a.x);
    return stacked || sideBySide;
}

function copy(list) {
    return list.map(d => Object.assign({}, d));
}

// The same arrangement, moved so it starts at 0,0
function normalize(list) {
    if (list.length === 0)
        return [];
    const minX = Math.min(...list.map(d => d.x));
    const minY = Math.min(...list.map(d => d.y));
    return list.map(d => Object.assign({}, d, { x: d.x - minX, y: d.y - minY }));
}

function bounds(list) {
    if (list.length === 0)
        return { x: 0, y: 0, w: 0, h: 0 };
    const minX = Math.min(...list.map(d => d.x));
    const minY = Math.min(...list.map(d => d.y));
    const maxX = Math.max(...list.map(d => d.x + d.w));
    const maxY = Math.max(...list.map(d => d.y + d.h));
    return { x: minX, y: minY, w: maxX - minX, h: maxY - minY };
}

function clamp(v, lo, hi) {
    return lo > hi ? (lo + hi) / 2 : Math.max(lo, Math.min(hi, v));
}

// The closest of the aligned positions when it is within `tolerance`, or the value itself
function align(v, targets, tolerance) {
    let best = v;
    let bestDist = tolerance;
    // On a tie the first target wins: the edges come before the centre
    for (const t of targets) {
        const d = Math.abs(t - v);
        if (d < bestDist || (best === v && d <= bestDist)) {
            best = t;
            bestDist = d;
        }
    }
    return best;
}

// Where display `index` lands when it is dropped with its corner at (x, y): against an edge of another display,
// sharing at least `minShare` pixels of it, aligned with its start, centre or end when it is close, and never on
// top of any display. With nothing else to touch it stays where it is.
function snap(list, index, x, y, options) {
    const opts = Object.assign({ minShare: 64, alignTolerance: 0.15 }, options || {});
    const me = list[index];
    const others = list.filter((_, i) => i !== index);
    if (others.length === 0)
        return { x: Math.round(x), y: Math.round(y) };

    let best = null;
    const consider = (cx, cy) => {
        const spot = { x: Math.round(cx), y: Math.round(cy), w: me.w, h: me.h };
        if (others.some(o => overlaps(spot, o)))
            return;
        const d = Math.hypot(spot.x - x, spot.y - y);
        if (!best || d < best.d)
            best = { x: spot.x, y: spot.y, d: d };
    };

    for (const o of others) {
        const share = Math.min(opts.minShare, me.h, o.h);
        const tolY = opts.alignTolerance * Math.min(me.h, o.h);
        const sideY = align(clamp(y, o.y - me.h + share, o.y + o.h - share), [o.y, o.y + (o.h - me.h) / 2, o.y + o.h - me.h], tolY);
        consider(o.x + o.w, sideY);
        consider(o.x - me.w, sideY);

        const shareX = Math.min(opts.minShare, me.w, o.w);
        const tolX = opts.alignTolerance * Math.min(me.w, o.w);
        const stackX = align(clamp(x, o.x - me.w + shareX, o.x + o.w - shareX), [o.x, o.x + (o.w - me.w) / 2, o.x + o.w - me.w], tolX);
        consider(stackX, o.y + o.h);
        consider(stackX, o.y - me.h);
    }
    return best ? { x: best.x, y: best.y } : { x: Math.round(x), y: Math.round(y) };
}

// Groups of displays that touch each other, as lists of indexes; the first group holds `index`
function groups(list, index) {
    const seen = new Array(list.length).fill(false);
    const out = [];
    const order = [index, ...list.map((_, i) => i).filter(i => i !== index)];
    for (const start of order) {
        if (start < 0 || start >= list.length || seen[start])
            continue;
        const group = [];
        const stack = [start];
        seen[start] = true;
        while (stack.length) {
            const i = stack.pop();
            group.push(i);
            for (let j = 0; j < list.length; j++) {
                if (!seen[j] && touches(list[i], list[j])) {
                    seen[j] = true;
                    stack.push(j);
                }
            }
        }
        out.push(group);
    }
    return out;
}

// Moving a display can leave others apart (the middle one of three, taken to an end): each loose display is snapped
// again where it is, so the pointer can always reach every display. Display `keep` does not move.
function joinUp(list, keep) {
    let out = copy(list);
    for (let round = 0; round < out.length; round++) {
        const parts = groups(out, keep);
        if (parts.length <= 1)
            break;
        const main = parts[0];
        // The loose display closest to the main group goes first
        // Qt's JavaScript has no Array.flat
        const loose = [].concat(...parts.slice(1));
        const box = bounds(main.map(i => out[i]));
        loose.sort((a, b) => distanceTo(out[a], box) - distanceTo(out[b], box));
        const i = loose[0];
        const placed = snap(out.filter((_, k) => main.includes(k) || k === i), mainIndexOf(out, main, i), out[i].x, out[i].y);
        out[i] = Object.assign({}, out[i], placed);
    }
    return out;
}

function mainIndexOf(list, main, i) {
    // Index of `i` inside the list made of the main group plus `i`, in the original order
    return list.map((_, k) => k).filter(k => main.includes(k) || k === i).indexOf(i);
}

function distanceTo(d, box) {
    const cx = d.x + d.w / 2;
    const cy = d.y + d.h / 2;
    const dx = Math.max(box.x - cx, 0, cx - (box.x + box.w));
    const dy = Math.max(box.y - cy, 0, cy - (box.y + box.h));
    return Math.hypot(dx, dy);
}

// Display `index` dropped at (x, y): its place, the rest joined up to it, and the whole moved to start at 0,0
function drop(list, index, x, y, options) {
    const out = copy(list);
    const placed = snap(out, index, x, y, options);
    out[index] = Object.assign({}, out[index], placed);
    return normalize(joinUp(out, index));
}

// Numbers people read on the canvas and on the screens: left to right, then top to bottom
function numbering(list) {
    const order = list.map((d, i) => i).sort((a, b) => (list[a].x - list[b].x) || (list[a].y - list[b].y));
    const out = {};
    order.forEach((i, n) => out[list[i].name] = n + 1);
    return out;
}

function samePositions(a, b) {
    if (a.length !== b.length)
        return false;
    const byName = {};
    for (const d of b)
        byName[d.name] = d;
    return a.every(d => byName[d.name] && byName[d.name].x === d.x && byName[d.name].y === d.y);
}

function positionString(x, y) {
    return `${Math.round(x)}x${Math.round(y)}`;
}
