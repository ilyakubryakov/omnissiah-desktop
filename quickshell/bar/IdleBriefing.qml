pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

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

    readonly property var usageLevels: PanelBriefing.providers.map(p => {
        const data = PanelBriefing.provider(p.id)
        const limit = PanelBriefing.tightest(data)
        const stale = PanelBriefing.usageStale(data)
        const used = limit ? limit.usedPercent : -1
        return { used: used, stale: stale, level: used >= 95 ? 'bad' : used >= 80 ? 'warn' : stale || !limit ? 'stale' : 'ok' }
    })
    readonly property real usageMax: usageLevels.reduce((m, u) => Math.max(m, u.used), -1)
    readonly property string usageLevel: usageLevels.reduce((w, u) => rank(u.level) > rank(w) ? u.level : w, 'ok')

    function clusterLevel(data) {
        if (PanelBriefing.stale(data, 300)) return 'stale'
        return data.readyNodes < data.nodes ? 'bad' : data.issueCount > 0 ? 'warn' : 'ok'
    }
    readonly property var clusterLevels: PanelBriefing.targets.map(t => clusterLevel(PanelBriefing.cluster(t.id)))
    readonly property string clustersLevel: clusterLevels.reduce((w, l) => rank(l) > rank(w) ? l : w, 'ok')
    readonly property int clusterIssues: PanelBriefing.targets.reduce((n, t) => {
        const data = PanelBriefing.cluster(t.id)
        return n + (PanelBriefing.stale(data, 300) ? 0 : data.issueCount || 0)
    }, 0)

    onVisibleChanged: if (!visible) { aiPopup.dismiss(); clusterPopup.dismiss(); backupPopup.dismiss() }

    component Divider: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.selection }
    component CardHeader: RowLayout {
        property string glyph
        property string title
        property string note
        Layout.fillWidth: true; spacing: 10
        Text { text: parent.glyph; font.family: Colors.iconFont; font.pixelSize: 22; color: Colors.accent }
        UiLabel { text: parent.title; font.pixelSize: 18; Layout.fillWidth: true }
        UiLabel { text: parent.note; color: Colors.dim; font.pixelSize: 11 }
    }

    StatusChip {
        id: aiSeg
        meters: PanelBriefing.providers.map((p, i) => {
            const u = root.usageLevels[i]
            return { glyph: p.glyph, value: u.used >= 0 ? Math.round(u.used) + '%' : '--', fill: Math.max(0, u.used) / 100,
                color: u.level === 'ok' ? Colors.foreground : root.levelColor(u.level) }
        })
        Accessible.name: 'AI usage ' + meters.map((m, i) => PanelBriefing.providers[i].label + ' ' + m.value).join(', ')
        onClicked: aiPopup.togglePinned()
        BarPopup {
            id: aiPopup
            anchorItem: aiSeg; barWindow: root.barWindow; above: true; cardWidth: 420
            triggerHovered: root.visible && aiSeg.hovered
            CardHeader { glyph: '\u{F0674}'; title: 'AI usage'; note: 'Account limits · all devices' }
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
                        Text { text: usageBlock.modelData.glyph; font.family: Colors.iconFont; font.pixelSize: 17; color: Colors.foreground }
                        UiLabel { text: usageBlock.modelData.label; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        UiLabel {
                            text: usageBlock.usageData.error || (usageBlock.stale ? 'Waiting for fresh limits' : 'Checked ' + PanelBriefing.stamp(usageBlock.usageData))
                            color: usageBlock.stale ? Colors.yellow : Colors.dim; font.pixelSize: 11
                        }
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
                                    Layout.fillWidth: true; font.pixelSize: 13
                                    text: PanelBriefing.period(quotaRow.modelData.windowMinutes)
                                        + (['codex', 'All models'].includes(quotaRow.modelData.label) ? '' : ' · ' + quotaRow.modelData.label)
                                }
                                UiLabel { text: Math.round(quotaRow.modelData.usedPercent) + '% used'; color: quotaRow.meterColor; font.pixelSize: 13 }
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
                                Layout.fillWidth: true; font.pixelSize: 11; color: Colors.muted
                                text: Math.max(0, 100 - quotaRow.modelData.usedPercent).toFixed(0) + '% remaining · '
                                    + PanelBriefing.resetText(quotaRow.modelData)
                            }
                        }
                    }
                    UiLabel {
                        visible: !(usageBlock.usageData.windows || []).length && !usageBlock.usageData.error
                        text: 'No limits reported yet'; color: Colors.muted; font.pixelSize: 12
                    }
                    UiLabel { visible: (usageBlock.usageData.windows || []).length > 6; text: 'Additional limits available in the client'; font.pixelSize: 11; color: Colors.dim }
                }
            }
            UiLabel {
                Layout.fillWidth: true; font.pixelSize: 10; color: Colors.dim
                text: 'Bar shows the most-used quota · refreshed every 2 min while idle.\n'
                    + 'Codex: CLI sign-in, read-only App Server RPC · Claude: Code sign-in, usage endpoint; no AI requests'
                wrapMode: Text.Wrap
            }
        }
    }

    StatusChip {
        id: clusterSeg
        glyph: '\u{F10FE}'
        value: root.clusterIssues > 0 ? String(root.clusterIssues) : ''
        valueColor: root.levelColor(root.clustersLevel)
        dots: root.clusterLevels.map(l => root.dotColor(l))
        Accessible.name: 'Kubernetes ' + root.clustersLevel
        onClicked: clusterPopup.togglePinned()
        BarPopup {
            id: clusterPopup
            anchorItem: clusterSeg; barWindow: root.barWindow; above: true; cardWidth: 430
            triggerHovered: root.visible && clusterSeg.hovered
            CardHeader { glyph: '\u{F10FE}'; title: 'Kubernetes'; note: 'Read-only · every 2 min' }
            Repeater {
                model: PanelBriefing.targets
                ColumnLayout {
                    id: clusterBlock
                    required property var modelData
                    required property int index
                    readonly property var clusterData: PanelBriefing.cluster(modelData.id)
                    readonly property string level: root.clusterLevel(clusterData)
                    readonly property bool stale: level === 'stale'
                    Layout.fillWidth: true; spacing: 6
                    Divider { visible: clusterBlock.index > 0 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            implicitWidth: 8; implicitHeight: 8; radius: 4
                            color: clusterBlock.level === 'ok' ? Colors.green : root.levelColor(clusterBlock.level)
                        }
                        UiLabel { text: clusterBlock.modelData.label; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        UiLabel {
                            visible: !!clusterBlock.clusterData.updatedAt
                            text: 'Nodes ' + clusterBlock.clusterData.readyNodes + '/' + clusterBlock.clusterData.nodes
                                + ' · Pods ' + clusterBlock.clusterData.readyPods + '/' + clusterBlock.clusterData.pods
                            color: Colors.muted; font.pixelSize: 12
                        }
                    }
                    UiLabel {
                        Layout.fillWidth: true
                        text: clusterBlock.clusterData.error || (clusterBlock.stale ? 'Waiting for a fresh check' : clusterBlock.clusterData.issueCount ? 'Needs attention'
                            : clusterBlock.clusterData.readyPods < clusterBlock.clusterData.pods ? 'Pods starting or stopping' : 'Nodes and pods are ready')
                        color: clusterBlock.stale || clusterBlock.clusterData.issueCount ? Colors.yellow : Colors.green
                        font.pixelSize: 12
                    }
                    UiLabel {
                        visible: !!clusterBlock.clusterData.cordoned
                        text: 'Cordoned: ' + clusterBlock.clusterData.cordoned
                        color: Colors.muted; font.pixelSize: 12
                    }
                    Repeater {
                        model: (clusterBlock.clusterData.nodeIssues || []).concat(clusterBlock.clusterData.podIssues || []).slice(0, 5)
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true; spacing: 2
                            UiLabel { Layout.fillWidth: true; text: modelData.name; font.pixelSize: 12; maximumLineCount: 2; elide: Text.ElideRight }
                            UiLabel { text: modelData.reason; color: Colors.yellow; font.pixelSize: 11 }
                        }
                    }
                    UiLabel { visible: clusterBlock.clusterData.issueCount > 5; text: '+ ' + (clusterBlock.clusterData.issueCount - 5) + ' more'; color: Colors.muted; font.pixelSize: 12 }
                    UiLabel { text: 'Checked ' + PanelBriefing.stamp(clusterBlock.clusterData); color: Colors.dim; font.pixelSize: 11 }
                }
            }
            UiLabel { Layout.fillWidth: true; text: 'Completed jobs excluded; new pods have a 2 min grace period.'; color: Colors.dim; font.pixelSize: 10 }
        }
    }

    StatusChip {
        id: backupSeg
        visible: PanelBriefing.backupKnown
        readonly property var status: PanelBriefing.backup
        readonly property string level: PanelBriefing.backupLevel
        glyph: level === 'ok' ? '\u{F0160}' : '\u{F09E0}'
        value: PanelBriefing.backupFailed ? 'failed' : PanelBriefing.ago(PanelBriefing.backupAge)
        valueColor: level === 'bad' ? Colors.red : level === 'late' ? Colors.yellow : Colors.foreground
        badge: level === 'bad' ? Colors.red : level === 'late' ? Colors.yellow : 'transparent'
        Accessible.name: 'Backup ' + value
        onClicked: backupPopup.togglePinned()
        BarPopup {
            id: backupPopup
            anchorItem: backupSeg; barWindow: root.barWindow; above: true; cardWidth: 400
            triggerHovered: root.visible && backupSeg.hovered
            CardHeader { glyph: backupSeg.glyph; title: 'Laptop backup'; note: 'restic · homelab' }
            UiLabel {
                Layout.fillWidth: true
                text: PanelBriefing.backupFailed ? 'Last attempt failed · check laptop-backup in the system journal'
                    : backupSeg.level === 'bad' ? 'No successful backup for over 3 days'
                    : backupSeg.level === 'late' ? 'Older than a day · waiting for AC, unmetered network and homelab'
                    : 'Encrypted copy on the homelab is current'
                color: backupSeg.level === 'ok' ? Colors.green : backupSeg.level === 'late' ? Colors.yellow : Colors.red
                wrapMode: Text.Wrap
            }
            UiLabel {
                text: 'Last success  ' + PanelBriefing.when(backupSeg.status.lastSuccess)
                    + (backupSeg.status.lastFailure ? '\nLast failure  ' + PanelBriefing.when(backupSeg.status.lastFailure) : '')
                    + '\nRepository check  ' + PanelBriefing.when(backupSeg.status.lastCheck)
                color: Colors.muted; font.pixelSize: 13
            }
            UiLabel {
                visible: backupSeg.status.added !== undefined
                text: 'Snapshot ' + backupSeg.status.snapshot + ' · ' + (backupSeg.status.changed || 0) + ' new or changed files · '
                    + ((backupSeg.status.added || 0) / 1048576).toFixed(1) + ' MiB added'
                color: Colors.muted; font.pixelSize: 12
            }
            UiLabel { Layout.fillWidth: true; text: 'Hourly on AC power, unmetered network and a reachable homelab.\nKeeps 24 hourly, 14 daily, 8 weekly and 6 monthly versions.'; color: Colors.dim; font.pixelSize: 10 }
        }
    }
}
