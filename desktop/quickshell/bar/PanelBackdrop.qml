import QtQuick

Item {
    id: root
    required property PanelContext context
    required property var groups
    property real sideInset: 0
    readonly property real surfaceWidth: Math.max(0, width - 2 * sideInset)
    readonly property bool atScreenEdge: sideInset <= 0
    property real pixelScale: 1
    layer.enabled: true
    readonly property var shownGroups: groups.filter(g => g.visible && g.width > 0)
    readonly property bool islands: PanelStyle.style === "islands"
    readonly property real join: islands ? context.progress : 1
    readonly property real radius: PanelStyle.cornerRadius
    readonly property real outerRadius: Math.min(radius, sideInset)
    readonly property real alpha: ShellLayout.panelOpacity + (1 - ShellLayout.panelOpacity) * context.progress
    property color desktopBase: ShellLayout.panelSurface
    Behavior on desktopBase { ColorAnimation { duration: root.context.duration } }
    function boundary(index) {
        if (index === 0) return 0
        if (index === shownGroups.length) return surfaceWidth
        const previous = shownGroups[index - 1], next = shownGroups[index]
        return Math.round((previous.x + previous.width + next.x) / 2 * pixelScale) / pixelScale
    }

    Rectangle {
        x: root.sideInset
        width: root.surfaceWidth
        height: root.height
        visible: !root.islands
        readonly property color surface: ShellLayout.blend(root.desktopBase, root.context.appBackground, root.context.progress)
        color: Qt.rgba(surface.r, surface.g, surface.b, root.alpha)
        radius: root.outerRadius
    }

    Repeater {
        model: root.shownGroups
        Rectangle {
            id: segment
            required property var modelData
            required property int index
            readonly property real start: modelData.x * (1 - root.join) + root.boundary(index) * root.join
            readonly property real end: (modelData.x + modelData.width) * (1 - root.join) + root.boundary(index + 1) * root.join
            readonly property color tinted: ShellLayout.blend(root.desktopBase, modelData.tone,
                modelData.strength + modelData.hoverTint)
            readonly property color surface: ShellLayout.blend(tinted, root.context.appBackground, root.context.progress)
            x: root.sideInset + (root.islands ? start : modelData.x)
            width: root.islands ? Math.max(0, end - start) : modelData.width
            height: root.height
            color: root.islands ? Qt.rgba(surface.r, surface.g, surface.b, root.alpha)
                : Qt.rgba(modelData.tone.r, modelData.tone.g, modelData.tone.b,
                    (modelData.strength + modelData.hoverTint) * (1 - root.context.progress))
            topLeftRadius: index === 0 ? root.outerRadius : root.radius * (1 - root.join)
            bottomLeftRadius: topLeftRadius
            topRightRadius: index === root.shownGroups.length - 1 ? root.outerRadius : root.radius * (1 - root.join)
            bottomRightRadius: topRightRadius
            antialiasing: root.join < 1 || !root.atScreenEdge
        }
    }
}
