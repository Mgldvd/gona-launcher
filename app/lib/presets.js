.pragma library

// The presets: ready-made configurations shipped with the plugin (app/presets/<name>.toml, the format of
// config.toml). Choosing one copies it into the profile in use; the file itself is never changed. The
// welcome screen offers them on the first start, and ⚙ > Profiles > "Show the welcome screen" later.

// in the order the welcome screen shows them; the recommended one is what Enter picks at first
var LIST = [
    { name: "omarchy", title: "Omarchy", recommended: true,
      text: "The full one: full screen, Omarchy's apps in seven coloured tiles, larger icons on top, square corners, every option on." },
    { name: "top", title: "Top",
      text: "A panel from the top of the screen: four even tiles, Web, Work, Media and System." },
    { name: "dock", title: "Dock",
      text: "A dock along the bottom: one row of your apps in three coloured groups, large icons, no names." },
    { name: "focus", title: "Focus",
      text: "A small window, one row: only the tools to work with. Terminal, editor, browser, files, notes." },
    { name: "clean", title: "Clean",
      text: "One empty tile and the defaults, to build your own from nothing." }
];

var NAMES = LIST.map(function (p) { return p.name; });

function find(name) {
    for (var i = 0; i < LIST.length; i++) if (LIST[i].name === name) return LIST[i];
    return null;
}

// Where the launcher sits on a screen of sw x sh px with these settings (short names, as fromConfig() gives
// them; what is missing is the default), as fractions 0..1 of the screen: { x, y, w, h }. For the previews.
function launcherBox(settings, sw, sh) {
    var s = settings || {};
    var edge = s.edge || "";
    var off = typeof s.offset === "number" ? s.offset : 12;
    if (edge === "full") return { x: off / sw, y: off / sh, w: 1 - 2 * off / sw, h: 1 - 2 * off / sh };
    if (edge === "") {
        var w = Math.min(typeof s.width === "number" ? s.width : 900, sw - 80) / sw;
        var h = Math.min(typeof s.height === "number" ? s.height : 620, sh - 80) / sh;
        return { x: (1 - w) / 2, y: (1 - h) / 2, w: w, h: h };
    }
    var defaults = { top: [100, 50], bottom: [100, 50], left: [40, 100], right: [40, 100] };
    // not Array.isArray(): through a QML `var` property an array arrives as a list that is not a JS Array
    var p = s.panels && s.panels[edge] && s.panels[edge].length >= 2 ? s.panels[edge] : defaults[edge];
    var pw = p[0] / 100, ph = p[1] / 100;
    var ox = off / sw, oy = off / sh;
    if (edge === "top") return { x: (1 - pw) / 2, y: oy, w: pw, h: ph };
    if (edge === "bottom") return { x: (1 - pw) / 2, y: 1 - ph - oy, w: pw, h: ph };
    if (edge === "left") return { x: ox, y: (1 - ph) / 2, w: pw, h: ph };
    return { x: 1 - pw - ox, y: (1 - ph) / 2, w: pw, h: ph };
}
