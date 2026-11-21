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
    spacing: Shared.DesktopStyle.px(20)
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
    SettingsGroup {
        title: root.adding ? "Connect a calendar account" : "Your calendars"
        footer: "Google and Microsoft sign-in opens in your browser. OniNix reads calendars; it cannot create, change or delete meetings."
        SettingsRow {
            title: root.adding ? "Choose a provider below" : "One agenda, all your accounts"
            subtitle: CalendarAccounts.busy && CalendarAccounts.authUrl === "" ? (CalendarAccounts.signingIn ? "Preparing secure sign-in…" : "Updating calendars…") : ""
            UiButton { text: "Sync now"; glyph: "\u{F021}"; visible: !root.adding; enabled: !CalendarAccounts.busy; onClicked: CalendarAccounts.request({op: "sync"}) }
            UiButton { text: root.adding ? "Back to accounts" : "Add account"; glyph: root.adding ? "\u{F060}" : "\u{F067}"; enabled: !CalendarAccounts.busy; onClicked: root.adding = !root.adding }
        }
        SettingsRow {
            visible: CalendarAccounts.error !== "" || CalendarAccounts.message !== ""
            stacked: true
            UiLabel {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                color: CalendarAccounts.error ? Colors.red : Colors.accent
                text: CalendarAccounts.error || CalendarAccounts.message
            }
        }
        SettingsRow {
            visible: CalendarAccounts.signingIn
            title: "Sign-in in progress"
            UiButton { text: "Open sign-in again"; enabled: CalendarAccounts.authUrl !== ""; onClicked: Qt.openUrlExternally(CalendarAccounts.authUrl) }
            UiButton { text: "Cancel sign-in"; onClicked: CalendarAccounts.cancel() }
        }
    }
    Repeater {
        model: root.adding ? [] : CalendarAccounts.accounts
        SettingsGroup {
            id: account
            required property var modelData
            title: account.modelData.email || account.modelData.label
            SettingsRow {
                title: root.providerName(account.modelData.provider) + (account.modelData.enabled ? "" : " · Paused")
                subtitle: account.modelData.error ? account.modelData.error.message : ""
                UiButton {
                    text: account.modelData.enabled ? "Pause" : "Resume"
                    enabled: !CalendarAccounts.busy
                    onClicked: CalendarAccounts.request({op: "enable", id: account.modelData.id, enabled: !account.modelData.enabled})
                }
            }
            Repeater {
                model: account.modelData.calendars
                SettingsRow {
                    id: calendar
                    required property var modelData
                    title: modelData.name
                    subtitle: account.modelData.enabled ? root.syncText(calendar.modelData) : "Paused · saved settings"
                    UiButton {
                        text: calendar.modelData.selected ? "Shown" : "Show"
                        glyph: calendar.modelData.selected ? "\u{F00C}" : "\u{F067}"
                        selected: calendar.modelData.selected
                        Accessible.name: (calendar.modelData.selected ? "Hide " : "Show ") + calendar.modelData.name
                        enabled: !CalendarAccounts.busy && account.modelData.enabled
                        onClicked: CalendarAccounts.select(account.modelData, calendar.modelData.id, !calendar.modelData.selected)
                    }
                }
            }
            SettingsRow { visible: account.modelData.calendars.length === 0; title: "No calendars loaded yet"; subtitle: "Refresh after signing in." }
            SettingsRow {
                title: "Connection"
                UiButton { text: "Refresh list"; visible: account.modelData.provider !== "ics"; enabled: !CalendarAccounts.busy; onClicked: CalendarAccounts.request({op: "discover", id: account.modelData.id}) }
                UiButton { text: "Sign in again"; visible: account.modelData.provider !== "ics"; enabled: !CalendarAccounts.busy; onClicked: CalendarAccounts.request({op: "connect", id: account.modelData.id}) }
                UiButton { text: "Remove"; danger: true; enabled: !CalendarAccounts.busy; onClicked: root.removeId = account.modelData.id }
            }
            SettingsRow {
                visible: root.removeId === account.modelData.id
                title: "Remove this connection and its local event cache?"
                subtitle: "Your meetings stay with the provider. Original files from the old setup are kept for rollback."
                UiButton { text: "Remove connection"; danger: true; enabled: !CalendarAccounts.busy; onClicked: { CalendarAccounts.request({op: "remove", id: account.modelData.id}); root.removeId = "" } }
                UiButton { text: "Keep"; onClicked: root.removeId = "" }
            }
        }
    }
    SettingsGroup {
        visible: root.adding
        title: "New account"
        footer: root.provider === "microsoft" ? "Your organization may require administrator consent or an approved device."
            : root.provider === "google" ? "The configured Google app must allow this account. An Internal Workspace app only accepts accounts in that organization."
            : "Use a subscription link supplied by your calendar provider. Anyone with a private link can read that feed; it is stored only on this machine."
        SettingsRow {
            title: "Provider"
            Segmented {
                model: ["google", "microsoft", "ics"].map(id => ({id: id, title: root.providerName(id)}))
                current: root.provider
                enabled: !CalendarAccounts.busy
                onChosen: id => { root.provider = id; root.setup = id !== "ics" && !CalendarAccounts.providers[id] }
            }
        }
        SettingsRow {
            visible: root.provider !== "ics"
            title: "Email"
            subtitle: !CalendarAccounts.providers[root.provider] ? "One-time app setup is needed before browser sign-in." : ""
            CalendarField {
                id: email
                Layout.preferredWidth: Shared.DesktopStyle.px(320)
                placeholderText: root.provider === "microsoft" ? "Work or school email" : "Google or Google Workspace email"
                enabled: !CalendarAccounts.busy
                Accessible.name: "Calendar account email"
                onAccepted: if (text.trim() && CalendarAccounts.providers[root.provider] && !CalendarAccounts.busy) CalendarAccounts.request({op: "connect", provider: root.provider, email: text.trim()})
            }
        }
        SettingsRow {
            visible: root.provider === "ics"
            title: "Name"
            CalendarField { id: feedName; Layout.preferredWidth: Shared.DesktopStyle.px(320); placeholderText: "Calendar name"; Accessible.name: placeholderText; enabled: !CalendarAccounts.busy }
        }
        SettingsRow {
            visible: root.provider === "ics"
            title: "Address"
            CalendarField { id: feedUrl; Layout.preferredWidth: Shared.DesktopStyle.px(320); placeholderText: "Private https://… iCalendar URL"; Accessible.name: "Calendar subscription URL"; echoMode: TextInput.PasswordEchoOnEdit; enabled: !CalendarAccounts.busy }
        }
        SettingsRow {
            title: root.provider === "ics" ? "Subscribe" : "Sign in"
            UiButton { text: "App setup"; visible: root.provider !== "ics"; selected: root.setup; enabled: !CalendarAccounts.busy; onClicked: root.setup = !root.setup }
            UiButton {
                text: root.provider === "ics" ? "Add subscription" : "Continue in browser"
                selected: true
                enabled: !CalendarAccounts.busy && (root.provider === "ics" ? feedName.text.trim() !== "" && feedUrl.text.trim() !== "" : email.text.trim() !== "" && CalendarAccounts.providers[root.provider] === true)
                onClicked: {
                    if (root.provider === "ics") { CalendarAccounts.request({op: "feed", label: feedName.text.trim(), url: feedUrl.text.trim()}); feedUrl.text = "" }
                    else CalendarAccounts.request({op: "connect", provider: root.provider, email: email.text.trim()})
                }
            }
        }
    }
    SettingsGroup {
        visible: root.adding && root.setup && root.provider !== "ics"
        title: "App setup"
        footer: root.provider === "google" ? "Import the Desktop app JSON from your Google Cloud project with Calendar API enabled. This becomes the default for new accounts; existing connections keep their client."
            : "Register an Entra app for your organization (or an approved multitenant app). Platform: Mobile and desktop. Redirect URI: http://localhost. Delegated permission: Calendars.ReadBasic. No client secret is needed."
        SettingsRow {
            visible: root.provider === "google"
            title: "Google client"
            UiButton { text: "Import Google client…"; enabled: !CalendarAccounts.busy; onClicked: { DesktopData.choosingFile = true; clientFile.open() } }
        }
        SettingsRow {
            visible: root.provider === "microsoft"
            title: "Application (client) ID"
            CalendarField { id: clientId; Layout.preferredWidth: Shared.DesktopStyle.px(320); placeholderText: "Application (client) ID"; Accessible.name: placeholderText }
        }
        SettingsRow {
            visible: root.provider === "microsoft"
            title: "Tenant"
            CalendarField { id: tenant; Layout.preferredWidth: Shared.DesktopStyle.px(320); placeholderText: "Directory tenant ID or organizations"; text: "organizations"; Accessible.name: "Microsoft tenant" }
        }
        SettingsRow {
            title: "Provider console"
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
