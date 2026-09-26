.pragma library

// The layout tree, as plain functions without state (shell.qml keeps the tree itself and calls
// these; see "Layout tree" in CLAUDE.md). A node is a leaf { type: "leaf", ids: [...], ... } or a
// split { type: "split", dir: "h" | "v", ratio, a, b }, addressed by a path of "a" / "b".
// Functions ending in `At` change the tree they are given (shell.qml passes a clone).

// the node at `path`, or undefined when the tree has no such node (any more: a view of the tree it had
// before an import or a preset can still ask for one while it is being rebuilt)
function nodeAt(tree, path) {
    let n = tree;
    for (const k of path) n = n ? n[k] : undefined;
    return n;
}
// the leaf at `path`, or {} when there is no such leaf (any more)
function leafAt(tree, path) {
    let n = tree;
    for (const k of (path || [])) n = n ? n[k] : undefined;
    return n && n.type === "leaf" ? n : ({});
}
function walkLeaves(n, fn) {
    if (n.type === "leaf") fn(n);
    else { walkLeaves(n.a, fn); walkLeaves(n.b, fn); }
}
// every leaf with where it sits, as fractions 0..1 of the whole: [{ x, y, w, h, leaf }] in tile order
// (the presets' previews draw the tiles from this, ignoring the tiles' minimum sizes)
function leafRects(n, x, y, w, h) {
    const r = { x: x || 0, y: y === undefined ? 0 : y, w: w === undefined ? 1 : w, h: h === undefined ? 1 : h };
    if (n.type === "leaf") return [{ x: r.x, y: r.y, w: r.w, h: r.h, leaf: n }];
    if (n.dir === "h") return leafRects(n.a, r.x, r.y, r.w * n.ratio, r.h).concat(leafRects(n.b, r.x + r.w * n.ratio, r.y, r.w * (1 - n.ratio), r.h));
    return leafRects(n.a, r.x, r.y, r.w, r.h * n.ratio).concat(leafRects(n.b, r.x, r.y + r.h * n.ratio, r.w, r.h * (1 - n.ratio)));
}

// dir "h" = new tile to the right, "v" = new tile below
function splitAt(tree, path, dir) {
    const n = nodeAt(tree, path);
    const old = JSON.parse(JSON.stringify(n));
    Object.keys(n).forEach(k => delete n[k]);
    Object.assign(n, { type: "split", dir: dir, ratio: 0.5, a: old, b: { type: "leaf", ids: [] } });
}
// Close a tile: its sibling takes the whole space. The last tile is only emptied.
function closeAt(tree, path) {
    if (path.length === 0) { tree.ids = []; return; }
    const parent = nodeAt(tree, path.slice(0, -1));
    const sibling = parent[path[path.length - 1] === "a" ? "b" : "a"];
    Object.keys(parent).forEach(k => delete parent[k]);
    Object.assign(parent, sibling);
}

// A "cross": a split whose two children are both splits in the other direction (a 2x2-like
// junction). Its four line halves can be moved apart, but only one axis at a time: moving both
// axes' halves independently would leave a hole between the tiles.
function isCross(n) {
    return n.type === "split" && n.a.type === "split" && n.b.type === "split"
        && n.a.dir === n.b.dir && n.a.dir !== n.dir;
}
// Same tiles, other orientation: rows-of-columns becomes columns-of-rows. Only valid when the
// two children's dividers are aligned (within `alignTol`), which is when the halves of the
// *other* line are free. False when it did nothing.
function rotateCrossAt(tree, path, alignTol) {
    const s = nodeAt(tree, path);
    if (!isCross(s) || Math.abs(s.a.ratio - s.b.ratio) >= alignTol) return false;
    const A = s.a, B = s.b;
    const rotated = { type: "split", dir: A.dir, ratio: (A.ratio + B.ratio) / 2,
        a: { type: "split", dir: s.dir, ratio: s.ratio, a: A.a, b: B.a },
        b: { type: "split", dir: s.dir, ratio: s.ratio, a: A.b, b: B.b } };
    Object.keys(s).forEach(k => delete s[k]);
    Object.assign(s, rotated);
    return true;
}

