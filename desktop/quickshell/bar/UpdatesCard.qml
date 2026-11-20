pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

// One answer, one action (owner decision 2026-11-08): up to date, updates
// waiting (no rush) or time to update. The agent session does the updating;
// the found changes stay folded behind Details.
ColumnLayout {
    id: root
    property real maxHeight: 600
    property bool details: false
    readonly property var updates: Shared.UpdatesData
    readonly property string level: updates.level
    readonly property int count: updates.count
    readonly property bool busy: updates.checking || updates.sessionOpen
    readonly property int changeTotal: (updates.available || []).length + (updates.packages || []).length
    spacing: Shared.DesktopStyle.px(12)

    readonly property color tone: level === "due" ? Colors.statusAvailable
        : level === "current" ? Colors.green : level === "error" ? Colors.statusWarning : Colors.foreground
    readonly property string headline: level === "checking" ? "Checking for updates…"
        : level === "error" ? "The last check failed"
        : level === "stale" ? "Not checked yet"
        : level === "due" ? "Time to update"
        : level === "available" ? (count === 1 ? "1 update waiting" : count > 1 ? count + " updates waiting" : "Updates waiting")
        : "Everything is up to date"
    readonly property string subline: updates.sessionOpen ? "An update session is open."
        : level === "error" ? updates.error
        : level === "checking" ? "Evaluating the newer NixOS configuration and upstream releases."
        : level === "stale" ? "The daily check runs in the background."
        : level === "due" ? (updates.reasons || []).map(r => r.charAt(0).toUpperCase() + r.slice(1)).join(" · ")
        : level === "available" ? "No rush. You will be told when it is time to update."
        : "Checked daily. Nothing installs until you start an update."

    function shortRef(value) { return /^[0-9a-f]{40}$/.test(value || "") ? value.slice(0, 7) : value || "" }

    component Divider: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.selection }
    component Note: UiLabel {
        Layout.fillWidth: true; visible: text !== ""; wrapMode: Text.Wrap
        font.pixelSize: Shared.DesktopStyle.px(12)
    }
    component ChangeRow: RowLayout {
        id: change
        required property string name
        required property string version
        Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(10)
        UiLabel { Layout.fillWidth: true; text: change.name; elide: Text.ElideRight; font.pixelSize: Shared.DesktopStyle.px(12) }
        UiLabel { text: change.version; color: Colors.muted; elide: Text.ElideLeft; Layout.maximumWidth: Shared.DesktopStyle.px(220); font.pixelSize: Shared.DesktopStyle.px(11); font.features: { "tnum": 1 } }
    }

    CardHeader {
        glyph: "\u{F06B0}"; title: "System updates"
        note: root.updates.result.checkedAt ? "Checked " + root.updates.stamp : ""
    }

    RowLayout {
        Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(14)
        Text {
            readonly property bool numeric: (root.level === "available" || root.level === "due") && root.count > 0
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: Shared.DesktopStyle.px(34)
            horizontalAlignment: Text.AlignHCenter
            text: numeric ? String(root.count)
                : root.level === "current" ? "\u{F05E0}"
                : root.level === "error" ? "\u{F0028}" : "\u{F06B0}"
            color: root.tone
            font.family: numeric ? Colors.textFont : Colors.iconFont
            font.pixelSize: Shared.DesktopStyle.px(numeric ? 34 : 30)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            UiLabel { Layout.fillWidth: true; text: root.headline; color: root.tone; wrapMode: Text.Wrap; font.pixelSize: Shared.DesktopStyle.px(15); font.weight: Font.DemiBold }
            Note { text: root.subline; color: Colors.muted }
        }
    }

    // Only things the owner should know: the agent handles a blocked NixOS update,
    // and a source that has not answered for three days.
    Note {
        text: root.updates.blocker && root.level !== "stale" ? "The NixOS update needs a configuration change; the update agent handles it." : ""
        color: Colors.muted
    }
    Note {
        readonly property var names: root.updates.unreachable || []
        text: names.length && root.level !== "stale" ? "Not reachable for 3+ days: " + names.join(", ") : ""
        color: Colors.statusWarning
    }

    UiButton {
        Layout.fillWidth: true
        visible: root.level === "due" || root.level === "available"
        selected: root.level === "due"
        glyph: "\u{F06B0}"
        text: root.updates.sessionOpen ? "Update session open" : "Update with " + root.updates.agentLabel
        enabled: !root.busy
        onClicked: root.updates.launch()
    }

    Flickable {
        visible: root.details && root.changeTotal > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(changes.implicitHeight, root.maxHeight)
        contentWidth: width; contentHeight: changes.implicitHeight
        clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: changes
            width: parent.width; spacing: Shared.DesktopStyle.px(4)
            Repeater {
                model: root.updates.available
                ChangeRow {
                    required property var modelData
                    name: modelData.name
                    version: root.shortRef(modelData.current) + "  →  " + root.shortRef(modelData.latest)
                }
            }
            Repeater {
                model: root.updates.packages.slice(0, 40)
                ChangeRow {
                    required property var modelData
                    name: modelData.name
                    version: (modelData.current || "") + "  →  " + (modelData.latest || "")
                }
            }
            UiLabel {
                visible: root.updates.packages.length > 40
                text: "+ " + (root.updates.packages.length - 40) + " more package changes"
                color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(11)
            }
        }
    }

    Divider {}
    RowLayout {
        Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(8)
        UiButton {
            visible: root.changeTotal > 0 && (root.level === "due" || root.level === "available")
            subtle: true; selected: root.details
            glyph: root.details ? "\u{F0140}" : "\u{F0142}"
            text: "Details · " + root.changeTotal
            onClicked: root.details = !root.details
        }
        Item { Layout.fillWidth: true }
        UiButton {
            subtle: true
            text: root.updates.checking ? "Checking…" : "Check now"
            glyph: "\u{F0450}"
            enabled: !root.busy
            onClicked: root.updates.check()
        }
    }
}
