// The configuration the promo video runs on: a curated set of tiles and colours, and two more profiles, written
// as real config.toml files through the launcher's own toml.js / config.js. Usage: node demo-config.mjs <config dir>
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";

const root = new URL("../../app/lib/", import.meta.url);
function load(file, names) {
    const src = readFileSync(new URL(file, root), "utf8").replace(/^\.pragma library\s*$/m, "");
    return new Function("Qt", src + "\nreturn { " + names.join(", ") + " };")({});
}
const Toml = load("toml.js", ["stringify"]);
const Config = load("config.js", ["DEFAULTS", "toConfig", "COMMENTS"]);

const dir = process.argv[2];
mkdirSync(dir + "/profiles", { recursive: true });

const col = (v, a = 100) => ({ v, a });
const leaf = (title, ids, hex) => ({
    type: "leaf", ids, title, titleAlign: "left", titleBold: true, centerH: true, centerV: true,
    cBorder: col(hex, 90), cBg: col(hex, 16)
});
const split = (dir, ratio, a, b) => ({ type: "split", dir, ratio, a, b });

const layouts = {
    default: split("h", 0.52,
        split("v", 0.55,
            leaf("Work", ["zen", "code", "obsidian", "foot"], "#b794ff"),
            leaf("Files", ["org.gnome.Nautilus", "localsend", "bitwarden"], "#35d6e8")),
        split("v", 0.5,
            leaf("Social", ["Discord", "WhatsApp", "X", "YouTube"], "#ff6fae"),
            leaf("Create", ["com.obsproject.Studio", "org.kde.kdenlive", "com.github.PintaProject.Pinta", "mpv"], "#ffb454"))),
    games: split("h", 0.5,
        leaf("Play", ["com.moonlight_stream.Moonlight", "dev.lizardbyte.app.Sunshine", "mpv"], "#ffb454"),
        leaf("Stream", ["com.obsproject.Studio", "YouTube", "Discord"], "#ff6fae")),
    study: split("v", 0.5,
        leaf("Read", ["org.gnome.Evince", "obsidian", "zen"], "#35d6e8"),
        leaf("Write", ["libreoffice-writer", "libreoffice-calc", "com.github.xournalpp.xournalpp"], "#7ee787"))
};
const accents = { default: "#ff8ec1", games: "#ffb454", study: "#35d6e8" };

const base = {
    ...Config.DEFAULTS,
    edge: "", width: 1000, height: 520, effect: "fluid", effectMs: 800, offset: 12,
    icon: 56, gap: 10, radius: 0, borderWidth: 2, labels: true,
    searchAll: true, searchLabels: true, filterFontSize: 18,
    allAppsButton: true, powerOffButton: true, restartButton: true, logoutButton: true, powerButtonSize: 34, iconTheme: "line-square",
    showProfileButtons: true, profileLabels: "letters",
    theme: "dark", followTheme: false,
    trackUsage: false, showUsageRow: false
};
for (const [name, layout] of Object.entries(layouts)) {
    const settings = { ...base, colors: { accent: col(accents[name]), appBg: col("#12131e", 88) }, colorsLight: { accent: col("#c2185b"), appBg: col("#ffffff", 90) } };
    const text = Toml.stringify(Config.toConfig(settings, layout), Config.COMMENTS);
    writeFileSync(name === "default" ? dir + "/config.toml" : dir + "/profiles/" + name + ".toml", text);
}
console.log("demo config written to " + dir);