//---------------------------------------------------------- cells
// size of one app cell for a given icon size, with or without the app names (the same formula
// AppCell.qml uses). Without names the icon has `cellPad(pad)` px around it on every side, `pad`
// being the tiles' padding (⚙ > Tiles > Padding; left out = the default, 14)
function cellPad(pad) { return pad === undefined ? 12 : Math.min(12, pad); }
function cellWidth(size, labels, pad) { return labels ? size * 2 + 4 : size + 2 * cellPad(pad); }
function cellHeight(size, labels, pad) { return labels ? size + 56 : size + 2 * cellPad(pad); }
// A tile's padding at the top: room for its title (or the "Launch all" corner button) when it has
// one; otherwise the padding, with a little more at the default sizes so the ⋯ button shown on hover
// does not sit on the icons (30 px at the default 14, shrinking with it to nothing at 0)
function padTop(spec, pad) {
    const header = (spec.title || "") !== "" || (spec.launchAll === true && spec.launchAllIcon !== true);
    return header ? Math.max(30, pad) : Math.max(pad, Math.min(30, pad * 30 / 14));
}
function padH(spec, m) { return padTop(spec, m.pad) + m.pad; }
function padW(m) { return 2 * m.pad; }
// "Launch all" shown as a regular cell among the apps: 1 while it takes up a cell's worth of
// space, so the grid and the tile's minimum size account for it, else 0.
function launchAllExtra(spec) { return spec.launchAll === true && spec.launchAllIcon === true ? 1 : 0; }
// `spec.ids` with `marker` spliced in at `launchAllIndex` (how many real ids come before it,
// clamped; default 0 = first), when "Launch all" is shown as a regular icon
function displayIds(spec, marker) {
    if (launchAllExtra(spec) === 0) return spec.ids;
    const out = spec.ids.slice();
    out.splice(Math.max(0, Math.min(spec.launchAllIndex || 0, out.length)), 0, marker);
    return out;
}

//---------------------------------------------------------- minimum size of a tile
// A tile is never smaller than what its icons need (Node.qml lays them out in a wrapping grid
// inside the tile's padding). `m` holds what that depends on, from shell.qml:
//   { icon: default icon size, labels: show names, gap: between tiles, cellGap: between cells,
//     pad: a tile's padding (see padTop() for the top) }

