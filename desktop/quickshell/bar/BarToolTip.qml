import QtQuick
import Quickshell
import "../shared" as Shared

PopupWindow {
    id: tip

    required property Item target
    property string text: ""
    property bool shown: false
    property bool side: false

    readonly property var barWindow: target.QsWindow.window
    readonly property bool above: barWindow && barWindow.edge === "bottom"

    anchor.item: target
    anchor.edges: side ? Edges.Right : above ? Edges.Top : Edges.Bottom
    anchor.gravity: side ? Edges.Right : above ? Edges.Top : Edges.Bottom
    anchor.margins.top: side || above ? 0 : Shared.DesktopStyle.px(8)
    anchor.margins.bottom: above && !side ? Shared.DesktopStyle.px(8) : 0
    anchor.margins.left: side ? Shared.DesktopStyle.px(8) : 0
    implicitWidth: Math.min(Shared.DesktopStyle.px(360), Math.max(Shared.DesktopStyle.px(120), measure.implicitWidth + Shared.DesktopStyle.px(28)))
    implicitHeight: label.implicitHeight + Shared.DesktopStyle.px(20)
    color: "transparent"
    visible: ready && text !== ""

    property bool ready: false
    onShownChanged: shown ? delay.restart() : (delay.stop(), ready = false)
    Timer { id: delay; interval: 400; onTriggered: tip.ready = true }

    Rectangle {
        anchors.fill: parent
        radius: Shared.DesktopStyle.radiusSmall
        color: Colors.background
        border.width: 1
        border.color: Colors.lightBackground
    }
    Text { id: measure; visible: false; text: tip.text; textFormat: Text.PlainText; font.family: Colors.textFont; font.pixelSize: Colors.fontSize }
    Text {
        id: label
        width: tip.width - Shared.DesktopStyle.px(28)
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: tip.text
        color: Colors.foreground
        font.family: Colors.textFont
        font.pixelSize: Colors.fontSize
    }
}
