pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

    readonly property var usageLevels: PanelBriefing.chipProviders.map(p => {
        const data = PanelBriefing.provider(p.id)
        const limit = PanelBriefing.tightest(data)
        const stale = PanelBriefing.usageStale(data)
        const used = limit ? limit.usedPercent : -1
        return { used: used, stale: stale, level: used >= 95 ? 'bad' : used >= 80 ? 'warn' : stale || !limit ? 'stale' : 'ok' }
    })
    readonly property real usageMax: usageLevels.reduce((m, u) => Math.max(m, u.used), -1)
    readonly property string usageLevel: usageLevels.reduce((w, u) => rank(u.level) > rank(w) ? u.level : w, 'ok')

    onVisibleChanged: if (!visible) aiPopup.dismiss()

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

}
