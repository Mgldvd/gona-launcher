import QtQuick
import "../lib/fx.js" as Fx

// Draws the opening / closing effect of the launcher (fluid, bounce, genie, dissolve, glitch; see fx.js and
// shaders/fx.frag) over `target`, the item that is the launcher. While `t` is below 1 the target is hidden
// and a frozen picture of it, taken by `snap()` when it opens or closes, is drawn through the shader instead;
// at 1 the live target shows and this draws nothing. Fill the window (or whatever the target sits in) with it:
// `srcRect` and `bodyRect` say where the target is in this item, so an effect can travel or overshoot past
// the target's own bounds. Used by the launcher window (Overlay.qml) and by the small preview in ⚙ > Effects.
Item {
    id: layer
    property Item target
    property string effect: ""        // one of Fx.NAMES, or "" for none
    property real t: 1                // the slide, 0 hidden .. 1 shown
    property bool opening: true       // which way t is going
    property rect srcRect: Qt.rect(0, 0, 0, 0)   // where `target` is, in this item's coordinates
    property rect bodyRect: srcRect   // the launcher inside it (a panel's area has an empty gap on its edge)
    property string edge: ""          // "" (centred), top, bottom, left, right, full
    property var anchor: null         // the bar button that opened it, { x, y } in this item's coordinates
    property string from: "top"       // the side slide and meet come from: top, bottom, left, right
    property real unit: height / 1080 // px scale of the effect (1 at 1080 p)

    readonly property bool active: effect !== "" && t < 1
    readonly property real p: Fx.ease(effect, opening, t)
    readonly property var slideDir: Fx.slideDir(effect, edge, from)
    readonly property var geo: Fx.geometry({ x: bodyRect.x, y: bodyRect.y, w: bodyRect.width, h: bodyRect.height }, edge, anchor)

    // a fresh picture of the target: call it when the launcher opens or closes (the picture is not live: a live
    // one would render the whole tile grid again on every frame)
    function snap() { shot.scheduleUpdate(); }

    ShaderEffectSource {
        id: shot
        sourceItem: layer.effect !== "" ? layer.target : null
        live: false
        visible: false // only a texture: the ShaderEffect below is what is drawn
        hideSource: layer.active
    }

    ShaderEffect {
        anchors.fill: parent
        visible: layer.active
        fragmentShader: Qt.resolvedUrl("../shaders/fx.frag.qsb")
        property variant source: shot
        property real mode: Fx.modeOf(layer.effect)
        property real p: layer.p
        property real unit: layer.unit
        property vector2d res: Qt.vector2d(width, height)
        property vector4d rect: Qt.vector4d(layer.srcRect.x, layer.srcRect.y, layer.srcRect.width, layer.srcRect.height)
        property vector4d body: Qt.vector4d(layer.bodyRect.x, layer.bodyRect.y, layer.bodyRect.width, layer.bodyRect.height)
        property vector2d origin: Qt.vector2d(layer.geo.origin.x, layer.geo.origin.y)
        property vector2d gorigin: Qt.vector2d(layer.geo.genieOrigin.x, layer.geo.genieOrigin.y)
        property vector2d dir: Qt.vector2d(layer.geo.dir.x, layer.geo.dir.y)
        property vector2d sdir: Qt.vector2d(layer.slideDir.x, layer.slideDir.y)
    }
}
