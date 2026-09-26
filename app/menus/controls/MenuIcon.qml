import QtQuick
import QtQuick.Shapes
import "../../lib/menuIcons.js" as Icons

// One line icon of menuIcons.js (by `name`), stroked in `color` at `size` px.
Item {
    id: icon
    property string name: ""
    property color color: "white"
    property real size: 18
    width: size
    height: size

    Shape {
        width: 24
        height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer // smooth edges at small sizes
        ShapePath {
            strokeColor: icon.color
            strokeWidth: 1.8
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.paths[icon.name] || "" }
        }
    }
}
