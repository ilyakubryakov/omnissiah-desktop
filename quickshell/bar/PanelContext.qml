import QtQuick
import "../shared" as Shared
import "PanelWindowLogic.js" as WindowLogic

QtObject {
    id: root
    required property string screenName
    readonly property var candidate: WindowLogic.surfaceWindow(Hypr.clients, Hypr.monitors,
        screenName, Shared.DesktopStyle.preferences.outer, Shared.DesktopStyle.preferences.gap)

    readonly property string candidateKey: candidate ? candidate.address + ":" + WindowLogic.surfaceRole(candidate.class) : ""
    property bool expanded: false
    property string surfaceRole: "windowBackground"
    property color appBackground: Colors[surfaceRole]
    Behavior on appBackground { ColorAnimation { duration: root.duration } }
    readonly property int duration: Shared.DesktopStyle.slow
    property real progress: expanded ? 1 : 0
    Behavior on progress { NumberAnimation { duration: root.duration; easing.type: Easing.InOutCubic } }

    function sideGapFor(screenWidth) {
        return PanelStyle.sideGapFor(screenWidth) * (1 - progress)
    }

    property Timer settle: Timer {
        interval: 90
        onTriggered: {
            root.expanded = ShellLayout.adaptivePanels && !!root.candidate
            if (root.candidate) root.surfaceRole = WindowLogic.surfaceRole(root.candidate.class)
        }
    }
    onCandidateKeyChanged: settle.restart()
    property bool enabled: ShellLayout.adaptivePanels
    onEnabledChanged: settle.restart()
    Component.onCompleted: settle.restart()
}
