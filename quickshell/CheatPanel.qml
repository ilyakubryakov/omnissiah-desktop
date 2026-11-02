pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "bar" as Bar
import "shared" as Shared
import "ShortcutLogic.js" as Logic

PanelWindow {
    id: sheet
    required property var screenTarget
    property bool shown: false
    property bool presented: false
    property string selected: "Home"
    property var sheetData: ({sections: []})
    property string loadError: ""
    property string copied: ""
    readonly property var sections: sheetData.sections || []
    readonly property var blocks: Logic.blocks(sections, selected, search.text)
    readonly property int columnCount: content.width >= 760 ? 2 : 1
    readonly property var columns: Logic.columns(blocks, columnCount)
    screen: screenTarget
    visible: presented && screenTarget !== null
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omnissiah-cheatsheet"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    function open() {
        hideDelay.stop(); selected = "Home"; search.clear(); copied = ""; loadError = ""
        presented = true; shown = true
        refresh.running = true
        Qt.callLater(() => search.forceActiveFocus())
    }
    function close() { shown = false; hideDelay.restart() }
    function toggle() { if (shown) close(); else open() }
    function copyKeys(keys) {
        Quickshell.execDetached(["wl-copy", "--", keys])
        copied = keys; copiedDelay.restart()
    }
    onBlocksChanged: if (scroll.contentItem) scroll.contentItem.contentY = 0
    Timer { id: hideDelay; interval: Shared.DesktopStyle.fast; onTriggered: sheet.presented = false }
    Timer { id: copiedDelay; interval: 1600; onTriggered: sheet.copied = "" }
    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/cheatsheet.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { sheet.sheetData = JSON.parse(text()) } catch (_) { sheet.loadError = "Could not read the guide. Try Refresh." } }
    }
    Process {
        id: refresh
        command: [Quickshell.env("HOME") + "/.local/bin/cheatsheet-helper"]
        onExited: (code, status) => {
            if (code !== 0) sheet.loadError = "Could not refresh. Showing the last available copy."
            else { sheet.loadError = ""; file.reload() }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Bar.Colors.background.r, Bar.Colors.background.g, Bar.Colors.background.b, 0.42)
        opacity: sheet.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.fast } }
        MouseArea { anchors.fill: parent; onClicked: sheet.close() }
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(1280, sheet.width - 48); height: Math.min(900, sheet.height - 64)
        radius: Shared.DesktopStyle.radiusPanel
        color: Bar.Colors.background; border.width: 1; border.color: Bar.Colors.selection
        opacity: sheet.shown ? 1 : 0
        transform: Translate { y: sheet.shown ? 0 : 14; Behavior on y { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.fast } }
        MouseArea { anchors.fill: parent }
        Keys.onEscapePressed: { if (search.text) search.clear(); else sheet.close() }
        Shortcut { sequence: "Ctrl+F"; enabled: sheet.shown; onActivated: search.forceActiveFocus() }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 24; spacing: 18
            RowLayout {
                Layout.fillWidth: true; spacing: 14
                Rectangle {
                    implicitWidth: 48; implicitHeight: 48; radius: 14; color: Bar.Colors.selection
                    Bar.UiLabel { anchors.centerIn: parent; text: "\uf11c"; font.family: Bar.Colors.iconFont; font.pixelSize: 23; color: Bar.Colors.accent }
                }
                ColumnLayout {
                    spacing: 2; Layout.fillWidth: true
                    Bar.UiLabel { Layout.fillWidth: true; text: "Your desktop, at a glance"; font.pixelSize: 25; font.weight: Font.DemiBold }
                    Bar.UiLabel { Layout.fillWidth: true; text: "Shortcuts, panels and everyday actions"; color: Bar.Colors.muted; font.pixelSize: 13 }
                }
                Bar.UiButton { glyph: "\uf00d"; Accessible.name: "Close shortcuts and guide"; onClicked: sheet.close() }
            }
            TextField {
                id: search; Layout.fillWidth: true; implicitHeight: 44
                placeholderText: "Find an action: window, screenshot, notes, Win+F…    Ctrl+F"
                color: Bar.Colors.foreground; placeholderTextColor: Bar.Colors.muted
                font.family: Bar.Colors.textFont; font.pixelSize: 15
                leftPadding: 14; rightPadding: 14; selectByMouse: true
                background: Rectangle { radius: 12; color: Bar.Colors.lightBackground; border.color: search.activeFocus ? Bar.Colors.accent : Bar.Colors.selection; border.width: 1 }
                Keys.onEscapePressed: { if (text) clear(); else sheet.close() }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 22
                ScrollView {
                    id: navigation
                    Layout.preferredWidth: card.width < 900 ? 160 : 194; Layout.fillHeight: true
                    clip: true; contentWidth: availableWidth; ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ColumnLayout {
                        width: navigation.availableWidth; spacing: 5
                        Repeater {
                            model: sheet.sections
                            Bar.UiButton {
                                required property var modelData
                                Layout.fillWidth: true; alignLeft: true; subtle: true
                                text: modelData.label || modelData.name
                                glyph: String.fromCodePoint(modelData.icon || 0xF04CE)
                                selected: !search.text && sheet.selected === modelData.name
                                onClicked: { search.clear(); sheet.selected = modelData.name }
                            }
                        }
                    }
                }
                ColumnLayout {
                    id: content
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        Bar.UiLabel {
                            Layout.fillWidth: true; font.pixelSize: 18; font.weight: Font.DemiBold
                            text: search.text ? "Search results" : ((sheet.sections.find(s => s.name === sheet.selected) || {}).label || sheet.selected)
                        }
                        Bar.UiLabel { text: sheet.blocks.reduce((n, b) => n + b.rows.length, 0) + " tips"; font.pixelSize: 12; color: Bar.Colors.muted }
                    }
                    ScrollView {
                        id: scroll; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        contentWidth: availableWidth; ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        Row {
                            width: scroll.availableWidth; spacing: 14
                            Repeater {
                                model: sheet.columns
                                Column {
                                    id: lane
                                    required property var modelData
                                    width: (scroll.availableWidth - (sheet.columnCount - 1) * 14) / sheet.columnCount
                                    spacing: 14
                                    Repeater {
                                        model: lane.modelData
                                        Rectangle {
                                            id: block
                                            required property var modelData
                                            width: lane.width; implicitHeight: body.implicitHeight + 32
                                            radius: Shared.DesktopStyle.radiusCard
                                            color: Bar.Colors.lightBackground
                                            ColumnLayout {
                                                id: body; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 12
                                                Bar.UiLabel { text: block.modelData.title; color: Bar.Colors.accent; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true }
                                                Repeater {
                                                    model: block.modelData.rows
                                                    ColumnLayout {
                                                        id: entry
                                                        required property var modelData
                                                        Layout.fillWidth: true; spacing: 6
                                                        Bar.UiLabel {
                                                            Layout.fillWidth: true; text: block.modelData.guide ? entry.modelData.detail : entry.modelData.desc
                                                            font.pixelSize: 14; lineHeight: 1.18
                                                        }
                                                        ShortcutKeys {
                                                            Layout.fillWidth: true; visible: !!entry.modelData.keys
                                                            keys: entry.modelData.keys
                                                            copied: sheet.copied === keys
                                                            onCopyRequested: sheet.copyKeys(keys)
                                                            command: ["Utilities", "Repo"].includes(sheet.selected) || (search.text && !!entry.modelData.exec)
                                                        }
                                                        Bar.UiLabel { visible: !block.modelData.guide && !!entry.modelData.detail; Layout.fillWidth: true; text: entry.modelData.detail || ""; color: Bar.Colors.muted; font.pixelSize: 12 }
                                                    }
                                                }
                                                Bar.UiLabel { visible: !!block.modelData.hint; text: block.modelData.hint; font.pixelSize: 11; color: Bar.Colors.muted; Layout.fillWidth: true }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Bar.UiLabel { visible: !sheet.blocks.length; text: refresh.running ? "Collecting shortcuts from this session…" : search.text ? "No matches. Try an action name or a key combination." : "No data yet. Try Refresh."; Layout.fillWidth: true; color: Bar.Colors.muted }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Bar.UiLabel {
                    Layout.fillWidth: true; font.pixelSize: 12
                    text: sheet.loadError || sheet.sheetData.warning || (sheet.copied ? "Copied: " + sheet.copied : "Win = Meta / Super  ·  Click a shortcut or command to copy  ·  Esc to clear / close")
                    color: sheet.loadError || sheet.sheetData.warning ? Bar.Colors.yellow : sheet.copied ? Bar.Colors.accent : Bar.Colors.muted
                }
                Bar.UiButton { text: refresh.running ? "Refreshing…" : "Refresh"; glyph: "\uf021"; enabled: !refresh.running; onClicked: refresh.running = true }
            }
        }
    }
}
