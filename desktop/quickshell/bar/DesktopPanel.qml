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
    signal guideRequested()
    signal toolRequested(string tool)
    property bool opened: false
    property bool presented: false
    property string page: "controls"
    property string section: "network"
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
        } else if (["calendars", "modes"].includes(section)) page = section
        else { page = "controls"; DesktopData.controlTab = section }
        DesktopData.page = page; CalendarAccounts.opened = page === "calendars"
        focusText = target || ""; highlightY = -1; restoreScroll.restart()
        DesktopData.refresh()
    }
    function show(which) {
        if (which === "guide") { openGuide(); return }
        if (which === "notifications") { DesktopData.notificationsRequested(); return }
        PopupState.close(); hideDelay.stop(); presented = true
        let key = which === "controls" ? (DesktopData.controlTab || ShellPrefs.ui.last || "network") : which === "appearance" ? "themes" : which
        choose(key); opened = true; DesktopData.open = true; DesktopData.refresh(); DesktopData.error = ""
        Hypr.refresh(); body.forceActiveFocus()
        const client = Hypr.clients.find(c => c.class === "org.quickshell" && c.title === root.title)
        if (client) Minimized.show(client)
    }
    function close() {
        if (!opened) return
        remember(); ShellPrefs.editingPanels = false; opened = false; hideDelay.restart(); DesktopData.open = false; DesktopData.controlTab = ""
        DesktopData.clips = []; CalendarAccounts.opened = false
    }
    function toggle(which) {
        if (opened && Hypr.active.class === "org.quickshell" && Hypr.active.title === title) close()
        else show(which)
    }
    function openGuide() { close(); guideRequested() }
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
                if (pageLoader.item && pageLoader.item.reveal && pageLoader.item.reveal(root.focusText)) { restart(); return }
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
        function toggle(page: string): void {
            if (page === "controls" && ControlCenterState.toggle()) return
            if (page === "overview" || page === "clipboard") { root.close(); root.toolRequested(page); return }
            root.toggle(page === "settings" ? "controls" : page)
        }
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
        Keys.onPressed: event => {
            if (root.opened && event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                search.forceActiveFocus()
                event.accepted = true
            }
        }
        Rectangle { anchors.fill: parent; radius: Shared.DesktopStyle.px(20); color: Colors.background; border.width: 1; border.color: Colors.selection }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: Shared.DesktopStyle.px(20); spacing: Shared.DesktopStyle.px(14)
            RowLayout {
                Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(14)
                Item {
                    Layout.preferredWidth: Shared.DesktopStyle.px(198); Layout.preferredHeight: Shared.DesktopStyle.px(44)
                    Image {
                        width: Shared.DesktopStyle.px(44); height: Shared.DesktopStyle.px(44)
                        source: "file://" + Quickshell.env("ONINIX_SHARE") + "/quickshell/assets/mechanicus.png"
                        readonly property int rasterSize: Math.ceil(44 * (root.screen ? root.screen.devicePixelRatio : 1))
                        sourceSize: Qt.size(rasterSize, rasterSize); fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                        Accessible.ignored: true
                    }
                    UiLabel { x: 54; anchors.verticalCenter: parent.verticalCenter; text: "CONTROL\nSTATION"; color: Colors.accent; font.pixelSize: Shared.DesktopStyle.px(11); font.letterSpacing: Shared.DesktopStyle.px(2) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.SizeAllCursor; onPressed: root.startSystemMove() }
                }
                TextField {
                    id: search; Layout.fillWidth: true; placeholderText: "Find a setting…   Ctrl+F"
                    color: Colors.foreground; placeholderTextColor: Colors.muted; selectByMouse: true
                    background: Rectangle { radius: Shared.DesktopStyle.px(10); color: Colors.lightBackground; border.color: search.activeFocus ? Colors.accent : Colors.selection; border.width: 1 }
                    onAccepted: {
                        const items = Catalog.search(text)
                        if (!items.length) return
                        const hits = Catalog.matches(text, items[0].id)
                        root.choose(items[0].id, hits.length ? hits[0].target : Catalog.target(text)); clear()
                    }
                }
                UiButton { glyph: "\uf00d"; Accessible.name: "Close Control Station"; onClicked: root.close() }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: Shared.DesktopStyle.px(18)
                ScrollView {
                    id: navigation; Layout.preferredWidth: Shared.DesktopStyle.px(198); Layout.fillHeight: true; clip: true
                    contentWidth: availableWidth; ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ColumnLayout {
                        width: navigation.availableWidth; spacing: Shared.DesktopStyle.px(3)
                        Repeater {
                            id: navRepeater
                            model: Catalog.search(search.text)
                            ColumnLayout {
                                id: entry
                                required property var modelData
                                required property int index
                                readonly property bool groupStart: index > 0 && navRepeater.model[index - 1].group !== modelData.group
                                readonly property var hits: Catalog.matches(search.text, modelData.id)
                                Layout.fillWidth: true; spacing: 1
                                Rectangle {
                                    visible: entry.groupStart
                                    Layout.fillWidth: true; Layout.topMargin: Shared.DesktopStyle.px(6); Layout.bottomMargin: Shared.DesktopStyle.px(6)
                                    Layout.leftMargin: Shared.DesktopStyle.px(10); Layout.rightMargin: Shared.DesktopStyle.px(10)
                                    implicitHeight: 1; color: Colors.selection
                                }
                                SidebarItem {
                                    Layout.fillWidth: true
                                    text: entry.modelData.title; glyph: entry.modelData.glyph; tone: Colors[entry.modelData.tone] || Colors.accent
                                    selected: root.section === entry.modelData.id
                                    onClicked: { root.choose(entry.modelData.id, search.text ? (entry.hits.length ? entry.hits[0].target : Catalog.target(search.text)) : ""); search.clear() }
                                }
                                Repeater {
                                    model: entry.hits
                                    UiButton {
                                        required property var modelData
                                        Layout.fillWidth: true; Layout.leftMargin: Shared.DesktopStyle.px(22); subtle: true; alignLeft: true
                                        text: modelData.title; glyph: "\uf105"
                                        Accessible.name: "Go to " + modelData.title
                                        onClicked: { root.choose(entry.modelData.id, modelData.target); search.clear() }
                                    }
                                }
                            }
                        }
                        UiLabel { visible: Catalog.search(search.text).length === 0; text: "No matching settings"; color: Colors.muted; Layout.fillWidth: true }
                        SidebarItem { visible: !search.text; Layout.fillWidth: true; Layout.topMargin: Shared.DesktopStyle.px(6); text: "Notifications"; glyph: "\uf0f3"; tone: Colors.red; onClicked: DesktopData.notificationsRequested() }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: Shared.DesktopStyle.px(12)
                    RowLayout {
                        Layout.fillWidth: true
                        UiLabel { text: Catalog.page(root.section).title; font.pixelSize: Shared.DesktopStyle.px(23); font.weight: Font.DemiBold; Layout.fillWidth: true }
                        UiLabel { visible: DesktopData.busy || ShellPrefs.busy; text: "Saving…"; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12) }
                    }
                    UiLabel { visible: DesktopData.error !== "" || ShellPrefs.error !== ""; text: DesktopData.error || ShellPrefs.error; color: Colors.red; Layout.fillWidth: true }
                    RowLayout {
                        visible: root.page === "appearance" && ShellPrefs.undoAvailable
                        Layout.fillWidth: true
                        UiLabel { text: ShellPrefs.undoLabel; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12); Layout.fillWidth: true }
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
                            sourceComponent: root.page === "appearance" ? appearance : root.page === "calendars" ? calendars : root.page === "modes" ? modes : controls
                            Rectangle {
                                visible: root.highlightY >= 0; y: Math.max(0, root.highlightY); width: parent.width; height: Shared.DesktopStyle.px(40)
                                radius: Shared.DesktopStyle.px(8); color: "transparent"; border.width: 2; border.color: Colors.accent
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
    Component { id: controls; ControlCenter { cal: root.cal } }
    Component { id: calendars; CalendarAccountsPage {} }
    Component { id: appearance; AppearancePanel { section: root.appearanceSection } }
    Component { id: modes; WorkModesPage {} }
}
