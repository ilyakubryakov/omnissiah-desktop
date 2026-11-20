import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

// One row of a SettingsGroup: title (and an optional explanation) on the left,
// its control on the right. `stacked` puts a wide control (grid, slider row,
// editor) under the title instead. The hairline separates it from the row above.
Item {
    id: row
    property string title: ""
    property string subtitle: ""
    property bool stacked: false
    default property alias control: slot.data
    Layout.fillWidth: true
    implicitHeight: Math.max(Shared.DesktopStyle.px(46), grid.implicitHeight + 2 * Shared.DesktopStyle.px(10))
    readonly property bool first: {
        const kids = parent ? parent.children : []
        // Repeaters are children too: count only visible rows.
        for (let i = 0; i < kids.length; i++) if (kids[i].visible && ("stacked" in kids[i])) return kids[i] === row
        return true
    }
    Rectangle {
        visible: !row.first
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Shared.DesktopStyle.px(14); rightMargin: Shared.DesktopStyle.px(14) }
        height: 1; color: Colors.selection
    }
    GridLayout {
        id: grid
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Shared.DesktopStyle.px(14); rightMargin: Shared.DesktopStyle.px(14) }
        columns: row.stacked ? 1 : 2
        columnSpacing: Shared.DesktopStyle.px(16); rowSpacing: Shared.DesktopStyle.px(8)
        ColumnLayout {
            visible: row.title !== "" || row.subtitle !== ""
            Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(2)
            UiLabel { visible: row.title !== ""; Layout.fillWidth: true; text: row.title }
            UiLabel { visible: row.subtitle !== ""; Layout.fillWidth: true; text: row.subtitle; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12) }
        }
        RowLayout {
            id: slot
            Layout.fillWidth: row.stacked
            Layout.alignment: row.stacked ? Qt.AlignLeft : Qt.AlignRight | Qt.AlignVCenter
            spacing: Shared.DesktopStyle.px(6)
        }
    }
}
