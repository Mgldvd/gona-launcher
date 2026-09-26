import QtQuick
import "controls"

// ⚙ > Profiles > "Your profiles": saved configurations with a name (settings and tiles, one file each in
// ~/.config/gona-launcher/profiles/). The chips switch between them; a name in the field and "Save a copy as new
// profile" copy what is on screen into a new one and use it from then on; "Delete" removes the one in use
// (asks twice; the default profile cannot be deleted). A keybinding can open the launcher on one:
// omarchy-shell shell summon gona.launcher '{"profile":"work"}'.
Column {
    id: box
    property var shell
    property real fullWidth: 696
    width: fullWidth
    spacing: 8

    readonly property string current: shell.activeProfile === "" ? "default" : shell.activeProfile
    property bool confirming: false // "Delete" was pressed once
    onCurrentChanged: confirming = false

    Column {
        width: box.width
        spacing: 2
        Text { text: "Your profiles"; color: box.shell.mFg; font.pixelSize: 13 }
        Text { width: box.width; wrapMode: Text.WordWrap; text: "Each is a saved set of settings and tiles (up to 5). Switch here, with Ctrl+P, or from a keybinding with {\"profile\":\"name\"}"; color: box.shell.mDim; font.pixelSize: 11 }
    }
    Flow { // the profiles: the default one, then the saved ones
        width: box.width
        spacing: 6
        Repeater {
            model: ["default"].concat(box.shell.profileNames)
            delegate: Rectangle {
                id: chip
                required property string modelData
                readonly property bool on: box.current === modelData
                width: Math.max(56, chipText.implicitWidth + 24)
                height: 26
                radius: 0
                color: "transparent"
                border.width: 1
                border.color: on ? box.shell.accent : (chipMa.containsMouse ? box.shell.mDim : box.shell.mBorder)
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.modelData
                    color: chip.on ? box.shell.accent : (chipMa.containsMouse ? box.shell.mFg : box.shell.mDim)
                    font.pixelSize: 12
                    font.bold: chip.on
                }
                MouseArea {
                    id: chipMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: box.shell.switchProfile(chip.modelData === "default" ? "" : chip.modelData)
                }
            }
        }
    }
    Row {
        spacing: 8
        Rectangle { // the name of the profile to save
            width: (box.width - 8) / 2; height: 32; radius: 0
            color: box.shell.mField
            border.width: nameInput.activeFocus ? 1 : 0
            border.color: box.shell.accent
            TextInput {
                id: nameInput
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                verticalAlignment: TextInput.AlignVCenter
                color: box.shell.mFg
                font.pixelSize: 13
                selectByMouse: true
                clip: true
                maximumLength: 32
                onAccepted: { saveButton.clicked(); focus = false; box.shell.menuFocusRequested(); }
                Keys.onEscapePressed: { focus = false; box.shell.menuFocusRequested(); }
            }
            Text {
                anchors { fill: parent; leftMargin: 10 }
                verticalAlignment: Text.AlignVCenter
                visible: nameInput.text === "" && !nameInput.activeFocus
                text: "name of the new profile"
                color: box.shell.mDim
                font.pixelSize: 13
            }
            TapHandler { onTapped: nameInput.forceActiveFocus() }
        }
        MenuButton {
            id: saveButton
            shell: box.shell
            width: (box.width - 8) / 2
            active: !box.shell.profilesFull
            label: box.shell.profilesFull ? "Profiles are full (5)" : "Save a copy as new profile"
            onClicked: { if (box.shell.createProfile(nameInput.text.trim())) nameInput.text = ""; }
        }
    }
    MenuButton { // the profile in use gets the name typed above
        shell: box.shell
        width: box.width
        active: box.current !== "default"
        label: box.current === "default" ? "Rename profile" : "Rename \"" + box.current + "\" to the name above"
        onClicked: { if (box.shell.renameProfile(box.current, nameInput.text.trim())) nameInput.text = ""; }
    }
    MenuButton {
        shell: box.shell
        width: box.width
        danger: true
        active: box.current !== "default"
        label: box.confirming ? "Yes, delete \"" + box.current + "\"" : (box.current === "default" ? "Delete profile" : "Delete \"" + box.current + "\"")
        onClicked: {
            if (!box.confirming) { box.confirming = true; return; }
            box.confirming = false;
            box.shell.deleteProfile(box.current);
        }
    }
    Text { // what happened; the row keeps its height while empty
        width: box.width
        height: Math.max(16, implicitHeight)
        wrapMode: Text.WordWrap
        text: box.shell.profileMessage
        color: box.shell.profileFailed ? box.shell.mDanger : box.shell.mDim
        font.pixelSize: 12
    }
}
