import QtQuick

// ? (or F1) in the launcher: every keyboard shortcut on one card, over the tiles. The ones that can change (⚙ > Keys) show
// the combination in use; a disabled one shows a dash. Any key or a click closes it (LauncherContent.qml, the MouseArea).
Rectangle {
    id: box
    property var shell

    readonly property real screenW: shell.targetScreen ? shell.targetScreen.width : 1920
    // the fixed ones, and the mouse
    readonly property var fixedKeys: [
        { keys: "Type", what: "Filter your apps" },
        { keys: "Arrows, Tab", what: "Move the selection" },
        { keys: "Enter, Space", what: "Launch the selected app" },
        { keys: "Esc", what: "Go back one step, then close" },
        { keys: "Alt + 1 … 9", what: "The nth app of the selected tile" },
        { keys: "Ctrl + wheel, Ctrl + / − / 0", what: "Icon size" },
        { keys: "Menu key, Shift + F10", what: "The menu of the selected app's tile" },
        { keys: "? or F1", what: "This list" }
    ]
    readonly property var mouse: [
        { keys: "Right-click a tile", what: "Its menu" },
        { keys: "Rest on a tile", what: "Shows its ＋ and ⋯ buttons" },
        { keys: "Drag an icon", what: "Onto another tile or icon" }
    ]
    readonly property var changeable: shell.keyActions.map(a => ({ keys: shell.comboFor(a.name) === "" ? "—" : shell.comboFor(a.name).replace(/\+/g, " + "), what: a.label }))

    width: Math.min(900, screenW - 80)
    height: body.implicitHeight + 40
    radius: 0
    color: Qt.rgba(shell.menuSurface.r, shell.menuSurface.g, shell.menuSurface.b, 1)
    border.width: 1
    border.color: shell.mBorder
    MouseArea { anchors.fill: parent; onClicked: box.shell.helpOpen = false }

    Column {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 12
        Text { text: "Keyboard shortcuts"; color: box.shell.mFg; font.pixelSize: 18; font.bold: true }
        Row {
            width: parent.width
            spacing: 24
            Column {
                width: (parent.width - 24) / 2
                spacing: 2
                Text { text: "You can change these in ⚙ > Keys"; color: box.shell.mDim; font.pixelSize: 11; bottomPadding: 4 }
                Repeater { model: box.changeable; delegate: HelpRow { required property var modelData; shell: box.shell; keyWidth: 140; keys: modelData.keys; what: modelData.what } }
            }
            Column {
                width: (parent.width - 24) / 2
                spacing: 2
                Text { text: "Always"; color: box.shell.mDim; font.pixelSize: 11; bottomPadding: 4 }
                Repeater { model: box.fixedKeys; delegate: HelpRow { required property var modelData; shell: box.shell; keys: modelData.keys; what: modelData.what } }
                Text { text: "Mouse"; color: box.shell.mDim; font.pixelSize: 11; topPadding: 10; bottomPadding: 4 }
                Repeater { model: box.mouse; delegate: HelpRow { required property var modelData; shell: box.shell; keys: modelData.keys; what: modelData.what } }
            }
        }
        Text { text: "Any key or a click closes this"; color: box.shell.mDim; font.pixelSize: 11 }
    }
}
