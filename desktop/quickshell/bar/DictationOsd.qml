pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../shared" as Shared

PanelWindow {
    id: root
    readonly property var stateData: DictationData.data
    readonly property var monitor: Hypr.monitors.find(m => m.id === stateData.monitor)
    readonly property var targetScreen: Quickshell.screens.find(s => root.monitor && s.name === root.monitor.name) || Shared.Screens.main
    screen: targetScreen
    visible: targetScreen !== null && stateData.phase !== "idle"
    anchors.bottom: true
    margins.bottom: PanelStyle.barHeight + PanelStyle.outerGap + 20
    implicitWidth: 420
    implicitHeight: contents.implicitHeight + 28
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oninix-dictation"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    focusable: false
    Connections {
        target: DictationData
        function onDataChanged() {
            if (["inserted", "copied", "empty", "handed"].includes(DictationData.data.phase)) { if (!hide.running) hide.start() }
            else hide.stop()
        }
    }
    Timer { id: hide; interval: 2000; onTriggered: DictationData.call({op:"dismiss"}) }
    Rectangle {
        anchors.fill: parent
        color: Colors.background; border.width: 1
        border.color: root.stateData.phase === "recording" ? Colors.accent : Colors.selection
        radius: Shared.DesktopStyle.radiusSmall
        ColumnLayout {
            id: contents
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                UiLabel { text: root.stateData.phase === "recording" ? "\u{F130}" : "\u{F11C}"; font.family: Colors.iconFont; color: Colors.accent; font.pixelSize: Shared.DesktopStyle.px(20) }
                UiLabel { text: root.stateData.phase === "recording" ? "Listening · " + Math.floor(root.stateData.seconds) + "s" : root.stateData.phase === "transcribing" ? "Whisper · recognizing" : "Dictation"; font.bold: true; Layout.fillWidth: true }
                UiButton { glyph: "\u{F00D}"; Accessible.name: "Cancel or dismiss dictation"; onClicked: DictationData.call({op:DictationData.active ? "cancel" : "dismiss"}) }
            }
            Rectangle {
                visible: root.stateData.phase === "recording"
                Layout.fillWidth: true; height: 5; radius: 2; color: Colors.selection
                Rectangle { width: parent.width * (root.stateData.level || 0); height: parent.height; radius: 2; color: Colors.accent; Behavior on width { NumberAnimation { duration: 150 } } }
            }
            UiLabel { text: DictationData.error || root.stateData.message || ""; Layout.fillWidth: true; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(12) }
            ScrollView {
                visible: !!root.stateData.text
                Layout.fillWidth: true; Layout.preferredHeight: Math.min(160, transcript.implicitHeight + 8)
                contentWidth: availableWidth; clip: true
                TextArea { id: transcript; text: root.stateData.text || ""; readOnly: true; wrapMode: TextEdit.Wrap; textFormat: TextEdit.PlainText; color: Colors.foreground; font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(14); background: null }
            }
            RowLayout {
                visible: !!root.stateData.text || root.stateData.phase === "error"
                UiButton { visible: !!root.stateData.text; text: "Copy text"; onClicked: DictationData.call({op:"copy"}) }
                UiButton { visible: root.stateData.phase === "error"; text: "Retry"; onClicked: DictationData.call({op:"retry"}) }
                Item { Layout.fillWidth: true }
            }
        }
    }
}
