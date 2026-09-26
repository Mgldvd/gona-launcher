import QtQuick
import "controls"

// ⚙ > Profiles > "Configuration file": where the launcher keeps everything it remembers (settings and
// tiles, one config.toml), and Export / Import of that file, to back it up, move it to another
// machine or share a look. The path field takes any file name (~ is the home folder). Importing
// replaces the settings and tiles with the file's and keeps the previous ones in config.toml.bak;
// a file that is not valid TOML is refused with the line that is wrong.
Column {
    id: box
    property var shell
    property real fullWidth: 696
    width: fullWidth
    spacing: 8

    Column {
        width: box.width
        spacing: 2
        Text { text: "Configuration file"; color: box.shell.mFg; font.pixelSize: 13 }
        Text { width: box.width; wrapMode: Text.WordWrap; text: "Settings and tiles of the profile in use are kept in " + box.shell.configPath.replace(box.shell.configDir, "~/.config/gona-launcher"); color: box.shell.mDim; font.pixelSize: 11 }
    }
    Rectangle { // the file to export to, or to import from
        width: box.width; height: 30; radius: 0
        color: box.shell.mField
        border.width: pathInput.activeFocus ? 1 : 0
        border.color: box.shell.accent
        TextInput {
            id: pathInput
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            verticalAlignment: TextInput.AlignVCenter
            color: box.shell.mFg
            font.pixelSize: 13
            selectByMouse: true
            clip: true
            text: box.shell.transferPath
            onTextEdited: box.shell.transferPath = text
            onAccepted: { focus = false; box.shell.menuFocusRequested(); }
            Keys.onEscapePressed: { focus = false; box.shell.menuFocusRequested(); }
        }
        TapHandler { onTapped: pathInput.forceActiveFocus() }
    }
    Row {
        spacing: 8
        MenuButton { shell: box.shell; width: (box.width - 8) / 2; label: "Export"; onClicked: box.shell.exportConfig(box.shell.transferPath) }
        MenuButton { shell: box.shell; width: (box.width - 8) / 2; label: "Import"; onClicked: box.shell.importConfig(box.shell.transferPath) }
    }
    Text { // what happened; the row keeps its height while empty, so nothing jumps
        width: box.width
        height: Math.max(16, implicitHeight)
        wrapMode: Text.WordWrap
        text: box.shell.transferMessage
        color: box.shell.transferFailed ? box.shell.mDanger : box.shell.mDim
        font.pixelSize: 12
    }
}
