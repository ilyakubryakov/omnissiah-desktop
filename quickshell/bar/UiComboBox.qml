import QtQuick
import QtQuick.Controls
import "../shared" as Shared

ComboBox {
    id: root
    implicitHeight: 36
    implicitWidth: 220
    leftPadding: 12; rightPadding: 30
    font.family: Colors.textFont; font.pixelSize: 13
    contentItem: Text {
        text: root.displayText; font: root.font; color: root.enabled ? Colors.foreground : Colors.muted
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    indicator: Text {
        x: root.width - width - 12; anchors.verticalCenter: parent.verticalCenter
        text: "\uf107"; font.family: Colors.iconFont; font.pixelSize: 14; color: Colors.muted
    }
    background: Rectangle {
        radius: 8; color: Colors.background; border.width: 1
        border.color: root.activeFocus || root.popup.visible ? Colors.accent : Colors.selection
        Behavior on border.color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
    }
    delegate: ItemDelegate {
        required property int index
        width: root.width - 2; implicitHeight: 36
        highlighted: root.highlightedIndex === index
        contentItem: Text { text: root.textAt(index); font: root.font; color: Colors.foreground; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { radius: 6; color: parent.highlighted ? Colors.selection : "transparent" }
    }
    popup: Popup {
        y: root.height + 4; width: root.width; padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 260)
        contentItem: ListView {
            clip: true; implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
        background: Rectangle { radius: 9; color: Colors.lightBackground; border.color: Colors.selection; border.width: 1 }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Shared.DesktopStyle.fast } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Shared.DesktopStyle.fast } }
    }
}
