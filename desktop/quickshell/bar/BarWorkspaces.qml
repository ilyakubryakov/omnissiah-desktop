import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../shared" as Shared
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

BarGroup {
    required property var bar
    property real budget: Shared.DesktopStyle.px(600)

        id: workspaceGroup
        group: "workspaces"
        Flickable {
            implicitWidth: Math.min(workspaceRow.implicitWidth, Math.max(Shared.DesktopStyle.px(40), budget - Shared.DesktopStyle.px(24)))
            Layout.fillHeight: true
            clip: true
            contentWidth: workspaceRow.implicitWidth
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
            RowLayout {
                id: workspaceRow
        height: parent.height
        spacing: 0

        Repeater {
            model: Hyprland.workspaces.values.filter(w => w.id > 0
                && (!w.monitor || w.monitor.name === bar.modelData.name))

            Item {
                id: ws
                required property var modelData
                readonly property bool focused: Hyprland.focusedWorkspace
                    && Hyprland.focusedWorkspace.id === modelData.id

                implicitWidth: Math.max(Shared.DesktopStyle.px(32), wsRow.implicitWidth + Shared.DesktopStyle.px(20))
                implicitHeight: bar.implicitHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Shared.DesktopStyle.px(3)
                    radius: Shared.DesktopStyle.px(5)
                    color: Qt.rgba(ShellLayout.buttonColor("workspaces").r, ShellLayout.buttonColor("workspaces").g, ShellLayout.buttonColor("workspaces").b, ws.focused ? 0.15 : wsMouse.containsMouse ? 0.07 : 0)
                    border.width: 1
                    border.color: Qt.rgba(ShellLayout.buttonColor("workspaces").r, ShellLayout.buttonColor("workspaces").g, ShellLayout.buttonColor("workspaces").b, ws.focused ? 0.38 : wsMouse.containsMouse ? 0.2 : 0)
                    Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
                    Behavior on border.color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
                }
                RowLayout {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: Shared.DesktopStyle.px(6)
                    UiLabel { text: ws.modelData.id + ":"; font.pixelSize: Shared.DesktopStyle.px(12); color: ws.focused ? ShellLayout.buttonColor("workspaces") : Colors.muted }
                    Repeater {
                        model: Hypr.classesOn(ws.modelData.id).length ? Hypr.classesOn(ws.modelData.id) : [""]
                        ApplicationIcon {
                            required property string modelData
                            appClass: modelData
                            opacity: ws.focused ? 1 : 0.75
                        }
                    }
                }

                MouseArea {
                    id: wsMouse
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + ws.modelData.id + "\" })")
                }
            }
        }
    }
        }
    }