// the least height a tile needs to show all its icons when it is `w` wide
// The icon size a tile shows: `base`, or the largest smaller one at which its `n` cells fit the room inside it (w x h,
// what is left after the tile's padding), never less than `floor`. So icons shrink as apps are added or the tile
// gets smaller, instead of being cut off by the tile's edge. Before the tile has a size it is `base`.
function fitIcon(base, n, w, h, labels, pad, cellGap, floor) {
    if (!(n > 0) || !(w > 0) || !(h > 0)) return base;
    const lo = Math.min(base, floor);
    for (let s = base; s > lo; s--) {
        const cw = cellWidth(s, labels, pad);
        if (cw > w) continue;
        const cols = Math.max(1, Math.min(n, Math.floor((w + cellGap) / (cw + cellGap))));
        const rows = Math.ceil(n / cols);
        if (rows * cellHeight(s, labels, pad) + (rows - 1) * cellGap <= h) return s;
    }
    return lo;
}
// How many apps of a tile take room: `m.count(ids)` (the installed ones: a tile lists alternatives and only those
// show) when the shell gives it, else all of them
function idCount(spec, m) { return m.count ? m.count(spec.ids) : spec.ids.length; }
function leafMinH(spec, w, m) {
    const s = spec.icon || m.icon;
    const stride = cellWidth(s, m.labels, m.pad) + m.cellGap;
    const cols = Math.max(1, Math.floor((w - padW(m) + m.cellGap) / stride));
    const rows = Math.ceil(Math.max(1, idCount(spec, m) + launchAllExtra(spec)) / cols);
    return padH(spec, m) + rows * cellHeight(s, m.labels, m.pad) + (rows - 1) * m.cellGap;
}
// the least width a tile needs to show all its icons when it is `h` high (as few columns as fit)
function leafMinW(spec, h, m) {
    const s = spec.icon || m.icon;
    const n = Math.max(1, idCount(spec, m) + launchAllExtra(spec));
    let cols = 1; // if not even one row fits, more columns would not help
    for (let c = 1; c <= n; c++) {
        const rows = Math.ceil(n / c);
        if (padH(spec, m) + rows * cellHeight(s, m.labels, m.pad) + (rows - 1) * m.cellGap <= h) { cols = c; break; }
    }
    return padW(m) + cols * (cellWidth(s, m.labels, m.pad) + m.cellGap) - m.cellGap;
}
// The same for any node. Along its own direction a split needs the sum of its two sides. Across
// it, the sides share the box, and can trade: a narrow tile needs many rows, a wide one few. So
// the least height of side-by-side tiles (in `w`) is the smallest one where both still fit
// next to each other (found by bisection, since more height never needs more width). Each
// nested split then finds its own divider inside the box it gets (effRatio).
// the least size whatever the other side is: one row / one column of the biggest cell
function floorH(n, m) {
    if (n.type === "leaf") return padH(n, m) + cellHeight(n.icon || m.icon, m.labels, m.pad);
    return n.dir === "v" ? floorH(n.a, m) + floorH(n.b, m) + m.gap : Math.max(floorH(n.a, m), floorH(n.b, m));
}
function floorW(n, m) {
    if (n.type === "leaf") return padW(m) + cellWidth(n.icon || m.icon, m.labels, m.pad);
    return n.dir === "h" ? floorW(n.a, m) + floorW(n.b, m) + m.gap : Math.max(floorW(n.a, m), floorW(n.b, m));
}
function minH(n, w, m) {
    if (n.type === "leaf") return leafMinH(n, w, m);
    if (n.dir === "v") return minH(n.a, w, m) + minH(n.b, w, m) + m.gap;
    let hi = Math.max(minH(n.a, w * n.ratio, m), minH(n.b, w * (1 - n.ratio), m)); // the current ratio fits
    let lo = Math.min(hi, Math.max(floorH(n.a, m), floorH(n.b, m)));
    for (let i = 0; i < 9; i++) {
        const mid = (lo + hi) / 2;
        if (minW(n.a, mid, m) + minW(n.b, mid, m) + m.gap <= w) hi = mid; else lo = mid;
    }
    return hi;
}
function minW(n, h, m) {
    if (n.type === "leaf") return leafMinW(n, h, m);
    if (n.dir === "h") return minW(n.a, h, m) + minW(n.b, h, m) + m.gap;
    let hi = Math.max(minW(n.a, h * n.ratio, m), minW(n.b, h * (1 - n.ratio), m));
    let lo = Math.min(hi, Math.max(floorW(n.a, m), floorW(n.b, m)));
    for (let i = 0; i < 9; i++) {
        const mid = (lo + hi) / 2;
        if (minH(n.a, mid, m) + minH(n.b, mid, m) + m.gap <= h) hi = mid; else lo = mid;
    }
    return hi;
}
// The divider position of split `n` (in a box w x h) that respects both sides' minimum, as
// near to `ratio` as possible. When the box is too small for both, the space is shared in
// proportion to what each needs.
function effRatio(n, w, h, ratio, m) {
    const side = n.dir === "h";
    const total = side ? w : h;
    if (!(total > 0)) return ratio;
    const minA = side ? minW(n.a, h, m) : minH(n.a, w, m);
    const minB = side ? minW(n.b, h, m) : minH(n.b, w, m);
    const half = m.gap / 2;
    const lo = (minA + half) / total, hi = 1 - (minB + half) / total;
    if (lo > hi) return (minA + half) / (minA + minB + m.gap);
    return Math.max(lo, Math.min(hi, ratio));
}
