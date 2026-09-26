.pragma library

// The opening / closing effects (⚙ > Effects): the timing curves and the geometry they need, as plain
// functions with no state. FxLayer.qml draws them with shaders/fx.frag; tests/logic.test.mjs tests this file.
//
//   ease(effect, opening, t)        the effect's own progress p from the linear slide t (0 hidden, 1 shown);
//                                   p may leave 0..1 (a spring overshoots), the shader knows
//   geometry(body, edge, anchor)    where the effect grows from: { origin, genieOrigin, dir }
//   bodyOf(edge, rect, offset)      the part of a docked panel's area the launcher itself covers
//   modeOf(effect)                  the number the shader switches on (0 = none)
//   slideDir(effect, edge, from)    the side slide comes from / the axis meet moves along
//   fromPoint(effect)               whether it grows from a point (the bar button, an edge, the centre) or plays in place

// "classic" is not here: it is the older per-mode behaviour (fade / slide / meet / corners / blocks)
var NAMES = ["fade", "slide", "meet", "corners", "blocks", "fluid", "bounce", "genie", "dissolve", "glitch", "matrix", "decrypt", "synthgrid", "spotlights", "laser", "blackhole", "fireworks", "rain", "beams", "vhs"];
var MODES = { fluid: 1, bounce: 2, genie: 3, dissolve: 4, glitch: 5, matrix: 6, decrypt: 7, synthgrid: 8, spotlights: 9, laser: 10, blackhole: 11, fireworks: 12, rain: 13, beams: 14, vhs: 15, fade: 16, slide: 17, meet: 18, corners: 19, blocks: 20 };
// the terminal effects (from Omarchy's screensaver): they play in place, so they do not start from a point (nor does glitch)
var TERMINAL = ["matrix", "decrypt", "synthgrid", "spotlights", "laser", "blackhole", "fireworks", "rain", "beams", "vhs"];
function fromPoint(effect) { return effect === "fluid" || effect === "bounce" || effect === "genie" || effect === "dissolve"; }
// the basic ones (the old full-screen styles): the ones with a side they come from are slide and meet
var BASIC = ["fade", "slide", "meet", "corners", "blocks"];
function hasSide(effect) { return effect === "slide" || effect === "meet"; }

function modeOf(effect) { return MODES[effect] || 0; }
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

// CSS cubic-bezier(x1, y1, x2, y2): y at the time t (found by bisection on x, so y may pass 1: a spring)
function bezier(x1, y1, x2, y2, t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    var lo = 0, hi = 1, s = t;
    for (var i = 0; i < 28; i++) {
        s = (lo + hi) / 2;
        var u = 1 - s;
        var x = 3 * u * u * s * x1 + 3 * u * s * s * x2 + s * s * s;
        if (x < t) lo = s; else hi = s;
    }
    var v = 1 - s;
    return 3 * v * v * s * y1 + 3 * v * s * s * y2 + s * s * s;
}

// the curve of each effect as the time s goes 0..1 (opening: 0 -> 1 and a bit beyond, closing: 0 -> 1)
function curve(effect, opening, s) {
    switch (effect) {
    case "fade":
        return opening ? bezier(0.3, 0, 0.4, 1, s) : bezier(0.6, 0, 0.7, 1, s);
    case "slide": case "meet": case "corners": case "blocks": // OutCubic in, InCubic out, like the panel slide always was
        return opening ? bezier(0.215, 0.61, 0.355, 1, s) : bezier(0.55, 0.055, 0.675, 0.19, s);
    case "fluid": // Material "expressive spatial" in, "emphasized accelerate" out: the shape springs past its size and settles
        return opening ? bezier(0.42, 1.67, 0.21, 0.90, s) : bezier(0.3, 0, 0.8, 0.15, s);
    case "bounce": // a damped spring in (about 24 % over, then 6 % under, then still); out: winds up, then drops
        return opening ? 1 - Math.exp(-5 * s) * Math.cos(s * Math.PI * 3.5) : s * s * (2.70158 * s - 1.70158);
    case "genie":
        return opening ? bezier(0.3, 0.05, 0.2, 1, s) : bezier(0.4, 0, 0.7, 0.2, s);
    case "dissolve":
        return bezier(0.4, 0, 0.2, 1, s);
    case "glitch":
        return opening ? bezier(0.2, 0.6, 0.3, 1, s) : bezier(0.6, 0, 0.9, 0.4, s);
    case "matrix": case "decrypt": case "synthgrid": case "spotlights": case "laser":
    case "blackhole": case "fireworks": case "rain": case "beams": case "vhs": // nearly linear: the effect itself is the motion
        return bezier(0.3, 0.2, 0.7, 0.8, s);
    }
    return s;
}

// t is the slide (0 hidden .. 1 shown) whichever way it is going: opening reads the curve forward,
// closing reads it from the shown end, so both start from what is on screen
function ease(effect, opening, t) {
    var x = clamp(t, 0, 1);
    if (x >= 1) return 1;
    if (x <= 0) return 0;
    return opening ? curve(effect, true, x) : 1 - curve(effect, false, 1 - x);
}

