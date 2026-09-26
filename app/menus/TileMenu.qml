import QtQuick
import "controls"

// The menu of ONE tile, opened by the ⋯ button in the tile's corner. It has every option of the
// tile in one place: split it, add apps, icon size, colour (border, tinted background and how
// light or dark it is), alignment, and removing the tile. It lives in a window of its own,
// centred on the screen (see shell.qml), and edits the tile named by `shell.tileMenuPath`.
Rectangle {
    id: menu
    property var shell
    property real maxHeight: 800 // taller than this: the content scrolls

    readonly property var path: shell.tileMenuPath
    readonly property var spec: shell.leafAt(path) // the tile's data, {} if it is gone
    property int tab: 0 // 0 General, 1 Title, 2 Colors
    readonly property int tabCount: 3
    readonly property real pageH: Math.max(page0.natural, page1.natural, page2.natural) + 8
    property bool confirming: false // asking whether to remove a tile that has apps
    onPathChanged: { tab = 0; confirming = false; fontList.visible = false; }
    readonly property bool onlyTile: path !== null && path.length === 0 // the last tile cannot be removed

    width: 310

    // The menu window has the keyboard focus while it is open, so the shortcuts must work here too.
    focus: visible
    Connections { target: menu.shell; function onMenuFocusRequested() { if (menu.visible) menu.forceActiveFocus(); } }
    Keys.onPressed: event => {
        if (menu.shell.captureAction !== "") { menu.shell.captureKey(event); event.accepted = true; }
        else if (event.key === Qt.Key_Escape) { menu.shell.closeTileMenu(); event.accepted = true; }
        else if (menu.shell.handleKey(event)) event.accepted = true;
    }
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
            spacing: 12

            // ---- title, with the tile in miniature (its own colours)
            Row {
                spacing: 8
                Rectangle { // this tile in miniature, with its own border and background over the launcher's
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 24; radius: 0
                    color: menu.shell.solidBg
                    border.width: 1
                    border.color: menu.shell.mBorder
                    Rectangle {
                        anchors { fill: parent; margins: 3 }
                        radius: 0
                        color: menu.shell.paint("bg", menu.spec)
                        border.width: 2
                        border.color: menu.shell.paint("border", menu.spec)
                    }
                }
                Text { text: "Tile"; color: menu.shell.mFg; font.pixelSize: 15; font.bold: true }
            }

            // ---- actions
            Row {
                spacing: 6
                readonly property real w: (col.width - 12) / 3
                MenuButton { shell: menu.shell; width: parent.w; label: "Split →"; onClicked: { menu.shell.split(menu.path, "h"); menu.shell.closeTileMenu(); } }
                MenuButton { shell: menu.shell; width: parent.w; label: "Split ↓"; onClicked: { menu.shell.split(menu.path, "v"); menu.shell.closeTileMenu(); } }
                MenuButton { shell: menu.shell; width: parent.w; label: "＋ Add apps"; onClicked: { menu.shell.pickingPath = menu.path; menu.shell.closeTileMenu(); } }
            }

            MenuTabBar {
                shell: menu.shell
                width: col.width
                tabs: [{ t: "General", icon: "general" }, { t: "Title", icon: "title" }, { t: "Colors", icon: "colors" }]
                current: menu.tab
                onPicked: index => { menu.tab = index; }
            }

            MenuPage {
                id: page0
                index: 0
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width
            MenuGroup {
                shell: menu.shell; fullWidth: col.width
                label: "Icon"
                // icon size of this tile, with ↺ to go back to the default size
                SliderRow {
                    shell: menu.shell; fullWidth: parent.width
                    label: "Size"
                    unit: " px"
                    from: 24; to: 96; step: 4
                    value: menu.spec.icon || menu.shell.iconSize
                    resettable: menu.spec.icon !== undefined
                    onPicked: v => menu.shell.setTileIcon(menu.path, v)
                    onReset: menu.shell.clearTileIcon(menu.path)
                }
            }

            MenuGroup {
                shell: menu.shell; fullWidth: col.width
                label: "Launch"
                // shows an icon on the tile that opens every app in it with one click
                MenuCheck {
                    shell: menu.shell
                    label: "Launch all apps"
                    checked: menu.spec.launchAll === true
                    onToggled: menu.shell.setTileFlag(menu.path, "launchAll", !checked)
                }
                // that icon: a small button in the tile's corner, or a regular cell in the grid,
                // the same size as the app icons
                MenuCheck {
                    shell: menu.shell
                    label: "Show as a regular icon"
                    active: menu.spec.launchAll === true
                    checked: menu.spec.launchAllIcon === true
                    onToggled: menu.shell.setTileFlag(menu.path, "launchAllIcon", !checked)
                }
            }

            MenuGroup {
                shell: menu.shell; fullWidth: col.width
                label: "Alignment"
                MenuCheck {
                    shell: menu.shell
                    label: "Center horizontally"
                    checked: menu.spec.centerH === true
                    onToggled: menu.shell.setTileFlag(menu.path, "centerH", !checked)
                }
                MenuCheck {
                    shell: menu.shell
                    label: "Center vertically"
                    checked: menu.spec.centerV === true
                    onToggled: menu.shell.setTileFlag(menu.path, "centerV", !checked)
                }
            }
            }

            MenuPage {
                id: page1
                index: 1
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width
            MenuGroup {
                shell: menu.shell; fullWidth: col.width
                label: "Text"
                // shown along the top edge of the tile; empty = no title
                Rectangle {
                    width: parent.width; height: 30; radius: 0
                    color: menu.shell.mField
                    border.width: titleInput.activeFocus ? 1 : 0
                    border.color: menu.shell.accent
                    Text {
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        visible: titleInput.text === ""
                        text: "Tile title"
                        color: menu.shell.mDim
                        font.pixelSize: 13
                    }
                    TextInput {
                        id: titleInput
                        anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        color: menu.shell.mFg
                        font.pixelSize: 13
                        selectByMouse: true
                        text: menu.spec.title || ""
                        // saved shortly after the last key, since each save rebuilds the tiles
                        onTextEdited: titleSave.restart()
                        onAccepted: { titleSave.stop(); menu.shell.setTileTitle(menu.path, text); focus = false; menu.shell.menuFocusRequested(); }
                        Keys.onEscapePressed: { focus = false; menu.shell.menuFocusRequested(); }
                    }
                    Timer { id: titleSave; interval: 300; onTriggered: menu.shell.setTileTitle(menu.path, titleInput.text) }
                    TapHandler { onTapped: titleInput.forceActiveFocus() }
                }
            }

            MenuGroup {
                shell: menu.shell; fullWidth: col.width
                label: "Font"
                // the font: a family (opens a list, each name in its own font), bold and italic
                Row {
                    id: fontRow
                    width: parent.width // (a Row has no width of its own: the field below is sized from it)
                    spacing: 4
                    Rectangle {
                        width: parent.width - 2 * (30 + 4); height: 30; radius: 0
                        color: menu.shell.mField
                        border.width: fontList.visible ? 1 : 0
                        border.color: menu.shell.accent
                        Text {
                            anchors { left: parent.left; leftMargin: 10; right: fontArrow.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: menu.spec.titleFont || "Default font"
                            elide: Text.ElideRight
                            color: menu.spec.titleFont ? menu.shell.mFg : menu.shell.mDim
                            font.pixelSize: 13
                        }
                        Text { id: fontArrow; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                               text: fontList.visible ? "▴" : "▾"; color: menu.shell.mDim; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; onClicked: fontList.visible = !fontList.visible }
                    }
                    Repeater {
                        model: [{ text: "B", key: "titleBold", on: menu.spec.titleBold !== false },
                                { text: "I", key: "titleItalic", on: menu.spec.titleItalic === true }]
                        delegate: Rectangle {
                            required property var modelData
                            width: 30; height: 30; radius: 0
                            color: "transparent"
                            border.width: 1
                            border.color: modelData.on ? menu.shell.accent : (styleMa.containsMouse ? menu.shell.mDim : menu.shell.mBorder)
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.text
                                color: parent.modelData.on ? menu.shell.accent : menu.shell.mDim
                                font.pixelSize: 14
                                font.bold: parent.modelData.text === "B"
                                font.italic: parent.modelData.text === "I"
                            }
                            MouseArea {
                                id: styleMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: menu.shell.setTileTitleStyle(menu.path, parent.modelData.key, !parent.modelData.on)
                            }
                        }
                    }
                }
                Rectangle { // the list of fonts, only while open
                    id: fontList
                    visible: false
                    width: parent.width; height: 160; radius: 0
                    color: menu.shell.mField
                    clip: true
                    ListView {
                        anchors.fill: parent
                        anchors.margins: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: [""].concat(Qt.fontFamilies()) // "" = the default font
                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool on: (menu.spec.titleFont || "") === modelData
                            width: ListView.view.width; height: 26; radius: 0
                            color: on ? Qt.rgba(1, 1, 1, 0.12) : (fontMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            Text {
                                anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: parent.modelData === "" ? "Default font" : parent.modelData
                                font.family: parent.modelData === "" ? Qt.application.font.family : parent.modelData
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                color: parent.on ? menu.shell.accent : menu.shell.mFg
                            }
                            MouseArea {
                                id: fontMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { menu.shell.setTileTitleStyle(menu.path, "titleFont", parent.modelData); fontList.visible = false; }
                            }
                        }
                    }
                }
            }

            MenuGroup {
                shell: menu.shell; fullWidth: col.width
                label: "Position"
                // where the title sits on the tile
                Row {
                    spacing: 4
                    readonly property real w: (parent.width - 8) / 3
                    Repeater {
                        model: [{ text: "Left", value: "left" }, { text: "Center", value: "center" }, { text: "Right", value: "right" }]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool on: (menu.spec.titleAlign || "left") === modelData.value
                            width: parent.w; height: 26; radius: 0
                            color: "transparent"
                            border.width: 1
                            border.color: on ? menu.shell.accent : (alignMa.containsMouse ? menu.shell.mDim : menu.shell.mBorder)
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.text
                                color: parent.on ? menu.shell.accent : (alignMa.containsMouse ? menu.shell.mFg : menu.shell.mDim)
                                font.pixelSize: 12
                                font.bold: parent.on
                            }
                            MouseArea {
                                id: alignMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: menu.shell.setTileTitleAlign(menu.path, parent.modelData.value)
                            }
                        }
                    }
                }
            }
            }

            MenuPage {
                id: page2
                index: 2
                current: menu.tab; pageH: menu.pageH; fullWidth: col.width
            MenuGroup {
                shell: menu.shell; fullWidth: col.width
                label: "Border"
                ColorField {
                    shell: menu.shell; fullWidth: parent.width
                    field: "border"; path: menu.path; label: "Color"
                }
            }

            MenuGroup {
                shell: menu.shell; fullWidth: col.width
                label: "Background"
                ColorField {
                    shell: menu.shell; fullWidth: parent.width
                    field: "bg"; path: menu.path; label: "Color"
                }
            }
            }

            // ---- remove the tile (its sibling takes the space; the apps in it are dropped from the
            // layout). The only tile left cannot be removed, it is just emptied. A tile with apps in it
            // asks first, so it is not deleted by accident.
            Text {
                visible: menu.confirming
                width: col.width
                wrapMode: Text.WordWrap
                readonly property int count: (menu.spec.ids || []).length
                text: (menu.onlyTile ? "Remove all " : "Remove this tile and its ") + count
                      + (count === 1 ? " app from it?" : " apps from it?")
                color: menu.shell.mFg
                font.pixelSize: 13
            }
            Row {
                spacing: 8
                readonly property real w: (col.width - 8) / 2
                MenuButton {
                    shell: menu.shell
                    width: parent.w
                    danger: true
                    label: menu.confirming ? "Yes, " + (menu.onlyTile ? "clear" : "remove") : (menu.onlyTile ? "Clear tile" : "Remove tile")
                    onClicked: {
                        if (!menu.confirming && (menu.spec.ids || []).length > 0) { menu.confirming = true; return; }
                        menu.shell.closeNode(menu.path);
                        menu.shell.closeTileMenu();
                    }
                }
                MenuButton {
                    shell: menu.shell
                    width: parent.w
                    primary: !menu.confirming
                    label: menu.confirming ? "Cancel" : "Done"
                    onClicked: { if (menu.confirming) menu.confirming = false; else menu.shell.closeTileMenu(); }
                }
            }
        }
    }
}
