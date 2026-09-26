.pragma library

// Line icons of the menu tabs (MenuTabBar.qml), as SVG path data in a 24x24 box, drawn as strokes
// by MenuIcon.qml so their colour follows the tab state. Feather-style shapes.
var paths = {
    tiles: "M3 3h7v7H3z M14 3h7v7h-7z M14 14h7v7h-7z M3 14h7v7H3z",
    colors: "M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z",
    window: "M2 3h20v14H2z M8 21h8 M12 17v4",
    motion: "M13 2L3 14h9l-1 8 10-12h-9l1-8z",
    // "Effects" tab: two sparkles
    effects: "M10 3l1.9 5.1L17 10l-5.1 1.9L10 17l-1.9-5.1L3 10l5.1-1.9z M19 14l.9 2.1L22 17l-2.1.9L19 20l-.9-2.1L16 17l2.1-.9z",
    search: "M11 3a8 8 0 1 0 0 16a8 8 0 1 0 0-16z M21 21l-4.35-4.35",
    buttons: "M18.36 6.64a9 9 0 1 1-12.73 0 M12 2v10",
    keys: "M2 6h20v12H2z M6 10h.01 M10 10h.01 M14 10h.01 M18 10h.01 M7 14h10",
    general: "M4 21v-7 M4 10V3 M12 21v-9 M12 8V3 M20 21v-5 M20 12V3 M1 14h6 M9 8h6 M17 16h6",
    title: "M4 7V4h16v3 M9 20h6 M12 4v16",
    // panel width/height (SliderRow icons, ⚙ > Window): a double-headed arrow along the axis it resizes
    width: "M2 12h20 M2 12l5-5 M2 12l5 5 M22 12l-5-5 M22 12l-5 5",
    height: "M12 2v20 M12 2l-5 5 M12 2l5 5 M12 22l-5-5 M12 22l5-5",
    // "Menu size" (SliderRow icon, footer of every tab): the menu's own corners drawing outward
    scale: "M9 3H3v6 M15 3h6v6 M9 21H3v-6 M15 21h6v-6",
    // "Menu" tab (this settings panel's own look: size, background): three sliders, mid-drag
    menu: "M4 6h16 M4 6a2 2 0 104 0 2 2 0 10-4 0 M4 12h16 M14 12a2 2 0 104 0 2 2 0 10-4 0 M4 18h16 M8 18a2 2 0 104 0 2 2 0 10-4 0",
    // "Profiles" tab (whole configurations: presets, profiles, export / import): stacked layers
    profiles: "M12 2l10 5-10 5L2 7z M2 12l10 5 10-5 M2 17l10 5 10-5",
    // Dark / Light switch (⚙ > Colors)
    auto: "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z M12 3v18",
    moon: "M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z",
    sun: "M12 8a4 4 0 1 0 0 8a4 4 0 1 0 0-8z M12 1v2 M12 21v2 M4.22 4.22l1.42 1.42 M18.36 18.36l1.42 1.42 M1 12h2 M21 12h2 M4.22 19.78l1.42-1.42 M18.36 5.64l1.42-1.42"
};
