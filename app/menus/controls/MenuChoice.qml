import QtQuick

// A label on top and a wrapping row of outline buttons below (one is selected). Each button sizes to
// its own text (min 56 px) instead of splitting the width evenly: a long label ("Meet in centre")
// would overflow its slot and overlap the next one, and wrapping keeps every button legible and lets
// the row grow to a second line. Tab reaches it, the arrow keys move the selection.
Item {
    id: row
    property var shell
    property real fullWidth: 300
    property string label: ""
    property var options: [] // [{ text, value }]
    property string current: ""
    signal chosen(string value)

    width: fullWidth
    height: content.height
    opacity: enabled ? 1 : 0.38 // dimmed rather than hidden when it does not apply right now,
    Behavior on opacity { NumberAnimation { duration: 120 } } // so rows around it never jump
    activeFocusOnTab: true
    function step(d) {
        const i = options.findIndex(o => o.value === current);
        const n = Math.max(0, Math.min(options.length - 1, (i < 0 ? 0 : i) + d));
        if (options[n]) chosen(options[n].value);
    }
    Keys.onLeftPressed: event => { row.step(-1); event.accepted = true; }
    Keys.onRightPressed: event => { row.step(1); event.accepted = true; }

    FocusRing { shell: row.shell }

    Column {
        id: content
        width: row.width
        spacing: 8

        Text {
            text: row.label
            color: row.shell.mFg
            font.pixelSize: 13
        }
        Flow {
            width: row.width
            spacing: 6
            Repeater {
                model: row.options
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: row.current === modelData.value
                    width: Math.max(56, label.implicitWidth + 20)
                    height: 26
                    radius: 0
                    color: "transparent"
                    border.width: 1
                    border.color: on ? row.shell.accent : (choiceMa.containsMouse ? row.shell.mDim : row.shell.mBorder)
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: parent.modelData.text
                        color: parent.on ? row.shell.accent : (choiceMa.containsMouse ? row.shell.mFg : row.shell.mDim)
                        font.pixelSize: 12
                        font.bold: parent.on
                    }
                    MouseArea {
                        id: choiceMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: row.chosen(parent.modelData.value)
                    }
                }
            }
        }
    }
}
