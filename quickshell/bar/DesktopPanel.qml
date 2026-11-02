pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../shared" as Shared
import "SettingsCatalog.js" as Catalog

FloatingWindow {
    id: root
    title: "Control Station"
    property var cal: null
    signal calendarRequested()
    property bool opened: false
    property bool presented: false
    property string page: "controls"
    property string section: "quick"
    property string appearanceSection: "themes"
    property var scrollPositions: ({})
    property string focusText: ""
    property real highlightY: -1
    screen: Shared.Screens.main
    visible: Shared.Screens.main !== null && presented
    implicitWidth: Math.min(1080, screen ? screen.width - 40 : 1080)
    implicitHeight: Math.min(900, screen ? screen.height - 80 : 900)
    minimumSize: Qt.size(Math.min(760, implicitWidth), Math.min(560, implicitHeight))
    color: "transparent"
    onClosed: { close(); hideDelay.stop(); presented = false }
    function remember() {
        const next = Object.assign({}, scrollPositions)
        next[section] = scroll.ScrollBar.vertical.position
        scrollPositions = next
        ShellPrefs.send("ui", {last: section, scroll: next})
    }
    function choose(key, target) {
        if (key === "guide") { openGuide(); return }
        if (opened) remember()
        section = Catalog.page(key).id
        if (["themes", "panels", "apps"].includes(section)) {
            page = "appearance"; appearanceSection = section
        } else if (["clipboard", "calendars", "overview", "modes"].includes(section)) page = section
        else { page = "controls"; DesktopData.controlTab = section }
        DesktopData.page = page; CalendarAccounts.opened = page === "calendars"
        focusText = target || ""; highlightY = -1; restoreScroll.restart()
        DesktopData.refresh()
    }
    function show(which) {
        if (which === "guide") { openGuide(); return }
        if (which === "notifications") { DesktopData.notificationsRequested(); return }
        PopupState.close(); hideDelay.stop(); presented = true
        let key = which === "controls" ? DesktopData.controlTab : which === "appearance" ? "themes" : which
        if (!opened && which === "controls" && DesktopData.controlTab === "quick") key = ShellPrefs.ui.last || "quick"
        choose(key); opened = true; DesktopData.open = true; DesktopData.refresh(); DesktopData.error = ""
        Hypr.refresh(); body.forceActiveFocus()
        const client = Hypr.clients.find(c => c.class === "org.quickshell" && c.title === root.title)
        if (client) Minimized.show(client)
    }
    function close() {
        if (!opened) return
        remember(); ShellPrefs.editingPanels = false; opened = false; hideDelay.restart(); DesktopData.open = false
        DesktopData.clips = []; CalendarAccounts.opened = false
    }
    function toggle(which) {
        if (opened && Hypr.active.class === "org.quickshell" && Hypr.active.title === title) close()
        else show(which)
    }
    function openGuide() {
        close()
        const entry = "cheat.qml"
        Quickshell.execDetached(["quickshell", "-p", Quickshell.env("HOME") + "/.config/quickshell/" + entry, "ipc", "call", "cheat", "toggle"])
    }
    function findLabel(item, text) {
        if (!item) return null
        if (typeof item.text === "string" && item.text.toLowerCase().includes(text.toLowerCase()) && item.visible) return item
        for (const child of (item.children || [])) { const found = findLabel(child, text); if (found) return found }
        return null
    }
    Timer {
        id: restoreScroll; interval: 160
        onTriggered: {
            if (root.focusText) {
                const label = root.findLabel(pageLoader.item, root.focusText)
                if (label) {
                    root.highlightY = Math.max(0, label.mapToItem(pageLoader, 0, 0).y - 8)
                    scroll.ScrollBar.vertical.position = Math.max(0, Math.min(1 - scroll.ScrollBar.vertical.size, root.highlightY / Math.max(1, pageLoader.height)))
                    highlightDelay.restart()
                }
            } else scroll.ScrollBar.vertical.position = Math.max(0, Math.min(1 - scroll.ScrollBar.vertical.size, root.scrollPositions[root.section] || 0))
        }
    }
    Timer { id: highlightDelay; interval: 2000; onTriggered: root.highlightY = -1 }
    Timer { id: hideDelay; interval: Shared.DesktopStyle.fast; onTriggered: if (!root.opened) root.presented = false }
    IpcHandler {
        target: "desktop"
        function toggle(page: string): void { root.toggle(page) }
        function close(): void { root.close() }
        function control(tab: string): void { root.show(tab) }
    }
    Connections { target: ShellPrefs; function onReady() { root.scrollPositions = ShellPrefs.ui.scroll || ({}) } function onChanged() { if (root.opened && root.page === "appearance") DesktopData.readAppearance() } }
    Connections { target: PinnedApps; function onSettingsRequested() { root.show("apps") } }
    Connections {
        target: DesktopData
        function onControlTabChanged() {
            if (root.opened && root.page === "controls" && root.section !== DesktopData.controlTab) root.choose(DesktopData.controlTab)
        }
    }
    FocusScope {
        id: body; anchors.fill: parent
        opacity: root.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.fast } }
        Keys.onEscapePressed: { if (search.text) search.clear(); else root.close() }
        Shortcut { sequence: "Ctrl+F"; enabled: root.opened; onActivated: search.forceActiveFocus() }
        Rectangle { anchors.fill: parent; radius: 20; color: Colors.background; border.width: 1; border.color: Colors.selection }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 20; spacing: 14
            RowLayout {
                Layout.fillWidth: true; spacing: 14
                Item {
                    Layout.preferredWidth: 198; Layout.preferredHeight: 44
                    Image {
                        width: 44; height: 44
                        source: Qt.resolvedUrl("../assets/mark.svg")
                        readonly property int rasterSize: Math.ceil(44 * (root.screen ? root.screen.devicePixelRatio : 1))
                        sourceSize: Qt.size(rasterSize, rasterSize); fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                        Accessible.ignored: true
                    }
                    UiLabel { x: 54; anchors.verticalCenter: parent.verticalCenter; text: "CONTROL\nSTATION"; color: Colors.accent; font.pixelSize: 11; font.letterSpacing: 2 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.SizeAllCursor; onPressed: root.startSystemMove() }
                }
                TextField {
                    id: search; Layout.fillWidth: true; placeholderText: "Find a setting…   Ctrl+F"
                    color: Colors.foreground; placeholderTextColor: Colors.muted; selectByMouse: true
                    background: Rectangle { radius: 10; color: Colors.lightBackground; border.color: search.activeFocus ? Colors.accent : Colors.selection; border.width: 1 }
                    onAccepted: { const items = Catalog.search(text); if (items.length) { root.choose(items[0].id, Catalog.target(text)); clear() } }
                }
                UiButton { glyph: "\uf00d"; Accessible.name: "Close Control Station"; onClicked: root.close() }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 18
                ScrollView {
                    id: navigation; Layout.preferredWidth: 198; Layout.fillHeight: true; clip: true
                    contentWidth: availableWidth; ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ColumnLayout {
                        width: navigation.availableWidth; spacing: 3
                        Repeater {
                            model: Catalog.search(search.text)
                            UiButton {
                                required property var modelData
                                Layout.fillWidth: true; subtle: true; alignLeft: true; text: modelData.title; glyph: modelData.glyph
                                selected: root.section === modelData.id
                                onClicked: { root.choose(modelData.id, search.text ? Catalog.target(search.text) : ""); search.clear() }
                            }
                        }
                        UiLabel { visible: Catalog.search(search.text).length === 0; text: "No matching settings"; color: Colors.muted; Layout.fillWidth: true }
                        UiButton { visible: !search.text; Layout.fillWidth: true; subtle: true; alignLeft: true; text: "Notifications"; glyph: "\uf0f3"; onClicked: DesktopData.notificationsRequested() }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        UiLabel { text: Catalog.page(root.section).title; font.pixelSize: 23; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        UiLabel { visible: DesktopData.busy || ShellPrefs.busy; text: "Saving…"; color: Colors.muted; font.pixelSize: 12 }
                    }
                    UiLabel { visible: DesktopData.error !== "" || ShellPrefs.error !== ""; text: DesktopData.error || ShellPrefs.error; color: Colors.red; Layout.fillWidth: true }
                    RowLayout {
                        visible: root.page === "appearance" && ShellPrefs.undoAvailable
                        Layout.fillWidth: true
                        UiLabel { text: ShellPrefs.undoLabel; color: Colors.muted; font.pixelSize: 12; Layout.fillWidth: true }
                        UiButton { text: "Undo"; glyph: "\uf0e2"; enabled: !ShellPrefs.busy; onClicked: ShellPrefs.send("undo", null) }
                    }
                    ScrollView {
                        id: scroll; Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
                        clip: true; contentWidth: availableWidth; contentHeight: pageLoader.implicitHeight
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        Loader {
                            id: pageLoader; width: scroll.availableWidth - 12; active: root.presented
                            property real entrance: 1
                            opacity: entrance
                            onLoaded: { pageEnter.restart(); restoreScroll.restart() }
                            NumberAnimation { id: pageEnter; target: pageLoader; property: "entrance"; from: 0; to: 1; duration: Shared.DesktopStyle.fast }
                            sourceComponent: root.page === "controls" ? controls : root.page === "clipboard" ? clipboard : root.page === "appearance" ? appearance : root.page === "calendars" ? calendars : root.page === "modes" ? modes : overview
                            Rectangle {
                                visible: root.highlightY >= 0; y: Math.max(0, root.highlightY); width: parent.width; height: 40
                                radius: 8; color: "transparent"; border.width: 2; border.color: Colors.accent
                            }
                        }
                    }
                }
            }
        }
    }

    Repeater {
        model: [Qt.TopEdge, Qt.BottomEdge, Qt.LeftEdge, Qt.RightEdge,
                Qt.TopEdge | Qt.LeftEdge, Qt.TopEdge | Qt.RightEdge,
                Qt.BottomEdge | Qt.LeftEdge, Qt.BottomEdge | Qt.RightEdge]
        MouseArea {
            required property int modelData
            readonly property bool horizontal: !!(modelData & (Qt.LeftEdge | Qt.RightEdge))
            readonly property bool vertical: !!(modelData & (Qt.TopEdge | Qt.BottomEdge))
            readonly property bool corner: horizontal && vertical
            width: corner ? 14 : horizontal ? 7 : root.width - 28
            height: corner ? 14 : vertical ? 7 : root.height - 28
            x: modelData & Qt.RightEdge ? root.width - width : horizontal ? 0 : 14
            y: modelData & Qt.BottomEdge ? root.height - height : vertical ? 0 : 14
            cursorShape: corner ? ((modelData === (Qt.TopEdge | Qt.LeftEdge) || modelData === (Qt.BottomEdge | Qt.RightEdge)) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor) : horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
            onPressed: root.startSystemResize(modelData)
        }
    }
    Component { id: controls; ControlCenter { cal: root.cal; onNotificationsRequested: DesktopData.notificationsRequested(); onCalendarRequested: root.calendarRequested(); onAppearanceRequested: root.show("appearance") } }
    Component { id: clipboard; ClipboardPanel {} }
    Component { id: calendars; CalendarAccountsPage {} }
    Component { id: appearance; AppearancePanel { section: root.appearanceSection } }
    Component { id: overview; WindowOverview {} }
    Component { id: modes; WorkModesPage {} }
}
