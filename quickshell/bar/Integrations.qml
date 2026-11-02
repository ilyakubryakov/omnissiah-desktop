pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var settings: ({})
    readonly property var ai: Array.isArray(settings.ai) ? settings.ai : []
    readonly property var clusters: Array.isArray(settings.clusters) ? settings.clusters : []
    readonly property string prometheus: settings.prometheus || ""
    readonly property string telemetry: settings.telemetry || ""
    readonly property real latitude: settings.weather?.latitude || 0
    readonly property real longitude: settings.weather?.longitude || 0
    readonly property bool weather: Number.isFinite(settings.weather?.latitude) && Number.isFinite(settings.weather?.longitude)
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omnissiah/integrations.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.settings = JSON.parse(text()) } catch (_) { root.settings = ({}) } }
    }
}
