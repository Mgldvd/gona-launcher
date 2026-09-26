import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// The stage of the promo video (tools/promo/): a full-screen dark backdrop with slowly drifting glows and a mock
// top bar, mapped before the launcher so every launcher window lands on top of it. It only exists in the
// throw-away instance that tools/promo/record.py runs; nothing here ships with the plugin.
PanelWindow {
    id: win
    property bool barOn: true         // the mock bar
    property bool pressed: false      // the bar button lit, as if clicked
    readonly property real buttonX: width - 44
    readonly property real buttonY: 15

    // the monitor the stage runs on (tools/promo/stage.py: the focused one, also where the launcher opens and what is
    // recorded), so a second monitor cannot take the stage away from the recording
    screen: Quickshell.screens.find(s => s.name === Quickshell.env("GONA_SCREEN")) || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "promo-backdrop"
    WlrLayershell.layer: WlrLayer.Overlay
    color: "#0a0b12"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#10111c" }
            GradientStop { position: 1.0; color: "#1a1030" }
        }
    }

    // three soft glows that drift on their own
    component Glow: Shape {
        id: g
        property color tint: "#c4a7ff"
        property real size: 640
        property real ax: 0
        property real ay: 0
        property real speed: 1
        x: ax; y: ay
        width: size; height: size
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillGradient: RadialGradient {
                centerX: g.size / 2; centerY: g.size / 2; centerRadius: g.size / 2
                focalX: centerX; focalY: centerY
                GradientStop { position: 0.0; color: Qt.rgba(g.tint.r, g.tint.g, g.tint.b, 0.34) }
                GradientStop { position: 1.0; color: Qt.rgba(g.tint.r, g.tint.g, g.tint.b, 0.0) }
            }
            strokeColor: "transparent"
            PathRectangle { x: 0; y: 0; width: g.size; height: g.size }
        }
        SequentialAnimation on ax {
            loops: Animation.Infinite
            NumberAnimation { to: g.ax + 90; duration: 9000 / g.speed; easing.type: Easing.InOutSine }
            NumberAnimation { to: g.ax - 40; duration: 9000 / g.speed; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on ay {
            loops: Animation.Infinite
            NumberAnimation { to: g.ay - 70; duration: 7000 / g.speed; easing.type: Easing.InOutSine }
            NumberAnimation { to: g.ay + 50; duration: 7000 / g.speed; easing.type: Easing.InOutSine }
        }
    }
    Glow { tint: "#ff6fae"; size: 760; ax: -220; ay: 380; speed: 1.0 }
    Glow { tint: "#7c5cff"; size: 820; ax: 700; ay: -260; speed: 0.8 }
    Glow { tint: "#35d6e8"; size: 560; ax: 420; ay: 470; speed: 1.3 }

    Rectangle { // the mock bar
        visible: win.barOn
        width: parent.width; height: 30
        color: "#14151f"
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#ffffff"; opacity: 0.06 }
        Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "1  2  3  4  5"; color: "#8b8fa8"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
        Text { anchors.centerIn: parent; text: "Tue 23 Sep  21:14"; color: "#b7bbd4"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
        Text { x: win.width - 250; anchors.verticalCenter: parent.verticalCenter; text: "󰕾  󰤨  󰁹"; color: "#8b8fa8"; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
        Rectangle { // the launcher's button
            x: win.buttonX - width / 2; y: (parent.height - height) / 2
            width: 26; height: 22; radius: 6
            color: win.pressed ? "#ff6fae" : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            Text { anchors.centerIn: parent; text: "▦"; font.pixelSize: 15; color: win.pressed ? "#14151f" : "#d6d9ee" }
        }
    }
}
