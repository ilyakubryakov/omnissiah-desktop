pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: Shared.DesktopStyle.px(20)
    property string query: ""
    readonly property var results: Object.values(AppIcons.apps).filter(e =>
        (e.name + " " + e.id + " " + e.genericName).toLowerCase().includes(query.toLowerCase()))
        .sort((a, b) => Number(PinnedApps.contains(b.id)) - Number(PinnedApps.contains(a.id)) || a.name.localeCompare(b.name))
    SettingsGroup {
        title: "Icon theme"
        footer: "One icon family for GTK, Qt and Launchpad; light and dark variants follow your palette, and some open applications need a restart. Papirus folders follow the palette; Tela, Colloid and Fluent use calm grey folders. Panel icons stay monochrome and follow your chosen group accent."
        SettingsRow {
            stacked: true
            GridLayout {
                columns: 3; Layout.fillWidth: true; columnSpacing: Shared.DesktopStyle.px(12); rowSpacing: Shared.DesktopStyle.px(12)
                Repeater {
                    model: AppIcons.data.families
                    Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool active: AppIcons.data.family === modelData.id
                        Layout.fillWidth: true; implicitHeight: Shared.DesktopStyle.px(96); radius: Shared.DesktopStyle.radiusSmall
                        color: Colors.background; border.width: active ? 2 : 1
                        border.color: active ? Colors.accent : Colors.selection
                        opacity: modelData.available ? 1 : 0.45
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: Shared.DesktopStyle.px(12); spacing: Shared.DesktopStyle.px(8)
                            Row {
                                spacing: Shared.DesktopStyle.px(9)
                                Repeater {
                                    model: card.modelData.preview
                                    Image { required property string modelData; source: modelData; width: Shared.DesktopStyle.px(28); height: width; sourceSize: Qt.size(64,64); fillMode: Image.PreserveAspectFit; mipmap: true }
                                }
                            }
                            UiLabel { text: card.modelData.name + (card.active ? " · active" : card.modelData.available ? "" : " · not installed"); font.weight: card.active ? Font.DemiBold : Font.Normal }
                        }
                        MouseArea {
                            anchors.fill: parent; enabled: card.modelData.available && !DesktopData.busy
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DesktopData.act("appearance", ["icons", card.modelData.id])
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: "Pinned applications"
        footer: "Drag icons on the top panel to reorder. Scroll the strip if it fills up. Pin any application here or use its pin button in Launchpad."
        SettingsRow {
            title: "Find"
            TextField {
                id: search
                Layout.preferredWidth: Shared.DesktopStyle.px(300); placeholderText: "Find an application…"
                color: Colors.foreground; selectionColor: Colors.accent
                onTextChanged: root.query = text
                background: Rectangle { radius: Shared.DesktopStyle.radiusSmall; color: Colors.background; border.width: 1; border.color: search.activeFocus ? Colors.accent : Colors.selection }
            }
        }
        SettingsRow {
            stacked: true
            ListView {
                Layout.fillWidth: true; Layout.preferredHeight: Shared.DesktopStyle.px(330)
                clip: true; spacing: 0; model: root.results
                ScrollBar.vertical: ScrollBar {}
                delegate: Item {
                    id: app
                    required property var modelData
                    required property int index
                    width: ListView.view.width - Shared.DesktopStyle.px(16); height: Shared.DesktopStyle.px(48)
                    Rectangle { visible: app.index > 0; anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Shared.DesktopStyle.px(42) } height: 1; color: Colors.selection }
                    RowLayout {
                        anchors.fill: parent; anchors.topMargin: Shared.DesktopStyle.px(6); anchors.bottomMargin: Shared.DesktopStyle.px(6); spacing: Shared.DesktopStyle.px(12)
                        Image { source: AppIcons.icon(app.modelData); Layout.preferredWidth: Shared.DesktopStyle.px(28); Layout.preferredHeight: Shared.DesktopStyle.px(28); sourceSize: Qt.size(64,64); fillMode: Image.PreserveAspectFit; mipmap: true }
                        UiLabel { Layout.fillWidth: true; text: app.modelData.name; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                        UiButton {
                            text: PinnedApps.contains(app.modelData.id) ? "Unpin" : "Pin"
                            glyph: "\u{F0403}"; selected: PinnedApps.contains(app.modelData.id)
                            onClicked: PinnedApps.toggle(app.modelData.id)
                        }
                    }
                }
            }
        }
        SettingsRow { visible: !root.results.length; title: "No matching applications" }
    }
}
