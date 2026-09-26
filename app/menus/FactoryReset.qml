import QtQuick
import "controls"

// ⚙ > Profiles > "Start over": Reset to factory settings. Asks once more before it does anything. A copy of the
// whole configuration folder is kept next to it (Overlay.factoryReset()).
Column {
    id: box
    property var shell
    property real fullWidth: 696
    width: fullWidth
    spacing: 8

    property bool confirming: false // the button was pressed once
    Connections { target: box.shell; function onOptionsOpenChanged() { box.confirming = false; } }

    Column {
        width: box.width
        spacing: 2
        Text { text: "Start over"; color: box.shell.mFg; font.pixelSize: 13 }
        Text {
            width: box.width; wrapMode: Text.WordWrap
            text: "Erases your settings, tiles, profiles and usage history and shows the welcome screen, as on the first start. A copy of everything is kept in ~/.config/gona-launcher.reset-<date>."
            color: box.shell.mDim; font.pixelSize: 11
        }
    }
    Row {
        width: box.width
        spacing: 8
        MenuButton {
            shell: box.shell
            width: box.confirming ? box.width - cancel.width - parent.spacing : box.width
            danger: true
            label: box.confirming ? "Yes, erase everything and start over" : "Reset to factory settings…"
            onClicked: {
                if (!box.confirming) { box.confirming = true; return; }
                box.confirming = false;
                box.shell.factoryReset();
            }
        }
        MenuButton {
            id: cancel
            shell: box.shell
            width: 90
            visible: box.confirming
            label: "Cancel"
            onClicked: box.confirming = false
        }
    }
}
