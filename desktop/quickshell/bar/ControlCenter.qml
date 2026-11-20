pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

// The settings pages hosted by the Control Station window, one file per page.
// Quick toggles live in the Control Center card on the panel (ControlCenterCard).
ColumnLayout {
    id: root
    property var cal: null
    property bool studioExpanded: false
    spacing: Shared.DesktopStyle.px(16)
    // Search targets on a page tab: DesktopPanel asks the hosted page.
    function reveal(target) { return sectionLoader.item && sectionLoader.item.reveal ? sectionLoader.item.reveal(target) : false }

    Loader {
        id: sectionLoader
        Layout.fillWidth: true
        property real entrance: 1
        opacity: entrance
        transform: Translate { x: (1 - sectionLoader.entrance) * 12 }
        onLoaded: { if (initialized) sectionEnter.restart(); initialized = true }
        property bool initialized: false
        NumberAnimation { id: sectionEnter; target: sectionLoader; property: "entrance"; from: 0; to: 1; duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic }
        sourceComponent: ({power: powerPage, audio: audioPage, network: networkPage, system: systemPage, devices: devicesPage, session: sessionPage, displays: displaysPage})[DesktopData.controlTab] || networkPage
    }
    Component { id: displaysPage; DisplaysPage {} }
    Component { id: audioPage; SoundPage { studioExpanded: root.studioExpanded; onStudioExpandedChanged: root.studioExpanded = studioExpanded } }
    Component { id: networkPage; ConnectionsPage {} }
    Component { id: devicesPage; DevicesPage {} }
    Component { id: sessionPage; SessionPage {} }
    Component { id: powerPage; PowerPage {} }
    Component { id: systemPage; SystemPage {} }
}
