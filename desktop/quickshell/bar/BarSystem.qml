pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

// Bottom-left system cluster, always visible regardless of the media/briefing
// view: Station Doctor, update availability and the system management agent.
RowLayout {
    id: root
    required property var barWindow
    implicitHeight: PanelStyle.barHeight
    spacing: 2
    Layout.fillHeight: true

    component Divider: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.selection }

    // Station Doctor, in the voice of the Adeptus Mechanicus: heart-cog when
    // the machine spirit is appeased, hammer-wrench when a Tech-Priest is
    // needed, skull-crossbones when the rite of exorcism is due, skull-scan
    // when the auguries are stale. Data comes from the oninix-doctor cache.
    StatusChip {
        id: doctorSeg
        visible: DoctorData.known
        readonly property string level: DoctorData.level
        readonly property var spirit: ({
            ok: { glyph: '\u{F1663}', mood: 'The Machine Spirit is appeased',
                  litany: 'All rites of maintenance are observed. Praise the Omnissiah.' },
            warn: { glyph: '\u{F1322}', mood: 'The Machine Spirit is restless',
                    litany: 'A Tech-Priest must attend. Apply the sacred unguents and chant the litany of repair.' },
            fail: { glyph: '\u{F0BC6}', mood: 'The Machine Spirit is wrathful',
                    litany: 'Summon the Adeptus Mechanicus. Begin the Rite of Exorcism before the cogitators fall silent.' },
            stale: { glyph: '\u{F14C7}', mood: 'The auguries have fallen silent',
                     litany: 'No rite of inspection for 45 minutes. Run the full check to wake the auspex.' }
        })[level] || ({ glyph: '\u{F14C7}', mood: 'The auguries are unread', litany: '' })
        readonly property color tone: level === 'fail' ? Colors.red : level === 'warn' ? Colors.yellow : level === 'ok' ? Colors.green : Colors.muted
        glyph: spirit.glyph
        value: level === 'stale' ? '?' : DoctorData.issues.length > 0 ? String(DoctorData.issues.length) : ''
        valueColor: tone
        badge: level === 'fail' || level === 'warn' ? tone : 'transparent'
        Accessible.name: 'Station Doctor ' + (DoctorData.issues.length ? DoctorData.issues.length + ' issues' : level)
        onClicked: doctorPopup.togglePinned()
        BarPopup {
            id: doctorPopup
            anchorItem: doctorSeg; barWindow: root.barWindow; above: true; cardWidth: Shared.DesktopStyle.px(fixBox.visible ? 540 : 460)
            triggerHovered: doctorSeg.hovered
            CardHeader {
                glyph: doctorSeg.glyph; title: 'Station Doctor'
                note: DoctorData.known ? 'Checked ' + DoctorData.ago(DoctorData.clock - DoctorData.report.checked) : ''
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Text {
                    Layout.alignment: Qt.AlignTop
                    text: doctorSeg.spirit.glyph; color: doctorSeg.tone
                    font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(30)
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    UiLabel {
                        Layout.fillWidth: true; text: doctorSeg.spirit.mood; color: doctorSeg.tone
                        font.pixelSize: Shared.DesktopStyle.px(14); font.weight: Font.DemiBold
                    }
                    UiLabel {
                        Layout.fillWidth: true; visible: text !== ''; text: doctorSeg.spirit.litany
                        wrapMode: Text.Wrap; color: Colors.muted; font.italic: true; font.pixelSize: Shared.DesktopStyle.px(12)
                    }
                }
            }
            Repeater {
                model: DoctorData.rows
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 10
                    Rectangle {
                        Layout.alignment: Qt.AlignTop; Layout.topMargin: 6
                        width: 8; height: 8; radius: 4
                        color: modelData.level === 'fail' ? Colors.red : modelData.level === 'warn' ? Colors.yellow : Colors.green
                    }
                    UiLabel { text: modelData.check; font.pixelSize: Shared.DesktopStyle.px(13); font.weight: Font.DemiBold; Layout.preferredWidth: 84; Layout.alignment: Qt.AlignTop }
                    UiLabel {
                        text: modelData.message; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: Shared.DesktopStyle.px(12)
                        color: modelData.level === 'ok' ? Colors.muted : Colors.foreground
                    }
                }
            }
            Divider { visible: !!DoctorData.rebuild }
            ColumnLayout {
                visible: !!DoctorData.rebuild
                Layout.fillWidth: true; spacing: 4
                readonly property var info: DoctorData.rebuild || ({})
                UiLabel {
                    text: 'Last switch  ' + (parent.info.at ? DoctorData.ago(DoctorData.clock - Date.parse(parent.info.at) / 1000) : 'unknown')
                        + ' · ' + (parent.info.count || 0) + ' package changes'
                    font.pixelSize: Shared.DesktopStyle.px(13); font.weight: Font.DemiBold; Layout.fillWidth: true
                }
                Repeater {
                    model: (parent.info.changes || []).slice(0, 8)
                    UiLabel {
                        required property var modelData
                        Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: Shared.DesktopStyle.px(11)
                        text: modelData.name + '  ' + modelData.detail + (modelData.kind === 'updated' ? '' : '  (' + modelData.kind + ')')
                        color: modelData.kind === 'downgraded' || modelData.kind === 'removed' ? Colors.yellow : Colors.muted
                    }
                }
                UiLabel {
                    visible: (parent.info.count || 0) > 8
                    text: '+ ' + ((parent.info.count || 0) - 8) + ' more in /var/lib/oninix/last-rebuild.txt'
                    color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(10); Layout.fillWidth: true
                }
            }
            Divider { visible: DoctorData.events.length > 0 }
            ColumnLayout {
                id: timeline
                property bool expanded: false
                visible: DoctorData.events.length > 0
                Layout.fillWidth: true; spacing: 3
                function clock(at) { return new Date(at * 1000).toLocaleTimeString(Qt.locale(), 'HH:mm') }
                RowLayout {
                    Layout.fillWidth: true
                    UiLabel { text: 'Last 24 hours'; font.pixelSize: Shared.DesktopStyle.px(13); font.weight: Font.DemiBold; Layout.fillWidth: true }
                    UiButton {
                        visible: DoctorData.events.length > 6; subtle: true
                        text: timeline.expanded ? 'Less' : 'All ' + DoctorData.events.length
                        onClicked: timeline.expanded = !timeline.expanded
                    }
                }
                Repeater {
                    model: timeline.expanded ? DoctorData.events : DoctorData.events.slice(0, 6)
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(8)
                        UiLabel { text: timeline.clock(modelData.at); color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(11); font.features: { "tnum": 1 } }
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Shared.DesktopStyle.px(6); implicitHeight: implicitWidth; radius: implicitWidth / 2
                            color: modelData.level === 'fail' ? Colors.red : modelData.level === 'warn' ? Colors.yellow : modelData.level === 'ok' ? Colors.green : Colors.muted
                        }
                        UiLabel {
                            Layout.fillWidth: true; elide: Text.ElideRight; text: modelData.text; font.pixelSize: Shared.DesktopStyle.px(12)
                            color: modelData.level === 'fail' || modelData.level === 'warn' ? Colors.foreground : Colors.muted
                        }
                    }
                }
            }
            // Fix it: a headless agent diagnoses read-only, the owner reads the
            // resolution here and presses Fix; the same session then applies it
            // with every permission (sudo through a password dialog).
            Divider { visible: fixBox.visible }
            ColumnLayout {
                id: fixBox
                readonly property string status: DoctorData.fixStatus
                readonly property string answer: status === 'done' || (status === 'failed' && DoctorData.fix.result)
                    ? (DoctorData.fix.result || '') : (DoctorData.fix.resolution || '')
                readonly property string agentLabel: DoctorData.fix.agent === 'codex' ? 'Codex' : 'Claude'
                visible: DoctorData.issues.length > 0 || status !== 'idle'
                Layout.fillWidth: true; spacing: 6
                UiLabel {
                    Layout.fillWidth: true
                    visible: fixBox.status !== 'idle'
                    font.pixelSize: Shared.DesktopStyle.px(13); font.weight: Font.DemiBold
                    color: fixBox.status === 'failed' ? Colors.red : fixBox.status === 'done' ? Colors.green : Colors.foreground
                    text: ({
                        diagnosing: fixBox.agentLabel + ' is studying the issues…',
                        proposed: 'Proposed resolution',
                        fixing: fixBox.agentLabel + ' is applying the fix…',
                        done: 'Fix finished',
                        failed: 'Fix failed'
                    })[fixBox.status] || ''
                }
                ScrollView {
                    id: fixScroll
                    visible: fixBox.answer !== '' && fixBox.status !== 'diagnosing'
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(fixAnswer.implicitHeight + Shared.DesktopStyle.px(4), Shared.DesktopStyle.px(340))
                    contentWidth: availableWidth
                    clip: true
                    VikaAnswer { id: fixAnswer; width: fixScroll.availableWidth; markdown: fixBox.answer }
                }
                UiLabel {
                    Layout.fillWidth: true; visible: DoctorData.fixError !== ''
                    text: DoctorData.fixError; color: Colors.red; font.pixelSize: Shared.DesktopStyle.px(11)
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    UiButton {
                        visible: !DoctorData.fixBusy && fixBox.status !== 'proposed' && DoctorData.issues.length > 0
                        text: 'Fix it'; glyph: '\u{F1322}'
                        onClicked: DoctorData.fixRun('diagnose')
                    }
                    UiButton {
                        visible: fixBox.status === 'proposed' && !DoctorData.fixBusy
                        text: 'Fix'; glyph: '\u{F012C}'; danger: true
                        onClicked: DoctorData.fixRun('fix')
                    }
                    UiButton {
                        visible: fixBox.status === 'diagnosing' || fixBox.status === 'fixing'
                        text: 'Stop'; glyph: '\u{F04DB}'; subtle: true
                        onClicked: DoctorData.fixRun('stop')
                    }
                    UiButton {
                        visible: !DoctorData.fixBusy && fixBox.status !== 'idle'
                        text: 'Dismiss'; subtle: true
                        onClicked: DoctorData.fixRun('dismiss')
                    }
                    UiLabel {
                        Layout.fillWidth: true; wrapMode: Text.Wrap; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(10)
                        text: fixBox.status === 'proposed' ? 'Fix runs this plan with all permissions; sudo asks for the password in a dialog.'
                            : DoctorData.fixBusy ? 'Runs in the background; a notification arrives when it is done.'
                            : 'The agent diagnoses read-only and proposes a resolution first.'
                    }
                }
            }
            Divider {}
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                UiButton {
                    text: DoctorData.running ? 'Communing with the machine spirit…' : 'Run full check'
                    glyph: '\u{F1663}'
                    enabled: !DoctorData.running
                    onClicked: DoctorData.runFull()
                }
                UiLabel {
                    Layout.fillWidth: true; wrapMode: Text.Wrap; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(10)
                    text: 'Read-only. Every 15 min; the theme check and a notification run daily at 10:00. Terminal: oninix-doctor'
                }
            }
        }
    }

    // Updates (owner decision 2026-11-08): no count, so waiting updates do not
    // pull attention; the glyph turns urgent red only when it is time to
    // update, the warning badge shows when the last check failed or a source
    // has not answered for three days. The count stays in the card.
    StatusChip {
        id: updatesSeg
        readonly property var updates: Shared.UpdatesData
        readonly property string level: updates.level
        glyph: '\u{F06B0}'
        value: level === 'stale' ? '?' : level === 'checking' ? '…' : ''
        valueColor: Colors.muted
        tint: level === 'due' ? Colors.statusUrgent : 'transparent'
        badge: level === 'error' || (updates.unreachable || []).length ? Colors.statusWarning : 'transparent'
        Accessible.name: 'System updates ' + updates.summary
        onClicked: updatesPopup.togglePinned()
        BarPopup {
            id: updatesPopup
            anchorItem: updatesSeg; barWindow: root.barWindow; above: true; cardWidth: Shared.DesktopStyle.px(500)
            triggerHovered: updatesSeg.hovered
            UpdatesCard { Layout.fillWidth: true; maxHeight: (root.barWindow.screen ? root.barWindow.screen.height : 1080) * 0.6 }
        }
    }

    StatusChip {
        id: managementSeg
        glyph: '\u{F0493}'
        Accessible.name: 'System management'
        onClicked: DesktopData.act('system-agent')
        BarToolTip {
            target: managementSeg; shown: managementSeg.hovered
            text: 'System management\nOpen an agent in the personal configuration repository.\nChoose Claude, Codex or OpenCode in Appearance > Panels.'
        }
    }

    Rectangle {
        Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 6; Layout.rightMargin: 6
        implicitWidth: 1; implicitHeight: 12; color: Colors.dim
    }
}
