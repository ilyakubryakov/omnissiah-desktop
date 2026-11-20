pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared
import "NotificationLogic.js" as Logic

Rectangle {
    id: root
    required property var notification
    property bool compact: false
    property bool live: false
    property bool buttonsOnly: false
    // A folded group of repeats: every id is dismissed together.
    property var ids: [String(notification.id)]
    property int count: 1
    property bool editing: false
    property bool wholeApp: false
    readonly property string tier: notification.tier || "normal"
    readonly property string app: notification.app_name || ""
    readonly property string ruleTier: Logic.ruleTier(DesktopData.notifications.rules, app, wholeApp ? "" : (notification.summary || ""))
    signal actionInvoked()
    readonly property string summary: notification.summary || "Notification"
    readonly property var actions: notification.actions || ({})
    readonly property bool canDiagnose: notification.app_name !== "Station Notebook"
        && (notification.urgency === "critical" || /error|failed|failure|exception|ошибк|сбой/i.test(summary))
    Layout.fillWidth: true
    implicitHeight: contents.implicitHeight + 24
    radius: Shared.DesktopStyle.radiusCard
    color: mouse.containsMouse || activeFocus ? Colors.selection : Colors.lightBackground
    border.width: notification.urgency === "critical" || activeFocus ? 1 : 0
    border.color: notification.urgency === "critical" && canDiagnose ? Colors.red : Colors.accent
    // Tiers: important carries an accent edge, quiet recedes.
    opacity: tier === "quiet" && !mouse.containsMouse && !activeFocus ? 0.72 : 1
    Rectangle {
        visible: root.tier === "important" || root.tier === "critical"
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 6 }
        width: 3; radius: 1.5
        color: root.tier === "critical" ? Colors.red : Colors.accent
    }
    Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: (notification.app_name || "Application") + ": " + summary
    function activate() {
        if (DesktopData.busy || buttonsOnly) return
        DesktopData.act("notification-open", [String(notification.id)])
        if (live && Object.prototype.hasOwnProperty.call(actions, "default")) actionInvoked()
    }
    Accessible.onPressAction: activate()
    Keys.onReturnPressed: activate()
    Keys.onSpacePressed: activate()
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.activate() }
    ColumnLayout {
        id: contents
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                UiLabel {
                    text: (root.notification.app_name || "Application") + (root.count > 1 ? "  ×" + root.count : "")
                        + (Logic.tierLabel(root.tier) ? "  · " + Logic.tierLabel(root.tier) : "")
                    color: root.tier === "quiet" ? Colors.muted : Colors.accent
                    font.pixelSize: Shared.DesktopStyle.px(11); Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight
                }
                UiLabel { text: root.summary; font.weight: Font.DemiBold; font.pixelSize: Shared.DesktopStyle.px(13); Layout.fillWidth: true; maximumLineCount: root.compact ? 2 : 4; elide: Text.ElideRight }
            }
            UiButton {
                visible: !root.compact && root.app !== "" && root.tier !== "critical"
                text: "Tier"; selected: root.editing
                Accessible.name: "Notification tier for " + root.app
                onClicked: root.editing = !root.editing
            }
            UiButton { glyph: "\u{F00D}"; Accessible.name: root.count > 1 ? "Dismiss " + root.count + " notifications" : "Dismiss notification"; enabled: !DesktopData.busy; onClicked: DesktopData.act("dismiss", root.ids) }
        }
        UiLabel {
            text: Logic.plainText(root.notification.body)
            visible: text !== ""; font.pixelSize: Shared.DesktopStyle.px(12); color: Colors.muted
            Layout.fillWidth: true; maximumLineCount: root.compact ? 2 : 12; elide: Text.ElideRight
        }
        Flow {
            Layout.fillWidth: true; spacing: 6
            visible: Logic.links(root.notification.body).length > 0 || Logic.verificationCode(root.summary, root.notification.body) !== ""
            Repeater {
                model: Logic.links(root.notification.body)
                UiButton {
                    required property string modelData
                    text: "Open link"; Accessible.name: "Open " + modelData
                    onClicked: Qt.openUrlExternally(modelData)
                }
            }
            UiButton {
                visible: Logic.verificationCode(root.summary, root.notification.body) !== ""
                text: "Copy code"; enabled: !DesktopData.busy
                onClicked: DesktopData.act("notification-copy-code", [String(root.notification.id)])
            }
        }
        // Future notifications from this title (or the whole app) get the chosen tier.
        Flow {
            visible: root.editing && !root.compact
            Layout.fillWidth: true; spacing: 6
            UiButton {
                text: root.wholeApp ? "All from " + root.app : "This title"
                onClicked: root.wholeApp = !root.wholeApp
            }
            Repeater {
                model: [["important", "Important"], ["normal", "Normal"], ["quiet", "Quiet"], ["hidden", "Hide"]]
                UiButton {
                    required property var modelData
                    text: modelData[1]; selected: root.ruleTier === modelData[0]
                    danger: modelData[0] === "hidden"
                    enabled: !DesktopData.busy
                    onClicked: {
                        DesktopData.act("notification-rule", [modelData[0], root.app, root.wholeApp ? "" : (root.notification.summary || "")])
                        root.editing = false
                    }
                }
            }
        }
        Flow {
            visible: (root.live && Object.keys(root.actions).length > 0) || (!root.compact && root.canDiagnose)
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: root.live ? Object.keys(root.actions) : []
                UiButton {
                    required property string modelData
                    text: root.actions[modelData] || "Open"
                    enabled: !DesktopData.busy
                    onClicked: { DesktopData.act("invoke", [String(root.notification.id), modelData]); root.actionInvoked() }
                }
            }
            UiButton { visible: root.canDiagnose; text: "Diagnose"; glyph: "\u{F0188}"; enabled: !DesktopData.busy; onClicked: { DesktopData.act("diagnose", [String(root.notification.id)]); root.actionInvoked() } }
        }
    }
}
