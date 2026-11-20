pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../shared" as Shared

// Idle bottom-left: one compact segment each for AI quotas and the station/laptop
// and homelab backups (Doctor and updates live in BarSystem; Kubernetes in BarMetrics). Hover cards expose coverage and freshness.
RowLayout {
    id: root
    required property var barWindow
    property real availableWidth: 1920
    implicitHeight: PanelStyle.barHeight
    spacing: 2
    Layout.fillHeight: true

    function rank(level) { return { bad: 3, warn: 2, stale: 1 }[level] || 0 }
    function dotColor(level) { return level === 'ok' ? Colors.green : levelColor(level) }
    function levelColor(level) {
        return level === 'bad' ? Colors.red : level === 'warn' ? Colors.yellow : level === 'stale' ? Colors.muted : Colors.foreground
    }

    readonly property var usageLevels: PanelBriefing.chipProviders.map(p => {
        const data = PanelBriefing.provider(p.id)
        const limit = PanelBriefing.tightest(data)
        const stale = PanelBriefing.usageStale(data)
        const used = limit ? limit.usedPercent : -1
        return { used: used, stale: stale, level: used >= 95 ? 'bad' : used >= 80 ? 'warn' : stale || !limit ? 'stale' : 'ok' }
    })
    readonly property real usageMax: usageLevels.reduce((m, u) => Math.max(m, u.used), -1)
    readonly property string usageLevel: usageLevels.reduce((w, u) => rank(u.level) > rank(w) ? u.level : w, 'ok')

    onVisibleChanged: if (!visible) { aiPopup.dismiss(); backupPopup.dismiss() }

    component Divider: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.selection }

    StatusChip {
        id: aiSeg
        meters: PanelBriefing.chipProviders.map((p, i) => {
            const u = root.usageLevels[i]
            return { glyph: p.glyph, value: u.used >= 0 ? Math.round(u.used) + '%' : '--', fill: Math.max(0, u.used) / 100,
                color: u.level === 'ok' ? Colors.foreground : root.levelColor(u.level) }
        })
        Accessible.name: 'AI usage ' + meters.map((m, i) => PanelBriefing.chipProviders[i].label + ' ' + m.value).join(', ')
        onClicked: aiPopup.togglePinned()
        BarPopup {
            id: aiPopup
            anchorItem: aiSeg; barWindow: root.barWindow; above: true; cardWidth: Shared.DesktopStyle.px(420)
            triggerHovered: root.visible && aiSeg.hovered
            CardHeader { glyph: '\u{F0674}'; title: 'AI usage'; note: 'Limits and local usage' }
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(aiContents.implicitHeight, (root.barWindow.screen ? root.barWindow.screen.height : 1080) * 0.65)
                contentHeight: aiContents.implicitHeight; contentWidth: width
                clip: true; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { }
                ColumnLayout {
                    id: aiContents
                    width: parent.width; spacing: 12
            Repeater {
                model: PanelBriefing.providers
                ColumnLayout {
                    id: usageBlock
                    required property var modelData
                    required property int index
                    readonly property var usageData: PanelBriefing.provider(modelData.id)
                    readonly property bool stale: PanelBriefing.usageStale(usageData)
                    Layout.fillWidth: true; spacing: 8
                    Divider { visible: usageBlock.index > 0 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: usageBlock.modelData.glyph; font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(17); color: Colors.foreground }
                        UiLabel { text: usageBlock.modelData.label; font.pixelSize: Shared.DesktopStyle.px(15); font.weight: Font.DemiBold; Layout.fillWidth: true }
                        UiLabel {
                            text: usageBlock.usageData.error || (usageBlock.stale ? 'Waiting for fresh limits' : 'Checked ' + PanelBriefing.stamp(usageBlock.usageData))
                            color: usageBlock.stale ? Colors.yellow : Colors.dim; font.pixelSize: Shared.DesktopStyle.px(11)
                        }
                    }
                    UiButton {
                        text: "Open agent"
                        onClicked: DesktopData.act("agent-launch", [usageBlock.modelData.id])
                    }
                    UiLabel {
                        visible: !!usageBlock.usageData.note
                        text: usageBlock.usageData.note || ""
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11)
                    }
                    UiLabel {
                        visible: !!usageBlock.usageData.tokens
                        text: {
                            const t = usageBlock.usageData.tokens || ({})
                            return "Tokens · input " + (t.input || 0).toLocaleString() + " · output " + (t.output || 0).toLocaleString() + " · cache " + (t.cacheRead || 0).toLocaleString()
                        }
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: Shared.DesktopStyle.px(11)
                    }
                    Repeater {
                        model: (usageBlock.usageData.windows || []).slice(0, 6)
                        ColumnLayout {
                            id: quotaRow
                            required property var modelData
                            Layout.fillWidth: true; spacing: 4
                            readonly property color meterColor: usageBlock.stale ? Colors.dim : modelData.usedPercent >= 95 ? Colors.red
                                : modelData.usedPercent >= 80 ? Colors.yellow : Colors.accent
                            RowLayout {
                                Layout.fillWidth: true
                                UiLabel {
                                    Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(13)
                                    text: PanelBriefing.period(quotaRow.modelData.windowMinutes)
                                        + (['codex', 'All models'].includes(quotaRow.modelData.label) ? '' : ' · ' + quotaRow.modelData.label)
                                }
                                UiLabel { text: Math.round(quotaRow.modelData.usedPercent) + '% used'; color: quotaRow.meterColor; font.pixelSize: Shared.DesktopStyle.px(13) }
                            }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 5; radius: 2.5; color: Colors.selection
                                Rectangle {
                                    height: parent.height; radius: parent.radius
                                    width: parent.width * Math.max(0, Math.min(1, quotaRow.modelData.usedPercent / 100))
                                    color: quotaRow.meterColor
                                    Behavior on width { NumberAnimation { duration: Shared.DesktopStyle.normal } }
                                }
                            }
                            UiLabel {
                                Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(11); color: Colors.muted
                                text: Math.max(0, 100 - quotaRow.modelData.usedPercent).toFixed(0) + '% remaining · '
                                    + PanelBriefing.resetText(quotaRow.modelData)
                            }
                        }
                    }
                    UiLabel {
                        visible: !(usageBlock.usageData.windows || []).length && !usageBlock.usageData.error && !usageBlock.usageData.note
                        text: 'No limits reported yet'; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12)
                    }
                    UiLabel { visible: (usageBlock.usageData.windows || []).length > 6; text: 'Additional limits available in the client'; font.pixelSize: Shared.DesktopStyle.px(11); color: Colors.dim }
                }
            }
                }
            }
            UiLabel {
                Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(10); color: Colors.dim
                text: 'Bar shows the most-used quota · refreshed every 2 min while idle.\n'
                    + 'Codex: CLI sign-in, read-only App Server RPC · Claude: Code sign-in, usage endpoint; no AI requests'
                wrapMode: Text.Wrap
            }
        }
    }

    StatusChip {
        id: backupSeg
        visible: PanelBriefing.backupKnown
        readonly property string level: PanelBriefing.backupLevel
        glyph: level === 'ok' ? '\u{F0160}' : '\u{F09E0}'
        value: PanelBriefing.backupFailed ? 'failed' : PanelBriefing.backupPartial ? 'skipped' : PanelBriefing.backupUnknown ? '?' : PanelBriefing.ago(PanelBriefing.backupAge)
        valueColor: level === 'bad' ? Colors.red : level === 'late' ? Colors.yellow : Colors.foreground
        badge: level === 'bad' ? Colors.red : level === 'late' ? Colors.yellow : 'transparent'
        Accessible.name: 'Backup ' + value
        onClicked: backupPopup.togglePinned()
        BarPopup {
            id: backupPopup
            anchorItem: backupSeg; barWindow: root.barWindow; above: true; cardWidth: Shared.DesktopStyle.px(470)
            triggerHovered: root.visible && backupSeg.hovered
            CardHeader { glyph: backupSeg.glyph; title: 'Backups'; note: 'Local · Homelab' }
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(backupContents.implicitHeight, (root.barWindow.screen ? root.barWindow.screen.height : 1080) * 0.65)
                contentHeight: backupContents.implicitHeight; contentWidth: width
                clip: true; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { }
                ColumnLayout {
                    id: backupContents
                    width: parent.width; spacing: 12
            Repeater {
                model: PanelBriefing.backupRows
                ColumnLayout {
                    required property var modelData
                    readonly property string rowLevel: PanelBriefing.backupRowLevel(modelData)
                    Layout.fillWidth: true; spacing: 5
                    RowLayout {
                        Layout.fillWidth: true
                        UiLabel { text: modelData.source + ' / ' + modelData.label; font.pixelSize: Shared.DesktopStyle.px(13); font.weight: Font.DemiBold; Layout.fillWidth: true }
                        UiLabel { text: modelData.stale ? 'stale' : rowLevel === 'unknown' ? 'unknown' : modelData.result === 'partial' ? 'skipped' : rowLevel === 'bad' && modelData.result === 'ok' ? 'overdue' : modelData.result
                            color: rowLevel === 'bad' ? Colors.red : rowLevel === 'ok' ? Colors.green : Colors.yellow; font.pixelSize: Shared.DesktopStyle.px(12) }
                    }
                    UiLabel { text: 'Last complete backup  ' + (modelData.lastSuccess ? PanelBriefing.when(modelData.lastSuccess) : 'unknown')
                        + (modelData.lastSuccess ? ' · ' + PanelBriefing.ago(Math.max(0, PanelBriefing.clock - modelData.lastSuccess)) + ' ago' : '')
                        color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11); Layout.fillWidth: true; wrapMode: Text.Wrap }
                    UiLabel { visible: modelData.running === true; text: 'Backup in progress'; color: Colors.yellow; font.pixelSize: Shared.DesktopStyle.px(11) }
                    UiLabel { visible: modelData.id === 'laptop'; text: 'Repository check  ' + (modelData.lastCheck ? PanelBriefing.when(modelData.lastCheck) : 'unknown'); color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(11) }
                    UiLabel { visible: !!modelData.snapshot; text: 'Snapshot ' + (modelData.snapshot || '')
                        + (modelData.changed !== undefined ? ' · ' + modelData.changed + ' changed files' : '')
                        + (modelData.added !== undefined ? ' · ' + (modelData.added / 1048576).toFixed(1) + ' MiB added' : '')
                        color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(11); Layout.fillWidth: true; wrapMode: Text.Wrap }
                    UiLabel {
                        visible: !!modelData.sites
                        text: Object.entries(modelData.sites || {}).map(([site, timestamp]) => site + ' ' + (timestamp ? PanelBriefing.ago(Math.max(0, PanelBriefing.clock - timestamp)) + ' ago' : 'unknown')).join(' · ')
                        color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(11); Layout.fillWidth: true; wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: Object.entries(modelData.guests || {})
                        UiLabel {
                            required property var modelData
                            Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: Shared.DesktopStyle.px(12)
                            text: modelData[1].status + ': ' + modelData[0] + ' · last backup ' + (modelData[1].lastSuccess
                                ? PanelBriefing.ago(Math.max(0, PanelBriefing.clock - modelData[1].lastSuccess)) + ' ago' : 'unknown')
                            color: modelData[1].status === 'skipped' ? Colors.yellow : Colors.muted
                        }
                    }
                    UiLabel { visible: modelData.id === 'homelab'; text: (modelData.count !== undefined && modelData.count !== null ? modelData.count + ' snapshots' : 'Snapshot count unknown')
                        + ' · ' + (modelData.sizeBytes !== undefined && modelData.sizeBytes !== null ? (modelData.sizeBytes / 1e9).toFixed(1) + ' GB' : 'size unknown'); color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(11) }
                    UiLabel { visible: !!modelData.note || !!modelData.error; text: modelData.error || modelData.note || ''; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(10); Layout.fillWidth: true; wrapMode: Text.Wrap }
                    UiLabel { visible: !!modelData.metricsAt; text: 'Metrics collected  ' + PanelBriefing.when(modelData.metricsAt); color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(10) }
                    Item { implicitHeight: 8 }
                }
            }
                }
            }
            UiLabel { visible: PanelBriefing.backupRows.some(row => row.id === 'vms'); Layout.fillWidth: true; text: 'VMs: daily at 00:30, stopped guests only. Running guests are never stopped automatically.'; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(10); wrapMode: Text.Wrap }
        }
    }
}
