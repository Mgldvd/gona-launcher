.pragma library

// The stored form of a colour field, as plain functions without state (shell.qml keeps the
// fields and resolves them; see "Colours" in CLAUDE.md). A field is { v, a }, either part may be
// missing: `v` is "system", "none", a palette index 0..paletteSize-1 or "#rrggbb"; `a` is the
// opacity 0..100.

function validValue(v, paletteSize) {
    return v === "system" || v === "none" || (typeof v === "number" && v >= 0 && v < paletteSize && v === Math.floor(v))
           || (typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v));
}
// a stored field with only its valid parts, or undefined when it has none
function cleanField(f, paletteSize) {
    if (!f || typeof f !== "object") return undefined;
    const o = {};
    if (validValue(f.v, paletteSize)) o.v = f.v;
    if (typeof f.a === "number" && f.a >= 0 && f.a <= 100) o.a = Math.round(f.a);
    return o.v === undefined && o.a === undefined ? undefined : o;
}
// change a field: `patch` = { v?, a? } merges into it, null resets it (undefined = delete it)
function patchField(old, patch, paletteSize) {
    return patch === null ? undefined : Object.assign({}, cleanField(old, paletteSize) || {}, patch);
}
// ---- surfaces and contrast (plain numbers, no Qt: an rgb is { r, g, b } with each part 0..1) ----
function parseHex(hex) {
    return { r: parseInt(hex.slice(1, 3), 16) / 255, g: parseInt(hex.slice(3, 5), 16) / 255, b: parseInt(hex.slice(5, 7), 16) / 255 };
}
function toHex(c) {
    const p = x => Math.round(Math.max(0, Math.min(1, x)) * 255).toString(16).padStart(2, "0");
    return "#" + p(c.r) + p(c.g) + p(c.b);
}
// `a` moved `t` (0..1) of the way to `b`
function mix(a, b, t) {
    return { r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t };
}
// `top` (with its own `a`, 0..1) painted over the opaque `bottom`: what the eye actually sees
function over(top, bottom) {
    const a = top.a === undefined ? 1 : top.a;
    return mix(bottom, top, a);
}
// perceived brightness, 0 (black) .. 1 (white)
function luminance(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b; }
// a surface this bright wants dark text
function isLight(c) { return luminance(c) > 0.5; }
