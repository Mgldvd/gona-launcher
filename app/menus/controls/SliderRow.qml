import QtQuick

// A labelled slider. Two layouts, chosen by whether `icon` (a menuIcons.js name) is set:
//  - plain: "label" on the left, "↺  −  ●───  +  value" on the right, one compact row. Most rows.
//  - with an icon: the icon sits by itself in a small tinted badge above the label, and the full
//    width below is given to "↺  −  ●─────────  +  value" -- a field with its own identity, for a
//    handful of settings worth calling out (⚙ > Window > Panel width/height) rather than one more
//    line in a list.
// `picked` gives the new value (already clamped to from..to and rounded to `step`); the owner
// stores it and passes it back in `value`. The optional ↺ (shown while `resettable` or `showReset`) emits `reset`.
Item {
    id: row
    property var shell
    property real fullWidth: 300
    property string label: ""
    property string icon: "" // menuIcons.js name; switches on the badge layout when set
    property string unit: ""
    property int from: 0
    property int to: 100
    property int step: 1
    property int value: 0
    property bool resettable: false // it differs from its default: ↺ is active
    property bool showReset: false  // keep the ↺ slot even while `resettable` is false (dimmed), so the row does not shift
    property string tip: "" // explained in a tooltip while the pointer rests on the row
    signal picked(int v)
    signal reset()
    readonly property bool hasIcon: icon !== ""
    readonly property bool dragging: (hasIcon ? fillTrack : compactTrack).pressed // the knob is being dragged

    width: fullWidth
    height: hasIcon ? 62 : 34
    opacity: enabled ? 1 : 0.38 // dimmed rather than hidden when it does not apply right now, so
    Behavior on opacity { NumberAnimation { duration: 120 } } // rows around it never jump in size
    z: tipItem.showing ? 100 : 0 // the tooltip paints over the rows below
    activeFocusOnTab: true // Tab reaches it; the arrow keys change it, Home / End jump to the ends
    Keys.onLeftPressed: event => { row.pick(row.value - row.step); event.accepted = true; }
    Keys.onRightPressed: event => { row.pick(row.value + row.step); event.accepted = true; }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) { row.pick(row.from); event.accepted = true; }
        else if (event.key === Qt.Key_End) { row.pick(row.to); event.accepted = true; }
    }
    MenuTip { id: tipItem; shell: row.shell; text: row.tip }
    FocusRing { shell: row.shell }
    function pick(v) { picked(Math.max(from, Math.min(to, Math.round(v / step) * step))); }
    function pickAt(x, trackWidth) { pick(from + Math.max(0, Math.min(1, x / trackWidth)) * (to - from)); }

    // ---- plain layout: label left, everything else right, one row
    Text {
        visible: !row.hasIcon
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        color: row.shell.mFg
        font.pixelSize: 13
    }
    Row {
        visible: !row.hasIcon
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.resettable || row.showReset
            opacity: row.resettable ? 1 : 0.35
            text: "↺"
            color: row.shell.mDim
            font.pixelSize: 15
            MouseArea { anchors.fill: parent; anchors.margins: -5; enabled: row.resettable; onClicked: row.reset() }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "−"
            color: row.shell.mFg
            font.pixelSize: 18
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: row.pick(row.value - row.step) }
        }
        SliderTrack {
            id: compactTrack
            shell: row.shell; from: row.from; to: row.to; value: row.value
            anchors.verticalCenter: parent.verticalCenter; width: 84
            onMoved: (x, w) => row.pickAt(x, w)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            color: row.shell.mFg
            font.pixelSize: 18
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: row.pick(row.value + row.step) }
        }
        SliderValue {
            anchors.verticalCenter: parent.verticalCenter
            shell: row.shell; value: row.value; text: row.value + row.unit
            onTyped: n => row.pick(n)
        }
    }

    // ---- badge layout: icon badge + label on top, the slider spans the full width below
    Row {
        id: header
        visible: row.hasIcon
        spacing: 10
        Rectangle {
            width: 28; height: 28; radius: 0
            color: Qt.rgba(row.shell.accent.r, row.shell.accent.g, row.shell.accent.b, 0.14)
            MenuIcon { anchors.centerIn: parent; name: row.icon; color: row.shell.accent; size: 15 }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: row.shell.mFg
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }
    Item {
        visible: row.hasIcon
        y: header.height + 10
        width: parent.width
        height: 22

        Text {
            id: resetGlyph
            visible: row.resettable || row.showReset
            opacity: row.resettable ? 1 : 0.35
            anchors.verticalCenter: parent.verticalCenter
            text: "↺"
            color: row.shell.mDim
            font.pixelSize: 15
            MouseArea { anchors.fill: parent; anchors.margins: -5; enabled: row.resettable; onClicked: row.reset() }
        }
        Text {
            id: minusGlyph
            anchors { verticalCenter: parent.verticalCenter; left: resetGlyph.visible ? resetGlyph.right : parent.left
                      leftMargin: resetGlyph.visible ? 10 : 0 }
            text: "−"
            color: row.shell.mFg
            font.pixelSize: 18
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: row.pick(row.value - row.step) }
        }
        SliderValue {
            id: valueLabel
            anchors { verticalCenter: parent.verticalCenter; right: parent.right }
            shell: row.shell; value: row.value; text: row.value + row.unit
            onTyped: n => row.pick(n)
        }
        Text {
            id: plusGlyph
            anchors { verticalCenter: parent.verticalCenter; right: valueLabel.left; rightMargin: 8 }
            text: "+"
            color: row.shell.mFg
            font.pixelSize: 18
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: row.pick(row.value + row.step) }
        }
        SliderTrack {
            id: fillTrack
            shell: row.shell; from: row.from; to: row.to; value: row.value
            onMoved: (x, w) => row.pickAt(x, w)
            anchors { verticalCenter: parent.verticalCenter; left: minusGlyph.right; right: plusGlyph.left
                      leftMargin: 10; rightMargin: 10 }
        }
    }
}
