import QtQuick
import "../lib/fx.js" as Fx
import "controls"
import "previews"

// The one options popup, opened by the ⚙ button in the corner. Every global setting lives here,
// one tab per area, each tab an icon over its name (MenuTabBar.qml): Tiles (icons and tile look,
// resizing), Colors, Window (mode, panel size and edge offset), Effects (how it opens and closes,
// with a live preview of the one chosen), Search, Buttons (the all-apps and power strip), Keys, Menu
// (this menu's own look) and Profiles (presets and the welcome screen, profiles, export / import).
Rectangle {
    id: menu
    property var shell
    property bool open: false
    property real maxHeight: parent ? parent.height - 70 : 9999 // scrolls beyond this
    // `key` names what "Reset this tab" puts back (Overlay.resetTab)
    readonly property var tabs: [
        { t: "Tiles", icon: "tiles", key: "tiles" }, { t: "Colors", icon: "colors", key: "colors" },
        { t: "Window", icon: "window", key: "window" }, { t: "Effects", icon: "effects", key: "effects" },
        { t: "Search", icon: "search", key: "search" },
        { t: "Buttons", icon: "buttons", key: "buttons" }, { t: "Keys", icon: "keys", key: "keys" },
        { t: "Menu", icon: "menu", key: "menu" }, { t: "Profiles", icon: "profiles", key: "profiles" }
    ]
    property int tab: 0 // index in `tabs`
    readonly property int tabCount: tabs.length
    // every tab page is as tall as the tallest one (plus a little), so the menu keeps one size
    // whichever tab is open (it only grows while a colour picker is open)
    readonly property real pageH: Math.max(page0.natural, page1.natural, page2.natural, page3.natural, page4.natural,
                                            page5.natural, page6.natural, page7.natural, page8.natural) + 16

    visible: open

    // The menu window has the keyboard focus while it is open, so the shortcuts must work here too.
    // only the open menu holds the focus: with both menus at `focus: true` in the same window the
    // last one declared (TileMenu) always won, so Esc went to a menu that was not even showing
    focus: open
    Connections { target: menu.shell; function onMenuFocusRequested() { if (menu.open) menu.forceActiveFocus(); } }
    Keys.onPressed: event => {
        if (menu.shell.captureAction !== "") { menu.shell.captureKey(event); event.accepted = true; }
        else if (event.key === Qt.Key_Escape) { menu.shell.optionsOpen = false; event.accepted = true; }
        else if (menu.shell.handleKey(event)) event.accepted = true;
    }

    // Wider than tall: the tabs run along the top and every page lays its rows out in two columns
    // (`colW` each), filling left to right, then the next row.
    width: 720
    readonly property real colGap: 16
    readonly property real colW: (col.width - colGap) / 2
    // taller than the window (a short panel)? then it scrolls instead of being cut off
    height: Math.min(col.implicitHeight + 24 + headerH, maxHeight)
    radius: 0
    color: shell.paint("menuBg", null) // ⚙ > Menu > Menu background; "#313244" until changed
    // "Menu size" (shell.menuScale): the whole menu, text and controls, scaled about its centre
    scale: shell.menuScale
    // how far the scaled menu reaches past (or stays inside) its own box on each side
    readonly property real overX: width * (scale - 1) / 2
    readonly property real overY: height * (scale - 1) / 2
    border.width: 1
    border.color: shell.mBorder

    // Swallow clicks anywhere on the menu (not just its controls) so an idle spot in its chrome does
    // not fall through to the launcher's own click-away handling behind it. Declared before the
    // header below, so the header's own DragHandler still wins there.
    MouseArea { anchors.fill: parent; onClicked: {} }

    // Drag the menu by its header only: a DragHandler covering the whole menu would steal presses
    // meant for the sliders and other controls below it.
    property bool userMoved: false
    readonly property real headerH: 22
    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: menu.headerH
        Rectangle {
            anchors.centerIn: parent
            width: 36; height: 4; radius: 0
            color: menu.shell.mDim
            opacity: 0.6
        }
        DragHandler {
            target: menu
            cursorShape: Qt.SizeAllCursor
            // bounds of the scaled menu, so it can reach the screen edges but not leave them
            xAxis.minimum: menu.overX
            xAxis.maximum: menu.parent ? menu.parent.width - menu.width - menu.overX : 0
            yAxis.minimum: menu.overY
            yAxis.maximum: menu.parent ? menu.parent.height - menu.height - menu.overY : 0
            onActiveChanged: if (active) menu.userMoved = true
        }
    }

    Flickable {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: header.bottom
                  leftMargin: 12; rightMargin: 12; topMargin: 4; bottomMargin: 12 }
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 16

            MenuTabBar {
                shell: menu.shell
                width: col.width
                tabs: menu.tabs
                current: menu.tab
                onPicked: index => { menu.tab = index; }
            }

            // ---- Tiles: how the tiles and their icons look, and editing their layout
            MenuSection {
                id: page0
                index: 0
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width; gap: menu.colGap
                // the tiles as they look with the settings below, at half size
                TilesPreview { width: col.width; shell: menu.shell }
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Icon size"
                    showReset: true; resettable: !menu.shell.isDefault("icon")
                    onReset: menu.shell.resetSetting("icon")
                    unit: " px"
                    from: 24; to: 96; step: 4
                    value: menu.shell.iconSize
                    onPicked: v => menu.shell.setIcon(v)
                }
                MenuToggle {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Show names"
                    checked: menu.shell.showLabels
                    onToggled: menu.shell.showLabels = !menu.shell.showLabels
                }
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Tile gap"
                    showReset: true; resettable: !menu.shell.isDefault("gap")
                    onReset: menu.shell.resetSetting("gap")
                    unit: " px"
                    from: 0; to: 100; step: 2 // the space between the tiles: smaller <-> larger
                    value: menu.shell.tileGap
                    onPicked: v => menu.shell.setTileGap(v)
                }
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Padding"
                    showReset: true; resettable: !menu.shell.isDefault("padding")
                    onReset: menu.shell.resetSetting("padding")
                    unit: " px"
                    from: 0; to: 24; step: 1 // inside the tiles and around the icons: 0 = the icons almost touch the border
                    value: menu.shell.tilePadding
                    onPicked: v => menu.shell.setTilePadding(v)
                }
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Corner roundness"
                    showReset: true; resettable: !menu.shell.isDefault("radius")
                    onReset: menu.shell.resetSetting("radius")
                    unit: " px"
                    from: 0; to: 28; step: 2 // 0 = square corners, higher = rounder
                    value: menu.shell.tileRadius
                    onPicked: v => menu.shell.setTileRadius(v)
                }
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Border width"
                    showReset: true; resettable: !menu.shell.isDefault("borderWidth")
                    onReset: menu.shell.resetSetting("borderWidth")
                    unit: " px"
                    from: 1; to: 10; step: 1
                    value: menu.shell.tileBorderWidth
                    onPicked: v => menu.shell.setTileBorderWidth(v)
                }
                MenuChoice {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Tile buttons ＋ ⋯ (right-click opens the menu)"
                    options: [{ text: "After a pause", value: "pause" }, { text: "Right-click only", value: "click" }]
                    current: menu.shell.tileButtons
                    onChosen: value => menu.shell.tileButtons = value
                }
                MenuButton { // takes back the last change to the tiles (split, close, move, colours, ...)
                    shell: menu.shell; width: menu.colW
                    active: menu.shell.undoSteps > 0
                    label: "Undo tile change" + (menu.shell.undoSteps > 0 ? " (" + menu.shell.undoSteps + ")" : "")
                    onClicked: menu.shell.undoLayout()
                }
                MenuButton {
                    shell: menu.shell; width: menu.colW
                    active: menu.shell.redoSteps > 0
                    label: "Redo tile change" + (menu.shell.redoSteps > 0 ? " (" + menu.shell.redoSteps + ")" : "")
                    onClicked: menu.shell.redoLayout()
                }
                MenuButton { // drag the dividers in the launcher; Esc (or this button again) stops
                    shell: menu.shell; width: menu.colW
                    primary: menu.shell.resizeMode
                    label: menu.shell.resizeMode ? "Stop resizing" : "Resize tiles"
                    onClicked: menu.shell.resizeMode = !menu.shell.resizeMode
                }
            }

            // ---- Colors
            MenuSection {
                id: page1
                index: 1
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width; gap: menu.colGap
                // Every colour is the same control: System, Transparent, the 8 colours or any colour,
                // its opacity and ↺. A tile can override the border and the background (its ⋯ menu).
                // Dark or Light, and a live picture of the launcher in the one in use. Each mode keeps
                // its own set of colours, and the 8 colours themselves come in a vivid version for
                // Dark and a deeper one for Light, so every swatch below is shown as it will really look.
                Column {
                    width: col.width
                    spacing: 10
                    Item {
                        width: parent.width
                        height: 34
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text { text: "Mode"; color: menu.shell.mFg; font.pixelSize: 13 }
                            Text { text: "Dark and Light each keep their own colors. Auto follows Omarchy's light/dark setting"; color: menu.shell.mDim; font.pixelSize: 11 }
                        }
                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 6
                            Repeater {
                                model: [ { text: "Dark", value: "dark", icon: "moon" }, { text: "Light", value: "light", icon: "sun" }, { text: "Auto", value: "auto", icon: "auto" } ]
                                delegate: Rectangle {
                                    id: modeBtn
                                    required property var modelData
                                    readonly property bool on: menu.shell.theme === modelData.value
                                    width: modeRow.implicitWidth + 24
                                    height: 30
                                    radius: 0
                                    color: on ? Qt.rgba(menu.shell.accent.r, menu.shell.accent.g, menu.shell.accent.b, 0.14) : "transparent"
                                    border.width: 1
                                    border.color: on ? menu.shell.accent : (modeMa.containsMouse ? menu.shell.mDim : menu.shell.mBorder)
                                    Row {
                                        id: modeRow
                                        anchors.centerIn: parent
                                        spacing: 7
                                        MenuIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: modeBtn.modelData.icon; size: 15
                                            color: modeBtn.on ? menu.shell.accent : (modeMa.containsMouse ? menu.shell.mFg : menu.shell.mDim)
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modeBtn.modelData.text
                                            font.pixelSize: 12
                                            font.bold: modeBtn.on
                                            color: modeBtn.on ? menu.shell.accent : (modeMa.containsMouse ? menu.shell.mFg : menu.shell.mDim)
                                        }
                                    }
                                    MouseArea { id: modeMa; anchors.fill: parent; hoverEnabled: true; onClicked: menu.shell.setTheme(modeBtn.modelData.value) }
                                }
                            }
                        }
                    }
                    MenuToggle {
                        shell: menu.shell; fullWidth: parent.width
                        label: "Follow the Omarchy theme"
                        tip: "Uses the colors of the active Omarchy theme for System colors, the 8 swatches and the backgrounds, while its light or dark matches the mode in use. Off: the launcher's own colors."
                        checked: menu.shell.followTheme
                        onToggled: menu.shell.followTheme = !menu.shell.followTheme
                    }
                    ThemePreview { width: parent.width; shell: menu.shell }
                }
                ColorField {
                    shell: menu.shell; fullWidth: menu.colW
                    field: "accent"; label: "Accent color"
                }
                ColorField {
                    shell: menu.shell; fullWidth: menu.colW
                    field: "border"; label: "Border color"
                }
                ColorField {
                    shell: menu.shell; fullWidth: menu.colW
                    field: "bg"; label: "Background color (tiles)"
                }
                ColorField {
                    shell: menu.shell; fullWidth: menu.colW
                    field: "appBg"; label: "App background color (gap)"
                }
            }

            // ---- Window: where and how big the launcher window is (how it comes in is the Effects tab)
            MenuSection {
                id: page2
                index: 2
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width; gap: menu.colGap
                // where the launcher opens, on a mini screen, with the numbers that go with it
                WindowPreview { width: col.width; shell: menu.shell }
                MenuChoice {
                    shell: menu.shell; fullWidth: col.width // its own row, full width, above panel width/height below
                    label: "Mode"
                    options: [{ text: "Centered", value: "" }, { text: "Top", value: "top" }, { text: "Bottom", value: "bottom" },
                              { text: "Left", value: "left" }, { text: "Right", value: "right" }, { text: "Full screen", value: "full" }]
                    current: menu.shell.edge
                    onChosen: value => menu.shell.edge = value
                }
                MenuToggle {
                    shell: menu.shell; fullWidth: menu.colW
                    enabled: menu.shell.edge !== "" && menu.shell.edge !== "full"
                    label: "Open next to the bar button"
                    tip: "A panel opened with the bar button is centred on that button along its edge (top, bottom, left or right). Opened from a key it is centred on the screen as before."
                    checked: menu.shell.nextToBar
                    onToggled: menu.shell.nextToBar = !menu.shell.nextToBar
                }
                // Every row below stays on screen and merely dims when it does not apply to the
                // current "Mode", never hidden, so the tab (and with it the whole menu, every other
                // tab sharing its height) is the same size for Centered, an edge or Full screen
                // instead of visibly growing and shrinking as you try each one.
                Text { // beside the switch above, so the two share one row
                    width: menu.colW
                    height: 34
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    text: menu.shell.edge === "" ? "A centered window has no panel size to set. Pick a side, or Full screen."
                        : menu.shell.edge === "full" ? "Full screen has no size of its own to set."
                        : "How it comes in is set in the Effects tab."
                    color: menu.shell.mDim
                    font.pixelSize: 12
                }
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    icon: "width"
                    label: "Panel width"
                    showReset: true
                    resettable: menu.shell.defaultPanels[menu.shell.edge] !== undefined && menu.shell.panelW !== menu.shell.defaultPanels[menu.shell.edge][0]
                    onReset: menu.shell.setPanel(menu.shell.defaultPanels[menu.shell.edge][0], menu.shell.panelH)
                    enabled: menu.shell.edge !== "" && menu.shell.edge !== "full" // full screen has no size to set
                    unit: " %"
                    from: 5; to: 100; step: 5
                    value: menu.shell.panelW
                    onPicked: v => menu.shell.setPanel(v, menu.shell.panelH)
                }
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    icon: "height"
                    label: "Panel height"
                    showReset: true
                    resettable: menu.shell.defaultPanels[menu.shell.edge] !== undefined && menu.shell.panelH !== menu.shell.defaultPanels[menu.shell.edge][1]
                    onReset: menu.shell.setPanel(menu.shell.panelW, menu.shell.defaultPanels[menu.shell.edge][1])
                    enabled: menu.shell.edge !== "" && menu.shell.edge !== "full" // full screen has no size to set
                    unit: " %"
                    from: 5; to: 100; step: 5
                    value: menu.shell.panelH
                    onPicked: v => menu.shell.setPanel(menu.shell.panelW, v)
                }
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Edge offset"
                    tip: "How far the panel sits from the screen edge it slides in from. Each position (Top, Bottom, Left, Right) keeps its own."
                    showReset: true; resettable: !menu.shell.offsetIsDefault
                    onReset: menu.shell.resetOffset()
                    enabled: menu.shell.edge !== ""
                    unit: " px"
                    from: 0; to: 200; step: 4 // gap between the panel and the screen edge
                    value: menu.shell.offset
                    onPicked: v => menu.shell.setOffset(v)
                }
            }

            // ---- Effects: how the launcher comes in and goes out, the same in every mode
            MenuSection {
                id: page3
                index: 3
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width; gap: menu.colGap
                // the effect chosen, playing on a loop on a mini screen
                EffectPreview { width: col.width; shell: menu.shell }
                MenuChoice {
                    shell: menu.shell; fullWidth: col.width
                    label: menu.shell.reduceMotion ? "Effect (not shown while Reduce motion is on)" : "Effect"
                    options: [{ text: "Classic", value: "classic" }, { text: "Fade", value: "fade" }, { text: "Slide", value: "slide" },
                              { text: "Meet", value: "meet" }, { text: "Corners", value: "corners" }, { text: "Blocks", value: "blocks" },
                              { text: "Fluid", value: "fluid" }, { text: "Bounce", value: "bounce" }, { text: "Genie", value: "genie" },
                              { text: "Dissolve", value: "dissolve" }, { text: "Glitch", value: "glitch" },
                              // the last ten are the effects of Omarchy's screensaver (docs/effects.md), in the same one list
                              { text: "Matrix", value: "matrix" }, { text: "Decrypt", value: "decrypt" }, { text: "Synthgrid", value: "synthgrid" },
                              { text: "Spotlights", value: "spotlights" }, { text: "Laser etch", value: "laser" },
                              { text: "Blackhole", value: "blackhole" }, { text: "Fireworks", value: "fireworks" }, { text: "Rain", value: "rain" },
                              { text: "Beams", value: "beams" }, { text: "VHS tape", value: "vhs" }]
                    current: menu.shell.effect
                    onChosen: value => menu.shell.effect = value
                }
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Duration"
                    tip: "How long the launcher takes to open or close. Classic keeps its own length, so switching effect does not change it. At 0 it is instant."
                    showReset: true; resettable: !menu.shell.isDefault(menu.shell.fxOn ? "effectMs" : "speed")
                    onReset: menu.shell.resetAnimMs()
                    enabled: menu.shell.fxOn || menu.shell.edge !== ""
                    unit: " ms"
                    from: 0; to: 2000; step: 50
                    value: menu.shell.wantedMs
                    onPicked: v => menu.shell.setAnimMs(v)
                }
                MenuToggle {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Reduce motion"
                    tip: "The launcher opens and closes at once, with no effect or slide. Your effect and its length are kept for when this is off."
                    checked: menu.shell.reduceMotion
                    onToggled: menu.shell.reduceMotion = !menu.shell.reduceMotion
                }
                MenuToggle {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Animate closing"
                    tip: "Off: the launcher goes away at once and only the opening is animated."
                    checked: menu.shell.closeAnim
                    onToggled: menu.shell.closeAnim = !menu.shell.closeAnim
                }
                // the side slide and meet come from; every row stays on screen and dims when it does not apply. A docked
                // panel's slide always comes from its own edge.
                MenuChoice {
                    shell: menu.shell; fullWidth: menu.colW
                    label: menu.shell.effect === "meet" ? "Halves come from" : "Comes from"
                    enabled: menu.shell.effect === "meet" || (menu.shell.effect === "slide" && (menu.shell.edge === "" || menu.shell.edge === "full"))
                    options: menu.shell.effect === "meet"
                             ? [{ text: "Left and right", value: "left" }, { text: "Top and bottom", value: "top" }]
                             : [{ text: "Top", value: "top" }, { text: "Bottom", value: "bottom" }, { text: "Left", value: "left" }, { text: "Right", value: "right" }]
                    current: menu.shell.effect === "meet" ? (menu.shell.fullFrom === "top" || menu.shell.fullFrom === "bottom" ? "top" : "left") : menu.shell.fullFrom
                    onChosen: value => menu.shell.fullFrom = value
                }
            }

            // ---- Search: typing to filter, and searching every installed app
            MenuSection {
                id: page4
                index: 4
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width; gap: menu.colGap
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Search text size"
                    showReset: true; resettable: !menu.shell.isDefault("filterFontSize")
                    onReset: menu.shell.resetSetting("filterFontSize")
                    unit: " px"
                    from: 12; to: 42; step: 1
                    value: menu.shell.filterFontSize
                    onPicked: v => menu.shell.setFilterFontSize(v)
                }
                MenuToggle {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Allow all apps in search"
                    tip: "While typing, look through every installed app and not only the apps in your tiles. The matches replace the tiles."
                    checked: menu.shell.searchAll
                    onToggled: menu.shell.searchAll = !menu.shell.searchAll
                }
                MenuToggle { // only for the all-apps search results; the tiles follow "Show names"
                    shell: menu.shell; fullWidth: menu.colW
                    enabled: menu.shell.searchAll // dimmed, not hidden, while search is limited to the apps in your tiles
                    label: "Show names in search"
                    checked: menu.shell.searchLabels
                    onToggled: menu.shell.searchLabels = !menu.shell.searchLabels
                }
                MenuChoice { // the all-apps list and the typed search
                    shell: menu.shell; fullWidth: col.width
                    label: "Order of all apps and search results"
                    options: [{ text: "A to Z", value: "name" }, { text: "Most used first", value: "most_used" }, { text: "Most recent first", value: "recent" }]
                    current: menu.shell.usageOrder
                    onChosen: value => menu.shell.usageOrder = value
                }
                MenuToggle {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Remember the apps I launch"
                    tip: "Counts each launch, on this machine only (~/.local/state/gona-launcher/usage.json), so the order above can use it. Nothing is sent anywhere."
                    checked: menu.shell.trackUsage
                    onToggled: menu.shell.trackUsage = !menu.shell.trackUsage
                }
                MenuToggle {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Show a row of my most used apps"
                    tip: "A row above the tiles with the apps you launch most (or last, with \"Most recent first\"). It fills as you use the launcher, and needs \"Remember the apps I launch\"."
                    checked: menu.shell.showUsageRow
                    onToggled: menu.shell.showUsageRow = !menu.shell.showUsageRow
                }
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    enabled: menu.shell.showUsageRow // dimmed, not hidden, while the row is off
                    label: "Apps in the row"
                    from: 3; to: 10; step: 1
                    value: menu.shell.usageRowCount
                    showReset: true; resettable: !menu.shell.isDefault("usageRowCount")
                    onReset: menu.shell.resetSetting("usageRowCount")
                    onPicked: v => menu.shell.usageRowCount = v
                }
                MenuButton {
                    shell: menu.shell; width: menu.colW
                    active: menu.shell.usageCount > 0
                    label: menu.shell.usageCount > 0 ? "Clear history (" + menu.shell.usageCount + " apps)" : "Clear history"
                    onClicked: menu.shell.clearUsage()
                }
            }

            // ---- Buttons: the strip with the all-apps and power buttons
            MenuSection {
                id: page5
                index: 5
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width; gap: menu.colGap
                // The strip as the launcher draws it, on the side it really uses; the style, size and
                // background below all show up here as they change.
                ButtonsPreview { width: col.width; shell: menu.shell }
                // each button is switched on on its own; they share one strip
                MenuToggle { // flips the tiles over to every installed app
                    shell: menu.shell; fullWidth: menu.colW
                    label: "All apps"
                    tip: "Shows every installed app, without typing anything: the launcher grows to the whole screen. Press it again (or Esc) to go back to the tiles."
                    checked: menu.shell.allAppsButton
                    onToggled: menu.shell.allAppsButton = !menu.shell.allAppsButton
                }
                MenuToggle {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Shut down"
                    checked: menu.shell.powerOffButton
                    onToggled: menu.shell.powerOffButton = !menu.shell.powerOffButton
                }
                MenuToggle {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Restart"
                    checked: menu.shell.restartButton
                    onToggled: menu.shell.restartButton = !menu.shell.restartButton
                }
                MenuToggle {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Log out"
                    checked: menu.shell.logoutButton
                    onToggled: menu.shell.logoutButton = !menu.shell.logoutButton
                }
                MenuToggle { // the saved profiles (⚙ > Profiles) as buttons in the same strip
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Profile buttons"
                    tip: "Shows your profiles (up to 5, the default first) in the strip, next to the other buttons, to switch with a click. Needs one saved profile (⚙ > Profiles). Hover a button for its name."
                    checked: menu.shell.showProfileButtons
                    onToggled: menu.shell.showProfileButtons = !menu.shell.showProfileButtons
                }
                MenuChoice {
                    shell: menu.shell; fullWidth: menu.colW
                    enabled: menu.shell.showProfileButtons // dimmed, not hidden, while they are off
                    label: "Label profile buttons with"
                    options: [{ text: "1  2  3", value: "numbers" }, { text: "A  B  C", value: "letters" }, { text: "I  II  III", value: "roman" }]
                    current: menu.shell.profileLabels
                    onChosen: value => menu.shell.profileLabels = value
                }
                // the styles, each drawn with its own power button on the launcher's background
                Column {
                    width: col.width
                    spacing: 8
                    Text { text: "Button style"; color: menu.shell.mFg; font.pixelSize: 13 }
                    Row {
                        id: styleRow
                        spacing: 8
                        readonly property real cellW: (col.width - 8 * (menu.shell.iconThemes.length - 1)) / menu.shell.iconThemes.length
                        Repeater {
                            model: menu.shell.iconThemes
                            delegate: Rectangle {
                                id: styleCell
                                required property var modelData
                                readonly property bool on: menu.shell.iconTheme === modelData.value
                                width: styleRow.cellW; height: 64
                                radius: 0
                                color: menu.shell.solidBg
                                border.width: on ? 2 : 1
                                border.color: on ? menu.shell.accent : (styleMa.containsMouse ? menu.shell.mDim : menu.shell.mBorder)
                                Image {
                                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 9 }
                                    width: 32; height: 32
                                    source: menu.shell.iconFor(styleCell.modelData.value, "power-off")
                                    sourceSize: Qt.size(128, 128)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                }
                                Text {
                                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 7 }
                                    text: styleCell.modelData.text
                                    color: styleCell.on ? menu.shell.accent : menu.shell.fg
                                    font.pixelSize: 11
                                    font.bold: styleCell.on
                                }
                                MouseArea { id: styleMa; anchors.fill: parent; hoverEnabled: true; onClicked: menu.shell.iconTheme = styleCell.modelData.value }
                            }
                        }
                    }
                }
                SliderRow {
                    shell: menu.shell; fullWidth: menu.colW
                    label: "Button size"
                    showReset: true; resettable: !menu.shell.isDefault("powerButtonSize")
                    onReset: menu.shell.resetSetting("powerButtonSize")
                    unit: " px"
                    from: 20; to: 56; step: 2
                    value: menu.shell.powerButtonSize
                    onPicked: v => menu.shell.setPowerButtonSize(v)
                }
                ColorField { // Line / Square line draw only a stroke, no fill of their own; this
                    shell: menu.shell; fullWidth: menu.colW // gives them one to sit on. Off ("Transparent")
                    field: "powerBg"; label: "Button background"; hint: "Fills behind the buttons (mainly Line styles)." // by default, so the other, already-filled styles
                }                                              // do not gain a second background.
            }

            // ---- Keys: the configurable shortcuts
            MenuSection {
                id: page6
                index: 6
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width; gap: menu.colGap
                // First and set apart in the accent: the key that opens the launcher at all (Super alone,
                // a line the launcher keeps in Hyprland's bindings.lua, Overlay.setSuperMode())
                Rectangle {
                    width: col.width
                    height: superChoice.height + 20
                    radius: 0
                    color: Qt.rgba(menu.shell.accent.r, menu.shell.accent.g, menu.shell.accent.b, 0.10)
                    border.width: 1
                    border.color: menu.shell.accent
                    MenuChoice {
                        id: superChoice
                        shell: menu.shell; fullWidth: parent.width - 24
                        x: 12; y: 10
                        enabled: menu.shell.superAvailable
                        label: "Open with Super: press and release it alone"
                        options: [{ text: "Off", value: "off" }, { text: "Tiles", value: "tiles" }, { text: "All apps", value: "allApps" }]
                        current: menu.shell.superMode
                        onChosen: v => menu.shell.setSuperMode(v)
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 10 }
                        text: menu.shell.superAvailable ? "Saved in bindings.lua. Set Off before removing the plugin" : "Needs Hyprland's ~/.config/hypr/bindings.lua"
                        color: menu.shell.mDim
                        font.pixelSize: 11
                    }
                }
                // the help, on one row across both columns; a rejected combination replaces it there
                // (in red) instead of adding a row, so the shortcuts below never jump
                Text {
                    width: col.width
                    elide: Text.ElideRight
                    text: menu.shell.captureMessage !== "" ? menu.shell.captureMessage
                          : "Click a shortcut, then press the new keys  ·  Ctrl or Alt required  ·  Backspace disables  ·  Esc cancels"
                    color: menu.shell.captureMessage !== "" ? menu.shell.mDanger : menu.shell.mDim
                    font.pixelSize: 12
                }
                Repeater {
                    model: menu.shell.keyActions
                    delegate: Item {
                        required property var modelData
                        readonly property bool waiting: menu.shell.captureAction === modelData.name
                        readonly property string combo: menu.shell.comboFor(modelData.name)
                        width: menu.colW; height: 30
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; right: chip.left; rightMargin: 8 }
                            text: parent.modelData.label
                            elide: Text.ElideRight
                            color: menu.shell.mFg
                            font.pixelSize: 13
                        }
                        Rectangle {
                            id: chip
                            anchors { right: undoBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            width: 128; height: 26; radius: 0
                            color: "transparent"
                            border.width: 1
                            border.color: parent.waiting ? menu.shell.accent : (chipMa.containsMouse ? menu.shell.mDim : menu.shell.mBorder)
                            Text {
                                anchors.centerIn: parent
                                text: parent.parent.waiting ? "Press keys…" : (parent.parent.combo === "" ? "Disabled" : parent.parent.combo.split("+").join(" + "))
                                color: parent.parent.waiting ? menu.shell.accent : (parent.parent.combo === "" ? menu.shell.mDim : menu.shell.mFg)
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: chipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { menu.shell.startCapture(parent.parent.modelData.name); menu.forceActiveFocus(); }
                            }
                        }
                        Text { // back to the default combination
                            id: undoBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 18
                            text: "↺"
                            horizontalAlignment: Text.AlignHCenter
                            color: menu.shell.mDim
                            opacity: menu.shell.keys[parent.modelData.name] !== undefined ? 1 : 0.35
                            font.pixelSize: 15
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -5
                                enabled: menu.shell.keys[parent.parent.modelData.name] !== undefined
                                onClicked: menu.shell.resetKey(parent.parent.modelData.name)
                            }
                        }
                    }
                }
                Text {
                    width: col.width
                    elide: Text.ElideRight
                    text: "Fixed keys: arrows, Tab, Enter, Space, Esc, Ctrl +/-/0 (icon size), Alt+1…9 (nth app of the tile)"
                    color: menu.shell.mDim
                    font.pixelSize: 12
                }
            }

            // ---- Menu: this settings panel's own look, not the launcher's
            MenuSection {
                id: page7
                index: 7
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width; gap: menu.colGap
                ColorField {
                    shell: menu.shell; fullWidth: menu.colW
                    field: "menuBg"; label: "Menu background"
                }
                // Scales both this menu and TileMenu.qml. While the knob is dragged only the
                // number follows it (the menu resizing under the pointer would move the slider
                // away from it); the new size is applied on release. − and + apply at once.
                SliderRow {
                    id: menuSizeRow
                    shell: menu.shell; fullWidth: menu.colW
                    property int pending: 100
                    icon: "scale"
                    label: "Menu size"
                    showReset: true; resettable: !menu.shell.isDefault("menuScale")
                    onReset: menu.shell.resetSetting("menuScale")
                    unit: " %"
                    from: 70; to: 160; step: 5
                    value: dragging ? pending : menu.shell.menuScalePct
                    onPicked: v => { if (dragging) pending = v; else menu.shell.setMenuScale(v); }
                    onDraggingChanged: {
                        if (dragging) pending = menu.shell.menuScalePct;
                        else menu.shell.setMenuScale(pending);
                    }
                }
            }

            // ---- Profiles: whole configurations. The presets (the welcome screen of the first start), the saved
            // profiles, and export / import of the file in use
            MenuSection {
                id: page8
                index: 8
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width; gap: menu.colGap
                ProfilePicker { fullWidth: menu.colW; shell: menu.shell } // left: your profiles
                Column { // right: add one, back it up, start over
                    width: menu.colW
                    spacing: 20
                    Column { // the ready-made profiles (lib/presets.js): the welcome screen's cards, adding one
                        width: menu.colW
                        spacing: 8
                        Column {
                            width: parent.width
                            spacing: 2
                            Text { text: "Add a ready-made profile"; color: menu.shell.mFg; font.pixelSize: 13 }
                            Text { width: parent.width; wrapMode: Text.WordWrap; text: "Omarchy, Top, Dock, Focus or Clean, ready to use. It is added to your profiles and switched to; the ones you have stay as they are."; color: menu.shell.mDim; font.pixelSize: 11 }
                        }
                        MenuButton {
                            shell: menu.shell
                            width: parent.width
                            primary: true
                            label: menu.shell.profilesFull ? "Profiles are full (" + menu.shell.maxProfiles + ")" : "Browse ready-made profiles…"
                            active: !menu.shell.profilesFull
                            onClicked: menu.shell.openWelcome()
                        }
                    }
                    ConfigTransfer { fullWidth: menu.colW; shell: menu.shell }
                    FactoryReset { fullWidth: menu.colW; shell: menu.shell }
                }
            }

            // "Reset this tab" puts every setting of the open tab back to how it started (the Keys tab: the
            // shortcuts; Colors: the colours of the look in use). "Done" closes just this menu, like Esc:
            // the launcher stays open behind it, and the "Open / close ⚙ menu" shortcut (⚙ > Keys) brings
            // the menu back.
            Row {
                spacing: 8
                MenuButton {
                    shell: menu.shell
                    width: (col.width - 8) * 0.4
                    label: "Reset this tab"
                    onClicked: menu.shell.resetTab(menu.tabs[menu.tab].key)
                }
                MenuButton {
                    shell: menu.shell
                    width: (col.width - 8) * 0.6
                    primary: true
                    label: "Done"
                    onClicked: menu.shell.optionsOpen = false
                }
            }
        }
    }
}
