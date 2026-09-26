import QtQuick
import Quickshell

// App picker for one tile. Created only while open (see the Loader in shell.qml), so its
// hundreds of icons cost nothing at startup. Each click toggles an app in/out of the tile
// and is saved at once.
Rectangle {
    id: picker
    property var shell
    // never see-through, even when the app background colour is transparent: the picker covers the
    // whole window, not just the gaps between tiles, so it needs its own readable background
    color: shell.solidBg

    // apps already in the tile being edited
    readonly property var present: shell.pickingPath === null ? []
                                    : shell.nodeAt(shell.layout, shell.pickingPath).ids

    Component.onCompleted: search.forceActiveFocus()

    Text {
        id: backBtn
        x: 16; y: 14
        text: "←  Done"
        color: picker.shell.dim
        font.pixelSize: 14
        MouseArea { anchors.fill: parent; onClicked: picker.shell.pickingPath = null }
    }
    Rectangle {
        id: searchBox
        anchors { top: backBtn.bottom; left: parent.left; right: parent.right; margins: 16 }
        height: 38
        radius: picker.shell.corner
        color: picker.shell.popupBg
        TextInput {
            id: search
            anchors.fill: parent
            anchors.margins: 10
            color: picker.shell.fg
            font.pixelSize: 15
            verticalAlignment: TextInput.AlignVCenter
            Text { visible: !search.text; text: "Search apps…"; color: picker.shell.dim; font: search.font }
        }
    }

    GridView {
        id: pickGrid
        anchors { top: searchBox.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 16 }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 110)))
        cellHeight: 110
        model: {
            const q = search.text.toLowerCase();
            return DesktopEntries.applications.values
                .filter(e => !e.noDisplay && e.name.toLowerCase().includes(q))
                .sort((a, b) => a.name.localeCompare(b.name));
        }
        delegate: Item {
            id: pickCell
            required property var modelData
            readonly property bool selected: picker.present.includes(modelData.id)
            width: pickGrid.cellWidth
            height: pickGrid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: picker.shell.corner
                color: pickCell.selected ? picker.shell.accentSoft : (pickMa.containsMouse ? picker.shell.hover : "transparent")
                border.width: pickCell.selected ? 2 : 0
                border.color: picker.shell.accent

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44; height: 44
                        asynchronous: true
                        sourceSize: Qt.size(88, 88)
                        source: Quickshell.iconPath(pickCell.modelData.icon, "application-x-executable")
                    }
                    Text {
                        width: pickCell.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: pickCell.modelData.name
                        color: picker.shell.fg
                        font.pixelSize: 12
                    }
                }
                Text {
                    anchors { top: parent.top; right: parent.right; margins: 6 }
                    visible: pickCell.selected
                    text: "✓"
                    color: picker.shell.accent
                    font.pixelSize: 14
                    font.bold: true
                }
                MouseArea {
                    id: pickMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (pickCell.selected) picker.shell.removeApp(pickCell.modelData.id);
                        else picker.shell.addApps(picker.shell.pickingPath, [pickCell.modelData.id]);
                    }
                }
            }
        }
    }
}
