pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "NotificationLogic.js" as Logic
import "../shared" as Shared

ColumnLayout {
    id: root
    signal actionInvoked()
    spacing: 12
    property bool showRules: false
    readonly property var groups: Logic.groups(DesktopData.notifications.current, DesktopData.notifications.history)
    readonly property var suggestions: DesktopData.notifications.suggestions || []
    readonly property var rules: DesktopData.notifications.rules || []
    RowLayout {
        Layout.fillWidth: true
        UiButton { text: "DND"; glyph: "\u{F0F3}"; selected: !!DesktopData.controls.dnd; enabled: !DesktopData.busy; onClicked: DesktopData.act("dnd") }
        Item { Layout.fillWidth: true }
        UiButton { text: "Clear all"; glyph: "\u{F039F}"; enabled: !DesktopData.busy && root.groups.length > 0; onClicked: DesktopData.act("clear") }
    }
    UiLabel { Layout.fillWidth: true; text: DesktopData.controls.dnd ? "Do not disturb · critical alerts can still appear." : "Recent messages · " + root.groups.length; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12) }
    UiLabel { visible: !!DesktopData.notifications.error || !!DesktopData.error; Layout.fillWidth: true; text: DesktopData.notifications.error || DesktopData.error; color: Colors.red }
    // From the local delivery log: titles that keep arriving and are never opened.
    ColumnLayout {
        visible: root.suggestions.length > 0
        Layout.fillWidth: true; spacing: 6
        UiLabel { text: "Often ignored · last 7 days"; color: Colors.accent; font.pixelSize: Shared.DesktopStyle.px(11); font.letterSpacing: 1 }
        Repeater {
            model: root.suggestions
            RowLayout {
                id: suggestion
                required property var modelData
                Layout.fillWidth: true
                UiLabel {
                    Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1
                    text: suggestion.modelData.app + " · " + (suggestion.modelData.summary || "all titles") + " · " + suggestion.modelData.count + "×, never opened"
                    font.pixelSize: Shared.DesktopStyle.px(12)
                }
                UiButton { text: "Make quiet"; enabled: !DesktopData.busy; onClicked: DesktopData.act("notification-rule", ["quiet", suggestion.modelData.app, suggestion.modelData.summary]) }
            }
        }
    }
    UiLabel { visible: root.groups.length === 0; text: "All clear\nYour next notifications will appear here."; color: Colors.muted; Layout.topMargin: 32; Layout.bottomMargin: 32; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
    Repeater {
        model: root.groups
        NotificationItem {
            required property var modelData
            notification: modelData.notification
            ids: modelData.ids
            count: modelData.count
            live: modelData.live
            onActionInvoked: root.actionInvoked()
        }
    }
    UiButton {
        visible: root.rules.length > 0
        Layout.fillWidth: true
        text: (root.showRules ? "Hide tier rules" : "Tier rules") + " · " + root.rules.length
        onClicked: root.showRules = !root.showRules
    }
    Repeater {
        model: root.showRules ? root.rules : []
        RowLayout {
            id: rule
            required property var modelData
            Layout.fillWidth: true
            UiLabel {
                Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1; font.pixelSize: Shared.DesktopStyle.px(12)
                text: Logic.tierLabel(rule.modelData.tier) + " · " + rule.modelData.app + " · " + (rule.modelData.summary || "all titles")
            }
            UiButton {
                glyph: "\u{F00D}"; Accessible.name: "Remove rule for " + rule.modelData.app
                enabled: !DesktopData.busy
                onClicked: DesktopData.act("notification-rule", ["normal", rule.modelData.app, rule.modelData.summary])
            }
        }
    }
}
