import QtQuick
import "controls"
import "previews"

// The ready-made profiles (lib/presets.js) as cards. The first time the launcher runs it shows in place of the
// tiles, to choose how to start (the choice becomes the default profile); later, from ⚙ > Profiles > "Add a
// ready-made profile", the chosen one is added as a new profile next to yours, which stay as they are.
// Arrows / Tab / 1-5 choose, Enter starts or adds, Esc cancels (on the first start: starts with the recommended one).
// The state and the keys are Overlay.qml's (welcomeOpen, welcomeIndex, welcomeKey(), applyPreset()).
Rectangle {
    id: box
    property var shell

    readonly property real screenW: shell.targetScreen ? shell.targetScreen.width : 1920
    readonly property real screenH: shell.targetScreen ? shell.targetScreen.height : 1080
    readonly property real gap: 12
    readonly property real cardW: (width - 48 - gap * (shell.presetInfo.length - 1)) / Math.max(1, shell.presetInfo.length)
    readonly property var chosen: shell.presetInfo[shell.welcomeIndex] || { name: "", title: "" }
    readonly property var toSave: shell.welcomeFirstRun ? shell.presetsToSave(chosen.name) : []
    readonly property bool canStart: shell.welcomeFirstRun || !shell.profilesFull

    width: Math.min(1180, screenW - 80)
    height: body.implicitHeight + 48
    radius: 0
    color: Qt.rgba(shell.menuSurface.r, shell.menuSurface.g, shell.menuSurface.b, 1)
    border.width: 1
    border.color: shell.mBorder

    Keys.onPressed: event => { if (shell.welcomeKey(event)) event.accepted = true; }
    Keys.onTabPressed: event => { shell.welcomeKey(event); event.accepted = true; }
    Keys.onBacktabPressed: event => { shell.welcomeKey(event); event.accepted = true; }
    MouseArea { anchors.fill: parent } // a click on the box is not a click outside the launcher

    Column {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
        spacing: 16

        Column {
            width: parent.width
            spacing: 4
            Text {
                text: box.shell.welcomeFirstRun ? "Welcome to Gona Launcher" : "Add a ready-made profile"
                color: box.shell.mFg
                font.pixelSize: 22
                font.bold: true
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: box.shell.welcomeFirstRun
                      ? "Choose how to start. Each one is a ready-made profile: a set of tiles and settings you can change later or switch between with Ctrl+P."
                      : box.shell.profilesFull
                        ? "You have " + box.shell.maxProfiles + " profiles, the most there can be. Delete one in ⚙ > Profiles to add another."
                        : "It is added as a new profile and the launcher switches to it. Your profiles stay as they are (" + (box.shell.profileNames.length + 1) + " of " + box.shell.maxProfiles + " used)."
                color: box.shell.mDim
                font.pixelSize: 13
            }
        }

        Row {
            spacing: box.gap
            Repeater {
                model: box.shell.presetInfo
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool on: box.shell.welcomeIndex === index
                    // with "Also save … as profiles" on, every other preset that will be saved is marked too
                    readonly property bool alsoSaved: !on && box.shell.welcomeSaveOthers && box.toSave.indexOf(modelData.name) >= 0
                    width: box.cardW
                    height: cardBody.implicitHeight + 20
                    radius: 0
                    color: cardMa.containsMouse || on ? box.shell.mHover : "transparent"
                    border.width: on || alsoSaved ? 2 : 1
                    border.color: on || alsoSaved ? box.shell.accent : box.shell.mBorder
                    Column {
                        id: cardBody
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 8
                        PresetPreview {
                            width: parent.width
                            shell: box.shell
                            info: card.modelData
                            screenW: box.screenW
                            screenH: box.screenH
                        }
                        Row {
                            spacing: 8
                            Text { text: (card.index + 1) + "  " + card.modelData.title; color: box.shell.mFg; font.pixelSize: 15; font.bold: true }
                            Rectangle {
                                visible: card.modelData.recommended === true
                                anchors.verticalCenter: parent.verticalCenter
                                width: badge.implicitWidth + 12; height: 18; radius: 0
                                color: "transparent"
                                border.width: 1
                                border.color: box.shell.accent
                                Text { id: badge; anchors.centerIn: parent; text: "Recommended"; color: box.shell.accent; font.pixelSize: 10 }
                            }
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: card.modelData.text
                            color: box.shell.mDim
                            font.pixelSize: 12
                        }
                        Text {
                            text: card.modelData.name === "clean" ? "Starts empty"
                                  : card.modelData.installed + (card.modelData.installed === 1 ? " app" : " apps") + " found on this computer"
                            color: box.shell.mDim
                            font.pixelSize: 11
                            font.italic: true
                        }
                    }
                    Rectangle { // what happens to it: the one started with, or saved as a profile
                        visible: (card.on && box.shell.welcomeSaveOthers) || card.alsoSaved
                        anchors { top: parent.top; right: parent.right; margins: 14 }
                        width: markText.implicitWidth + 14; height: 20; radius: 0
                        color: box.shell.accent
                        Text {
                            id: markText
                            anchors.centerIn: parent
                            text: card.on ? "✓ In use" : "✓ Profile"
                            color: box.shell.menuLight ? "#ffffff" : "#1e1e2e"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: box.shell.welcomeIndex = card.index
                        onDoubleClicked: box.shell.applyPreset(card.modelData.name, box.shell.welcomeSaveOthers)
                    }
                }
            }
        }

        MenuToggle { // the first start only: the other ready-made profiles are added too, to try them with Ctrl+P
            visible: box.shell.welcomeFirstRun
            shell: box.shell
            fullWidth: body.width
            enabled: box.toSave.length > 0
            label: box.toSave.length > 0 ? "Also add " + box.toSave.join(", ") + " as profiles, to switch with Ctrl+P"
                                         : "Also add the others as profiles (no room: 5 profiles at most)"
            tip: "Each one becomes a profile of its own, the last one made comes last, and the profile buttons show in the launcher's strip when that profile has them on."
            checked: box.shell.welcomeSaveOthers && box.toSave.length > 0
            onToggled: box.shell.welcomeSaveOthers = !box.shell.welcomeSaveOthers
        }

        MenuToggle { // the first start only: the one thing the launcher writes outside its own folders, so it asks
            visible: box.shell.welcomeFirstRun && box.shell.superAvailable
            shell: box.shell
            fullWidth: body.width
            label: "Open with Super: press and release it alone"
            tip: "Adds a shortcut to Hyprland's ~/.config/hypr/bindings.lua, in a marked block of its own. Change it or remove it in ⚙ > Keys."
            checked: box.shell.welcomeSuper
            onToggled: box.shell.welcomeSuper = !box.shell.welcomeSuper
        }

        Row {
            spacing: 8
            Text {
                width: body.width - (cancel.visible ? cancel.width + 8 : 0) - start.width - 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: "← → choose   ·   Enter " + (box.shell.welcomeFirstRun ? "start" : "add") + "   ·   Esc " + (box.shell.welcomeFirstRun ? "start with " + (box.shell.presetInfo[0] || { title: "" }).title : "cancel")
                color: box.shell.mDim
                font.pixelSize: 12
            }
            MenuButton {
                id: cancel
                shell: box.shell
                width: 110
                visible: !box.shell.welcomeFirstRun
                label: "Cancel"
                onClicked: box.shell.closeWelcome()
            }
            MenuButton {
                id: start
                shell: box.shell
                width: 200
                primary: true
                active: box.canStart
                label: (box.shell.welcomeFirstRun ? "Start with " : "Add ") + box.chosen.title
                onClicked: box.shell.applyPreset(box.chosen.name, box.shell.welcomeSaveOthers)
            }
        }
    }
}
