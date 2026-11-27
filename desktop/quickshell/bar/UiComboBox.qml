import QtQuick
import QtQuick.Controls
import "../shared" as Shared

ComboBox {
    id: root
    implicitHeight: Shared.DesktopStyle.unified ? Shared.DesktopStyle.controlHeight : Shared.DesktopStyle.metrics.control_height
    implicitWidth: Shared.DesktopStyle.px(220)
    leftPadding: Shared.DesktopStyle.controlPadding; rightPadding: Shared.DesktopStyle.controlPadding + Shared.DesktopStyle.px(18)
    font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.comboFontSize
    contentItem: Text {
        text: root.displayText; font: root.font; color: root.enabled ? Colors.foreground : Colors.muted
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    indicator: Text {
        x: root.width - width - Shared.DesktopStyle.px(12); anchors.verticalCenter: parent.verticalCenter
        text: "\uf107"; font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(14); color: Colors.muted
    }
    background: Rectangle {
        radius: Shared.DesktopStyle.metrics.combo_radius; color: Colors.background; border.width: root.activeFocus ? Shared.DesktopStyle.focusWidth : 1
        border.color: root.activeFocus || root.popup.visible ? Colors.accent : Colors.selection
        Behavior on border.color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
    }
    delegate: ItemDelegate {
        required property int index
        width: root.width - Shared.DesktopStyle.px(2); implicitHeight: Shared.DesktopStyle.unified ? Shared.DesktopStyle.controlHeight : Shared.DesktopStyle.metrics.control_height
        highlighted: root.highlightedIndex === index
        contentItem: Text { text: root.textAt(index); font: root.font; color: Colors.foreground; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { radius: Shared.DesktopStyle.metrics.row_radius; color: parent.highlighted ? Colors.selection : "transparent" }
    }
    popup: Popup {
        y: root.height + Shared.DesktopStyle.spaceUnit; width: root.width; padding: Shared.DesktopStyle.spaceUnit
        implicitHeight: Math.min(contentItem.implicitHeight + Shared.DesktopStyle.px(8), Shared.DesktopStyle.px(260))
        contentItem: ListView {
            clip: true; implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
        background: Rectangle { radius: Shared.DesktopStyle.metrics.popup_radius; color: Colors.lightBackground; border.color: Colors.selection; border.width: 1 }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Shared.DesktopStyle.fast } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Shared.DesktopStyle.fast } }
    }
}
