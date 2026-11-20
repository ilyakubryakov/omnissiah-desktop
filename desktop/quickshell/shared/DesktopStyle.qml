pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "UiMetricsDefaults.js" as MetricDefaults

Singleton {
    id: root
    property var preferences: ({})
    readonly property bool comfortable: preferences.density === "comfortable"
    property var metrics: MetricDefaults.values
    readonly property bool unified: metrics.unified === true
    readonly property string fontFamily: metrics.font_family
    readonly property int fontSize: metrics.text_px
    readonly property int buttonFontSize: metrics.button_text_px
    readonly property int comboFontSize: metrics.combo_text_px
    // Scales a size designed for the default 11 pt text (text_px 15), so every
    // card follows the chosen UI font size; default metrics return n unchanged.
    function px(n) { return Math.max(1, Math.round(n * metrics.text_px / 15)) }
    readonly property int controlHeight: comfortable ? metrics.control_height_comfortable : metrics.control_height
    readonly property int focusWidth: metrics.focus_width
    readonly property int spaceUnit: metrics.space_unit
    readonly property int controlPadding: metrics.padding_x
    readonly property int cardPadding: metrics.card_padding
    readonly property int cardSpacing: metrics.card_spacing
    property bool fullscreen: false
    readonly property bool motion: ["subtle", "smooth"].includes(preferences.motion) && !fullscreen
    // Shared proportions and motion for every shell layout.
    readonly property int radiusSmall: metrics.radius_small
    readonly property int radiusControl: metrics.radius_control
    readonly property int radiusCard: metrics.radius_card
    readonly property int radiusPanel: metrics.radius_panel
    readonly property int spacing: spaceUnit * (comfortable ? 4 : 3)
    readonly property bool smooth: preferences.motion === "smooth"
    readonly property int fast: motion ? (smooth ? 160 : 120) : 0
    readonly property int normal: motion ? (smooth ? 300 : 220) : 0
    readonly property int slow: motion ? (smooth ? 400 : 320) : 0
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/theme/ui-metrics.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.metrics = Object.assign({}, MetricDefaults.values, JSON.parse(text())) }
            catch (_) { root.metrics = MetricDefaults.values }
        }
        onLoadFailed: root.metrics = MetricDefaults.values
    }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/theme/desktop.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const next = {}
            for (const line of text().split("\n")) {
                const pair = line.split("=")
                if (pair.length === 2) next[pair[0]] = pair[1]
            }
            root.preferences = next
        }
        onLoadFailed: root.preferences = ({})
    }
}
