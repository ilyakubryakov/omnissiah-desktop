import QtQuick
import Quickshell

// A hover hint under a bar item. Controls' ToolTip draws inside the bar's own
// window and gets clipped by its height, so this is a popup of its own.
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
    anchor.margins.top: side || above ? 0 : 8
    anchor.margins.bottom: above && !side ? 8 : 0
    anchor.margins.left: side ? 8 : 0
    implicitWidth: Math.min(360, Math.max(120, measure.implicitWidth + 28))
    implicitHeight: label.implicitHeight + 20
    color: "transparent"
    visible: ready && text !== ""

    property bool ready: false
    onShownChanged: shown ? delay.restart() : (delay.stop(), ready = false)
    Timer { id: delay; interval: 400; onTriggered: tip.ready = true }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Colors.background
        border.width: 1
        border.color: Colors.lightBackground
    }
    Text { id: measure; visible: false; text: tip.text; textFormat: Text.PlainText; font.family: Colors.textFont; font.pixelSize: Colors.fontSize }
    Text {
        id: label
        width: tip.width - 28
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: tip.text
        color: Colors.foreground
        font.family: Colors.textFont
        font.pixelSize: Colors.fontSize
    }
}
