import QtQuick
import "../shared" as Shared
import "PanelWindowLogic.js" as WindowLogic

QtObject {
    id: root
    required property string screenName
    readonly property var candidate: WindowLogic.surfaceWindow(Hypr.clients, Hypr.monitors,
        screenName, Shared.DesktopStyle.preferences.outer, Shared.DesktopStyle.preferences.gap)
    // Repeated title/geometry notifications must not postpone the transition forever.
    readonly property string candidateKey: candidate ? candidate.address + ":" + WindowLogic.surfaceRole(candidate.class) : ""
    property bool expanded: false
    property string surfaceRole: "windowBackground"
    property color appBackground: Colors[surfaceRole]
    Behavior on appBackground { ColorAnimation { duration: root.duration } }
    readonly property int duration: Shared.DesktopStyle.slow
    property real progress: expanded ? 1 : 0
    Behavior on progress { NumberAnimation { duration: root.duration; easing.type: Easing.InOutCubic } }

    // Share one transition for the surface, island joins and available panel width.
    function sideGapFor(screenWidth) {
        return PanelStyle.sideGapFor(screenWidth) * (1 - progress)
    }

    // Coalesce the independently refreshed client/monitor snapshots on workspace changes.
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
