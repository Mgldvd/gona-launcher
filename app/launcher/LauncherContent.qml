import QtQuick

// Everything the launcher shows: background, tiles, options menu, app picker. It is placed in
// either window kind (the floating window or the edge-docked slide-in panel), see shell.qml.
Item {
    id: content
    property var shell
    // reserved strip below the tiles for the power/all-apps button row when it is docked there
    // (bottom edge); 0 when that row is off, so the tiles get the full height
    readonly property real footerH: (shell.stripOn && shell.powerSide === "bottom") ? shell.powerButtonSize + 8 : 0

    focus: true
    Component.onCompleted: shell.dragOverlay = dragLayer

    Keys.onEscapePressed: {
        if (shell.helpOpen) shell.helpOpen = false;
        else if (shell.captureAction !== "") { shell.captureAction = ""; shell.captureMessage = ""; } // cancels a shortcut being set
        else if (shell.optionsOpen) shell.optionsOpen = false;
        else if (shell.tileMenuPath !== null) shell.closeTileMenu();
        else if (shell.filterText !== "" || shell.selectedId !== "") { shell.filterText = ""; shell.selectedId = ""; }
        else if (shell.allAppsOpen) shell.allAppsOpen = false;
        else if (shell.resizeMode) shell.resizeMode = false;
        else if (shell.pickingPath !== null) shell.pickingPath = null;
        else shell.hide();
    }

    // Keyboard navigation: Tab / Shift+Tab step through the apps, arrows move to the nearest one,
    // Enter launches the selected app (Space too, when no filter is being typed).
    Keys.onTabPressed: event => {
        if (shell.captureAction !== "") { shell.captureKey(event); event.accepted = true; return; }
        if (shell.handleKey(event)) { event.accepted = true; return; } // Ctrl+Tab and the like
        if (shell.pickingPath === null) { shell.selectStep(1); event.accepted = true; }
    }
    Keys.onBacktabPressed: event => {
        if (shell.captureAction !== "") { shell.captureKey(event); event.accepted = true; return; }
        if (shell.handleKey(event)) { event.accepted = true; return; }
        if (shell.pickingPath === null) { shell.selectStep(-1); event.accepted = true; }
    }
    Keys.onReturnPressed: event => { if (shell.pickingPath === null) { shell.launchSelected(); event.accepted = true; } }
    Keys.onEnterPressed: event => { if (shell.pickingPath === null) { shell.launchSelected(); event.accepted = true; } }

    Keys.onPressed: event => {
        // the shortcut list is open: any key closes it
        if (shell.helpOpen) { shell.helpOpen = false; event.accepted = true; return; }
        // waiting for a new shortcut (⚙ > Keys): every key goes to it; then the configurable shortcuts
        if (shell.captureAction !== "") { shell.captureKey(event); event.accepted = true; return; }
        if (shell.handleKey(event)) { event.accepted = true; return; }
        // Ctrl + / Ctrl - / Ctrl 0 and Ctrl+wheel change the icon size
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) shell.adjustIcon(4);
            else if (event.key === Qt.Key_Minus) shell.adjustIcon(-4);
            else if (event.key === Qt.Key_0) shell.resetIcon();
            else return;
            event.accepted = true;
            return;
        }
        // ? or F1 lists the shortcuts (a ? typed into a filter is just a character); the Menu key and Shift+F10 open the
        // menu of the selected app's tile
        if (event.key === Qt.Key_F1 || (event.text === "?" && shell.filterText === "" && shell.pickingPath === null)) { shell.helpOpen = true; event.accepted = true; return; }
        if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            if (shell.pickingPath === null && !shell.searchingAll) { shell.openSelectedTileMenu(); event.accepted = true; }
            return;
        }
        // Type to filter: letters and digits start it; once started, any printable key extends it.
        if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) return;
        if (shell.pickingPath !== null) return; // the app picker has a search box of its own
        switch (event.key) {
        case Qt.Key_Left:  shell.selectDir(-1, 0); event.accepted = true; return;
        case Qt.Key_Right: shell.selectDir(1, 0);  event.accepted = true; return;
        case Qt.Key_Up:    shell.selectDir(0, -1); event.accepted = true; return;
        case Qt.Key_Down:  shell.selectDir(0, 1);  event.accepted = true; return;
        case Qt.Key_Space: // launches the selection, unless a filter is being typed (then it is a space)
            if (shell.filterText === "") { shell.launchSelected(); event.accepted = true; return; }
            break;
        }
        if (event.key === Qt.Key_Backspace) {
            if (shell.filterText !== "") { shell.filterText = shell.filterText.slice(0, -1); event.accepted = true; }
            return;
        }
        const t = event.text;
        if (t.length !== 1 || t.charCodeAt(0) < 32) return;
        const isLetterOrDigit = /[0-9]/.test(t) || t.toLowerCase() !== t.toUpperCase();
        if (shell.filterText !== "" || isLetterOrDigit) {
            shell.filterText += t;
            event.accepted = true;
        }
    }
    HoverHandler { id: winHover }
    WheelHandler {
        acceptedModifiers: Qt.ControlModifier
        onWheel: event => shell.adjustIcon(event.angleDelta.y > 0 ? 4 : -4)
    }

    Rectangle { // the window background: the app background colour, with its own opacity
        anchors.fill: parent
        color: shell.bgColor
        z: -1
    }

    // the room the button strip (power and all-apps buttons) takes on its side (0 while the option is off, or when they sit in the footer), so the tiles never sit under it
    readonly property real padL: shell.powerSide === "left" ? shell.powerPad : 0
    readonly property real padR: shell.powerSide === "right" ? shell.powerPad : 0
    readonly property real padT: shell.powerSide === "top" ? shell.powerPad : 0
    readonly property real padB: shell.powerSide === "bottom" ? shell.powerPad : 0

    // the room around the tiles and the list: the launcher's margin, the strip of buttons, the usage row
    readonly property real mL: shell.outerMargin + padL
    readonly property real mR: shell.outerMargin + padR
    readonly property real mT: shell.outerMargin + padT + shell.usageRowH
    readonly property real mB: shell.outerMargin + footerH + padB
    // while the launcher grows to the screen the tiles keep their own size, centred (see Overlay `ownContentW`)
    readonly property real tilesW: shell.grow > 0 ? shell.ownContentW : width
    readonly property real tilesH: shell.grow > 0 ? shell.ownContentH : height
    Node {
        x: (content.width - content.tilesW) / 2 + content.mL
        y: (content.height - content.tilesH) / 2 + content.mT
        width: content.tilesW - content.mL - content.mR
        height: content.tilesH - content.mT - content.mB
        shell: content.shell
        path: []
        // Going to every app (`flip` 0 -> 1, while the launcher grows to the screen): the tiles fade out in the
        // first part and shrink a little, then the list comes in (below). The picker takes over the whole window.
        visible: content.shell.pickingPath === null && opacity > 0
        opacity: Math.max(0, 1 - content.shell.flip * 1.8)
        scale: 1 - 0.06 * content.shell.flip
    }
    // ---- the apps used most (or last), in a row above the tiles (⚙ > Search); clicks launch them
    Item {
        id: usageRow
        visible: shell.usageRowH > 0 && shell.pickingPath === null
        z: 30
        anchors { top: parent.top; left: parent.left; right: parent.right
                  topMargin: shell.outerMargin + content.padT; leftMargin: shell.outerMargin + content.padL; rightMargin: shell.outerMargin + content.padR }
        height: shell.usageRowH
        readonly property real stride: shell.cellWidth(shell.iconSize, shell.searchLabels) + 4
        // the caption at the left names the row, so a lone icon above the tiles does not look like one that strayed
        readonly property real captionW: caption.implicitWidth + 16
        readonly property int fit: Math.max(1, Math.floor((width - 2 * captionW + 4) / stride))
        Text {
            id: caption
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; verticalCenterOffset: -6 }
            text: shell.usageOrder === "recent" ? "Recently used" : "Most used"
            color: shell.fg
            opacity: 0.55
            font.pixelSize: 11
            font.letterSpacing: 0.4
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: shell.usageRowIds.slice(0, usageRow.fit)
                delegate: AppCell {
                    required property string modelData
                    shell: content.shell
                    inResults: true
                    appId: modelData
                    iconSize: content.shell.iconSize
                }
            }
        }
        Rectangle { // a hair line between the row and the tiles
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 4 }
            height: 1
            color: shell.fg
            opacity: 0.12
        }
    }
    // every matching app, when "Allow all apps in search" is on (only exists while typing)
    Loader {
        // laid out at the size it has on the whole screen, and scaled to the launcher while it is still growing
        readonly property real fullW: content.shell.grow > 0 && content.shell.grow < 1 ? content.shell.fullContentW : content.width
        readonly property real fullH: content.shell.grow > 0 && content.shell.grow < 1 ? content.shell.fullContentH : content.height
        x: (content.width - fullW) / 2 + content.mL
        y: (content.height - fullH) / 2 + content.mT
        width: fullW - content.mL - content.mR
        height: fullH - content.mT - content.mB
        transformOrigin: Item.Center
        active: content.shell.searchingAll && content.shell.pickingPath === null
        // it comes in over the second part of `flip`, from a little larger, as the launcher reaches the screen
        visible: opacity > 0
        opacity: Math.max(0, Math.min(1, (content.shell.flip - 0.35) / 0.55))
        scale: Math.min(1, content.width / fullW, content.height / fullH)
        onLoaded: item.shell = content.shell
        source: "SearchResults.qml"
    }

    //---------------------------------------------------------- type-to-filter display
    // A small pill at the top centre shows what is being typed, and how to leave it.
    Rectangle {
        visible: shell.filterText !== ""
        z: 45
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
        height: filterLabel.implicitHeight + 16
        width: filterLabel.implicitWidth + 32
        radius: Math.min(shell.corner, height / 2)
        color: shell.popupBg
        border.width: 1
        border.color: shell.accent
        Text {
            id: filterLabel
            anchors.centerIn: parent
            textFormat: Text.StyledText
            text: "<font color='" + shell.dim + "'>Filter:</font> " + shell.filterText.replace(/&/g, "&amp;").replace(/</g, "&lt;")
                  + "<font color='" + shell.accent + "'>▏</font>"
            color: shell.fg
            font.pixelSize: shell.filterFontSize
        }
    }
    Rectangle { // a short message (a profile switch, ...) over the tiles
        visible: shell.toast !== ""
        z: 60
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: shell.stripOn && shell.powerSide === "bottom" ? shell.powerButtonSize + 24 : 16 }
        height: toastLabel.implicitHeight + 16
        width: toastLabel.implicitWidth + 32
        radius: Math.min(shell.corner, height / 2)
        color: shell.popupBg
        border.width: 1
        border.color: shell.accent
        Text { id: toastLabel; anchors.centerIn: parent; text: shell.toast; color: shell.fg; font.pixelSize: 14 }
    }
    Text {
        visible: shell.filterText !== "" && shell.matchCount === 0
        z: 44
        anchors.centerIn: parent
        text: "No apps match"
        color: shell.dim
        font.pixelSize: 15
    }

    // the dragged icon lives here so it is not clipped by its tile
    Item { id: dragLayer; anchors.fill: parent; z: 50 }

    //---------------------------------------------------------- options menu
    // One faint ⚙ in the corner opens a popup with every global option. A click anywhere else
    // closes it.
    MouseArea {
        anchors.fill: parent
        z: 35
        // While resizing tiles the menu stays open however much you click and drag in the launcher;
        // only its "Done" button (or Esc) closes it then.
        visible: (shell.optionsOpen && !shell.resizeMode) || shell.tileMenuPath !== null
        onClicked: { shell.optionsOpen = false; shell.closeTileMenu(); }
    }
    // the footer strip, below the tile grid, for the power/all-apps button row only now: reaching
    // ⚙ is the bar button's right click (or its keybind, ⚙ menu > Keys), not a button in here, so
    // the tiles get the full height back when that row is off (see footerH above).
    Item {
        id: footer
        z: 40
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: content.footerH
    }

    // ---- power buttons: on the side opposite to the docked edge; below they sit in the footer strip,
    // elsewhere in the room the docked window grew by (see powerPad in shell.qml)
    Item {
        id: powerStrip
        z: 40
        visible: shell.stripOn
        readonly property bool vertical: shell.powerSide === "left" || shell.powerSide === "right"
        readonly property real thick: shell.powerSide === "bottom" ? content.footerH : (shell.powerButtonSize + 10)
        x: shell.powerSide === "left" ? 6 : (shell.powerSide === "right" ? content.width - thick - 6 : 0)
        y: shell.powerSide === "top" ? 6 : (shell.powerSide === "bottom" ? content.height - thick : 12)
        width: vertical ? thick : content.width
        height: vertical ? content.height - content.footerH - 12 : thick

        // one button = one complete image (background and drawing) from the chosen icons/themes/
        // folder (shell.iconTheme), 256x256
        component PowerButton: Item {
            id: pb
            property url icon // svg or png: replace the file to change the whole look
            property string flag: "" // a session command of the power buttons; empty = emit `activated`
            signal activated()
            readonly property real s: shell.powerButtonSize
            width: s; height: s
            opacity: pbMa.containsMouse ? 1 : 0.85
            // Some button styles (Line, Square line) draw only a stroke, no fill: this sits behind
            // them so they read against the app background instead of floating in mid-air. Off by
            // default ("none"), so styles with their own solid background do not gain a second one.
            Rectangle {
                anchors.fill: parent
                radius: shell.stripRadius(pb.s)
                color: shell.paint("powerBg", null)
            }
            Image {
                anchors.fill: parent
                source: pb.icon
                sourceSize: Qt.size(256, 256)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true // scaled down from 256 px without jagged edges
            }
            MouseArea { id: pbMa; anchors.fill: parent; hoverEnabled: true; onClicked: { if (pb.flag !== "") shell.powerAction(pb.flag); else pb.activated(); } }
        }
        Grid {
            anchors.centerIn: parent
            columns: powerStrip.vertical ? 1 : 9
            spacing: 10
            PowerButton { // every installed app, flipped in; again to flip back
                visible: shell.allAppsButton
                icon: shell.stripIcon("all-apps")
                onActivated: shell.allAppsOpen = !shell.allAppsOpen
            }
            PowerButton { visible: shell.powerOffButton; icon: shell.stripIcon("power-off"); flag: "--power-off" }  // shut down
            PowerButton { visible: shell.restartButton; icon: shell.stripIcon("restart"); flag: "--reboot" }       // restart
            PowerButton { visible: shell.logoutButton; icon: shell.stripIcon("logout"); flag: "--logout" }        // log out
            Repeater { // the profiles, when they are shown as buttons (⚙ > Profiles > Profile)
                model: shell.profileButtons
                delegate: ProfileButton {
                    required property string modelData
                    required property int index
                    shell: content.shell
                    name: modelData
                    label: content.shell.profileLabel(index)
                    s: content.shell.powerButtonSize
                }
            }
        }
    }

    // the app picker only exists while open, so startup does not pay for its icons
    Loader {
        anchors.fill: parent
        z: 100
        active: content.shell.pickingPath !== null
        onLoaded: item.shell = content.shell
        source: "Picker.qml"
    }
}
