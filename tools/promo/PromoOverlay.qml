import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// The words of the promo video (tools/promo/): a title card, a caption pill at the bottom, a small tag at the top and
// an outro card, in a transparent full-screen window that the director re-maps after the launcher opens so it
// stays on top (layer-shell windows stack in the order they were mapped). Nothing here ships with the plugin.
PanelWindow {
    id: win
    property bool titleOn: false
    property string title: ""
    property string subtitle: ""
    property bool captionOn: false
    property string caption: ""
    property bool tagOn: false
    property string tag: ""
    property bool outroOn: false
    property bool cursorOn: false     // a pointer, since the recording has none: it is moved by the director
    property real cx: 700
    property real cy: 400
    property int cursorMs: 500
    function click() { ripple.restart(); }
    readonly property string mono: "JetBrainsMono Nerd Font"

    // the monitor the stage runs on (tools/promo/stage.py: the focused one, also where the launcher opens and what is
    // recorded), so a second monitor cannot take the stage away from the recording
    screen: Quickshell.screens.find(s => s.name === Quickshell.env("GONA_SCREEN")) || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "promo-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"

    // ---- title and outro: the same card, the second with its own words
    component Card: Item {
        id: c
        property bool on: false
        property string head: ""
        property string sub: ""
        property string foot: ""
        anchors.fill: parent
        opacity: on ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
        Rectangle { anchors.fill: parent; color: "#0a0b12"; opacity: 0.55 } // dims the stage behind the words
        Column {
            anchors.centerIn: parent
            spacing: 18
            scale: c.on ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
            Image { // the launcher's own icon (tools/promo/gona-launcher.png, copied next to this file), as it is
                anchors.horizontalCenter: parent.horizontalCenter
                source: Qt.resolvedUrl("gona-launcher.png")
                width: 150; height: 150
                smooth: true; mipmap: true
                scale: c.on ? 1 : 0.6
                opacity: c.on ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 450 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: c.head
                color: "#ffffff"
                font.family: win.mono; font.pixelSize: 64; font.bold: true
                font.letterSpacing: c.on ? 1 : 10
                Behavior on font.letterSpacing { NumberAnimation { duration: 1100; easing.type: Easing.OutCubic } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: c.sub !== ""
                text: c.sub
                color: "#ff8ec1"
                font.family: win.mono; font.pixelSize: 24
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: c.foot !== ""
                text: c.foot
                color: "#b7bbd4"
                font.family: win.mono; font.pixelSize: 18
            }
        }
    }
    Card { on: win.titleOn; head: win.title; sub: win.subtitle }
    Card { on: win.outroOn; head: "Gona Launcher"; sub: "Made for Omarchy"; foot: "github.com/Mgldvd/gona-launcher" }

    // ---- caption: a pill at the bottom
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.captionOn ? parent.height - height - 26 : parent.height - height - 6
        width: capText.implicitWidth + 56; height: 50; radius: 25
        color: "#e6111320"
        border.width: 1; border.color: "#66ff8ec1"
        opacity: win.captionOn ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 260 } }
        Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Text {
            id: capText
            anchors.centerIn: parent
            text: win.caption
            color: "#ffffff"
            font.family: win.mono; font.pixelSize: 22; font.bold: true
        }
    }

    // ---- tag: the name of the effect being shown, small, at the top
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.tagOn ? 46 : 32
        width: tagText.implicitWidth + 36; height: 34; radius: 17
        color: "#e6111320"
        border.width: 1; border.color: "#66ff8ec1"
        opacity: win.tagOn ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Text {
            id: tagText
            anchors.centerIn: parent
            text: win.tag
            color: "#ff8ec1"
            font.family: win.mono; font.pixelSize: 16; font.bold: true
        }
    }

    // ---- a pointer, and a ripple where it clicks
    Item {
        id: pointer
        x: win.cx; y: win.cy
        visible: win.cursorOn
        Behavior on x { NumberAnimation { duration: win.cursorMs; easing.type: Easing.InOutCubic } }
        Behavior on y { NumberAnimation { duration: win.cursorMs; easing.type: Easing.InOutCubic } }
        Rectangle {
            id: ring
            x: -22; y: -22; width: 44; height: 44; radius: 22
            color: "transparent"; border.width: 3; border.color: "#ff8ec1"
            opacity: 0
        }
        ParallelAnimation {
            id: ripple
            NumberAnimation { target: ring; property: "scale"; from: 0.3; to: 1.5; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: ring; property: "opacity"; from: 0.95; to: 0; duration: 420 }
        }
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#ffffff"; strokeColor: "#14151f"; strokeWidth: 1.5
                PathSvg { path: "M0 0 L0 17 L4.5 13 L7.5 20 L10 19 L7 12 L13 12 Z" }
            }
        }
    }
}
