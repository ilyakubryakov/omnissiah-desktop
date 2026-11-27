import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

RowLayout {
    property string glyph
    property string title
    property string note
    Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(10)
    Text { text: parent.glyph; font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(22); color: Colors.accent }
    UiLabel { text: parent.title; font.pixelSize: Shared.DesktopStyle.px(18); Layout.fillWidth: true }
    UiLabel { text: parent.note; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(11) }
}