// rect: { x, y, w, h }. The area of a docked panel (or of full screen) has `offset` px of empty gap on the
// side(s) it slides from; the launcher is the rest.
function bodyOf(edge, rect, offset) {
    var l = edge === "left" || edge === "full" ? offset : 0;
    var t = edge === "top" || edge === "full" ? offset : 0;
    var r = edge === "right" || edge === "full" ? offset : 0;
    var b = edge === "bottom" || edge === "full" ? offset : 0;
    return { x: rect.x + l, y: rect.y + t, w: Math.max(1, rect.w - l - r), h: Math.max(1, rect.h - t - b) };
}

// Where an effect comes from. `body` is the launcher's rectangle, `edge` the mode ("" centred, top, bottom,
// left, right, full) and `anchor` the bar button that opened it ({ x, y } in the same coordinates) or null.
//   origin       the point fluid / bounce / dissolve grow from: on the edge it is docked to (the button's
//                position along it), else the button, else the centre
//   genieOrigin  the point genie is sucked into, and dir the unit vector (along an axis) from there to the
//                launcher; with no button a centred window is drawn into the bottom of the screen like a dock
function geometry(body, edge, anchor) {
    var cx = body.x + body.w / 2, cy = body.y + body.h / 2;
    var along = anchor ? { x: clamp(anchor.x, body.x, body.x + body.w), y: clamp(anchor.y, body.y, body.y + body.h) } : { x: cx, y: cy };
    if (edge === "top") return { origin: { x: along.x, y: body.y }, genieOrigin: { x: along.x, y: body.y }, dir: { x: 0, y: 1 } };
    if (edge === "bottom") return { origin: { x: along.x, y: body.y + body.h }, genieOrigin: { x: along.x, y: body.y + body.h }, dir: { x: 0, y: -1 } };
    if (edge === "left") return { origin: { x: body.x, y: along.y }, genieOrigin: { x: body.x, y: along.y }, dir: { x: 1, y: 0 } };
    if (edge === "right") return { origin: { x: body.x + body.w, y: along.y }, genieOrigin: { x: body.x + body.w, y: along.y }, dir: { x: -1, y: 0 } };
    if (!anchor) return { origin: { x: cx, y: cy }, genieOrigin: { x: cx, y: body.y + body.h }, dir: { x: 0, y: -1 } };
    // centred / full screen, opened from the button: the side of the launcher facing it
    var dx = cx - anchor.x, dy = cy - anchor.y;
    var inside = anchor.x >= body.x && anchor.x <= body.x + body.w && anchor.y >= body.y && anchor.y <= body.y + body.h;
    var dir, gen;
    if (inside) { // the nearest side, the origin brought onto it
        var dl = anchor.x - body.x, dr = body.x + body.w - anchor.x, dt = anchor.y - body.y, db = body.y + body.h - anchor.y;
        var m = Math.min(dl, dr, dt, db);
        if (m === dt) { dir = { x: 0, y: 1 }; gen = { x: anchor.x, y: body.y }; }
        else if (m === db) { dir = { x: 0, y: -1 }; gen = { x: anchor.x, y: body.y + body.h }; }
        else if (m === dl) { dir = { x: 1, y: 0 }; gen = { x: body.x, y: anchor.y }; }
        else { dir = { x: -1, y: 0 }; gen = { x: body.x + body.w, y: anchor.y }; }
    } else {
        dir = Math.abs(dx) > Math.abs(dy) ? { x: dx > 0 ? 1 : -1, y: 0 } : { x: 0, y: dy > 0 ? 1 : -1 };
        gen = { x: anchor.x, y: anchor.y };
    }
    return { origin: { x: anchor.x, y: anchor.y }, genieOrigin: gen, dir: dir };
}

// The unit vector toward the side a slide comes from (or, for meet, the axis its halves move along), in screen
// coordinates. A docked panel slides from its own edge; anything else from `from` ("top", "bottom", "left", "right").
function slideDir(effect, edge, from) {
    var side = effect === "slide" && (edge === "top" || edge === "bottom" || edge === "left" || edge === "right") ? edge : from;
    return side === "bottom" ? { x: 0, y: 1 } : side === "left" ? { x: -1, y: 0 } : side === "right" ? { x: 1, y: 0 } : { x: 0, y: -1 };
}

// The bar button's position on its screen, from where the bar's own window put it. The bar window spans
// its screen along its edge and is `barSize` thick, so along the edge the two agree and across it the window
// sits at the far side for a bottom or right bar. position: the bar's "top" | "bottom" | "left" | "right".
function screenPoint(x, y, position, screenW, screenH, winW, winH) {
    return { x: position === "right" ? x + screenW - winW : x, y: position === "bottom" ? y + screenH - winH : y };
}
