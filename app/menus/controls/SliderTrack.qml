import QtQuick

// The track of a SliderRow: the thin rail, its filled portion up to `value`, the handle, and the
// drag/tap area that moves it, at whatever width its own layout gives it. `moved(x, width)` reports
// where the pointer is; `pressed` says whether the knob is being dragged.
Item {
    id: track
    property var shell
    property real from: 0
    property real to: 100
    property real value: 0
    readonly property alias pressed: trackMa.pressed
    signal moved(real x, real trackWidth)

    height: 22
    readonly property real ratio: to > from ? (value - from) / (to - from) : 0
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 3; radius: 0
        color: track.shell.mBorder
        Rectangle { width: parent.width * track.ratio; height: parent.height; radius: 0; color: track.shell.accent }
    }
    Rectangle {
        x: track.width * track.ratio - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14; radius: 0
        color: track.shell.accent
    }
    MouseArea {
        id: trackMa
        anchors.fill: parent
        onPressed: mouse => track.moved(mouse.x, track.width)
        onPositionChanged: mouse => track.moved(mouse.x, track.width)
    }
}
