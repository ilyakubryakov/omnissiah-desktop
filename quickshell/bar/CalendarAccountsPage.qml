pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../shared" as Shared

ColumnLayout {
    id: root
    property string provider: "google"
    property bool setup: false
    property bool adding: false
    property string removeId: ""
    spacing: 16
    Component.onCompleted: CalendarAccounts.opened = true
    Component.onDestruction: CalendarAccounts.opened = false
    Connections {
        target: CalendarAccounts
        function onOperationFinished(operation) { if (operation === "connect" || operation === "feed") root.adding = false }
    }
    function providerName(value) { return value === "google" ? "Google" : value === "microsoft" ? "Microsoft 365" : "iCalendar subscription" }
    function syncText(calendar) {
        if (!calendar.selected) return "Hidden"
        const sync = calendar.sync || ({})
        if (sync.ok === false) return sync.err || "Sync failed · saved events"
        if (!sync.ts) return "Waiting for first sync"
        return (sync.n === undefined ? "Synced" : sync.n + " events") + " · " + Qt.formatDateTime(new Date(sync.ts * 1000), "ddd HH:mm")
    }
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            UiLabel { text: "YOUR CALENDARS"; color: Colors.accent; font.pixelSize: 11; font.letterSpacing: 2 }
            UiLabel { text: root.adding ? "Connect a calendar account" : "One agenda, all your accounts"; font.pixelSize: 22; font.weight: Font.DemiBold }
        }
        UiButton { text: "Sync now"; glyph: "\u{F021}"; visible: !root.adding; enabled: !CalendarAccounts.busy; onClicked: CalendarAccounts.request({op: "sync"}) }
    }
    UiLabel {
        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Colors.muted
        text: "Google and Microsoft sign-in opens in your browser. Station reads calendars; it cannot create, change or delete meetings."
    }
    UiLabel {
        visible: CalendarAccounts.error !== "" || CalendarAccounts.message !== ""
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        color: CalendarAccounts.error ? Colors.red : Colors.accent
        text: CalendarAccounts.error || CalendarAccounts.message
    }
    RowLayout {
        visible: CalendarAccounts.signingIn
        UiButton { text: "Open sign-in again"; enabled: CalendarAccounts.authUrl !== ""; onClicked: Qt.openUrlExternally(CalendarAccounts.authUrl) }
        UiButton { text: "Cancel sign-in"; onClicked: CalendarAccounts.cancel() }
    }
    UiLabel {
        Layout.fillWidth: true; color: Colors.muted
        visible: CalendarAccounts.busy && CalendarAccounts.authUrl === ""
        text: CalendarAccounts.signingIn ? "Preparing secure sign-in…" : "Updating calendars…"
    }
    Repeater {
        model: root.adding ? [] : CalendarAccounts.accounts
        Rectangle {
            id: account
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: contents.implicitHeight + 28
            radius: Shared.DesktopStyle.radiusSmall
            color: Colors.lightBackground
            ColumnLayout {
                id: contents
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    UiLabel { text: "\u{F073}"; font.family: Colors.iconFont; color: Colors.accent; font.pixelSize: 22 }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        UiLabel { Layout.fillWidth: true; text: account.modelData.email || account.modelData.label; elide: Text.ElideRight; font.weight: Font.DemiBold }
                        UiLabel { text: root.providerName(account.modelData.provider) + (account.modelData.enabled ? "" : " · Paused"); color: Colors.muted; font.pixelSize: 12 }
                    }
                    UiButton {
                        text: account.modelData.enabled ? "Pause" : "Resume"
                        enabled: !CalendarAccounts.busy
                        onClicked: CalendarAccounts.request({op: "enable", id: account.modelData.id, enabled: !account.modelData.enabled})
                    }
                }
                UiLabel {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Colors.red
                    visible: !!account.modelData.error
                    text: account.modelData.error ? account.modelData.error.message : ""
                }
                Repeater {
                    model: account.modelData.calendars
                    RowLayout {
                        id: calendar
                        required property var modelData
                        Layout.fillWidth: true; spacing: 10
                        UiButton {
                            glyph: calendar.modelData.selected ? "\u{F00C}" : "\u{F067}"
                            selected: calendar.modelData.selected
                            Accessible.name: (calendar.modelData.selected ? "Hide " : "Show ") + calendar.modelData.name
                            enabled: !CalendarAccounts.busy && account.modelData.enabled
                            onClicked: CalendarAccounts.select(account.modelData, calendar.modelData.id, !calendar.modelData.selected)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            UiLabel { Layout.fillWidth: true; text: calendar.modelData.name; elide: Text.ElideRight; font.pixelSize: 13 }
                            UiLabel {
                                Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 11
                                color: calendar.modelData.sync && calendar.modelData.sync.ok === false && calendar.modelData.selected ? Colors.yellow : Colors.muted
                                text: account.modelData.enabled ? root.syncText(calendar.modelData) : "Paused · saved settings"
                            }
                        }
                    }
                }
                UiLabel { visible: account.modelData.calendars.length === 0; text: "No calendars loaded yet. Refresh after signing in."; color: Colors.muted }
                RowLayout {
                    Layout.fillWidth: true
                    UiButton { text: "Refresh list"; visible: account.modelData.provider !== "ics"; enabled: !CalendarAccounts.busy; onClicked: CalendarAccounts.request({op: "discover", id: account.modelData.id}) }
                    UiButton { text: "Sign in again"; visible: account.modelData.provider !== "ics"; enabled: !CalendarAccounts.busy; onClicked: CalendarAccounts.request({op: "connect", id: account.modelData.id}) }
                    Item { Layout.fillWidth: true }
                    UiButton { text: "Remove"; danger: true; enabled: !CalendarAccounts.busy; onClicked: root.removeId = account.modelData.id }
                }
                ColumnLayout {
                    visible: root.removeId === account.modelData.id
                    Layout.fillWidth: true
                    UiLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Remove this connection and its local event cache? Your meetings stay with the provider. Original files from the old setup are kept for rollback."; color: Colors.muted }
                    RowLayout {
                        UiButton { text: "Remove connection"; danger: true; enabled: !CalendarAccounts.busy; onClicked: { CalendarAccounts.request({op: "remove", id: account.modelData.id}); root.removeId = "" } }
                        UiButton { text: "Keep"; onClicked: root.removeId = "" }
                    }
                }
            }
        }
    }
    UiButton { text: root.adding ? "Back to accounts" : "Add account"; glyph: root.adding ? "\u{F060}" : "\u{F067}"; enabled: !CalendarAccounts.busy; onClicked: root.adding = !root.adding }
    ColumnLayout {
        visible: root.adding
        Layout.fillWidth: true; spacing: 12
        Flow {
            Layout.fillWidth: true; Layout.preferredHeight: childrenRect.height; spacing: 8
            Repeater {
                model: ["google", "microsoft", "ics"]
                UiButton { required property string modelData; text: root.providerName(modelData); selected: root.provider === modelData; enabled: !CalendarAccounts.busy; onClicked: { root.provider = modelData; root.setup = modelData !== "ics" && !CalendarAccounts.providers[modelData] } }
            }
        }
        CalendarField {
            id: email
            Layout.fillWidth: true; visible: root.provider !== "ics"
            placeholderText: root.provider === "microsoft" ? "Work email, for example name@example.com" : "Google or Google Workspace email"
            enabled: !CalendarAccounts.busy
            Accessible.name: "Calendar account email"
            onAccepted: if (text.trim() && CalendarAccounts.providers[root.provider] && !CalendarAccounts.busy) CalendarAccounts.request({op: "connect", provider: root.provider, email: text.trim()})
        }
        CalendarField { id: feedName; Layout.fillWidth: true; visible: root.provider === "ics"; placeholderText: "Calendar name"; Accessible.name: placeholderText; enabled: !CalendarAccounts.busy }
        CalendarField { id: feedUrl; Layout.fillWidth: true; visible: root.provider === "ics"; placeholderText: "Private https://… iCalendar URL"; Accessible.name: "Calendar subscription URL"; echoMode: TextInput.PasswordEchoOnEdit; enabled: !CalendarAccounts.busy }
        UiLabel {
            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Colors.muted
            text: root.provider === "microsoft" ? "EPAM may require administrator consent or an approved device. Station will show the actual Microsoft result. No work password is stored here."
                : root.provider === "google" ? "The configured Google app must allow this account. An Internal Workspace app only accepts accounts in that organization."
                : "Use a subscription link supplied by your calendar provider. Anyone with a private link can read that feed; it is stored only on this machine."
        }
        RowLayout {
            Layout.fillWidth: true
            UiButton {
                text: root.provider === "ics" ? "Add subscription" : "Continue in browser"
                enabled: !CalendarAccounts.busy && (root.provider === "ics" ? feedName.text.trim() !== "" && feedUrl.text.trim() !== "" : email.text.trim() !== "" && CalendarAccounts.providers[root.provider] === true)
                onClicked: {
                    if (root.provider === "ics") { CalendarAccounts.request({op: "feed", label: feedName.text.trim(), url: feedUrl.text.trim()}); feedUrl.text = "" }
                    else CalendarAccounts.request({op: "connect", provider: root.provider, email: email.text.trim()})
                }
            }
            UiButton { text: "App setup"; visible: root.provider !== "ics"; selected: root.setup; enabled: !CalendarAccounts.busy; onClicked: root.setup = !root.setup }
        }
        UiLabel {
            visible: root.provider !== "ics" && !CalendarAccounts.providers[root.provider]
            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Colors.yellow
            text: "One-time app setup is needed before browser sign-in."
        }
        ColumnLayout {
            visible: root.setup && root.provider !== "ics"
            Layout.fillWidth: true; spacing: 10
            UiLabel {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Colors.muted
                text: root.provider === "google" ? "Import the Desktop app JSON from your Google Cloud project with Calendar API enabled. This becomes the default for new accounts; existing connections keep their client."
                    : "Register an Entra app for your organization (or an approved multitenant app). Platform: Mobile and desktop. Redirect URI: http://localhost. Delegated permission: Calendars.ReadBasic. No client secret is needed."
            }
            UiButton { text: "Import Google client…"; visible: root.provider === "google"; enabled: !CalendarAccounts.busy; onClicked: { DesktopData.choosingFile = true; clientFile.open() } }
            CalendarField { id: clientId; Layout.fillWidth: true; visible: root.provider === "microsoft"; placeholderText: "Application (client) ID"; Accessible.name: placeholderText }
            CalendarField { id: tenant; Layout.fillWidth: true; visible: root.provider === "microsoft"; placeholderText: "Directory tenant ID or organizations"; text: "organizations"; Accessible.name: "Microsoft tenant" }
            UiButton { text: "Save Microsoft app"; visible: root.provider === "microsoft"; enabled: !CalendarAccounts.busy && clientId.text.trim() !== ""; onClicked: CalendarAccounts.request({op: "setup", provider: "microsoft", client_id: clientId.text.trim(), tenant: tenant.text.trim()}) }
            UiButton {
                text: "Open provider console"
                onClicked: Qt.openUrlExternally(root.provider === "google" ? "https://console.cloud.google.com/auth/clients" : "https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade")
            }
        }
    }
    FileDialog {
        id: clientFile
        title: "Choose Google OAuth Desktop app JSON"
        nameFilters: ["JSON files (*.json)"]
        onAccepted: {
            DesktopData.choosingFile = false
            CalendarAccounts.request({op: "setup", provider: "google", path: decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))})
        }
        onRejected: DesktopData.choosingFile = false
    }
}
