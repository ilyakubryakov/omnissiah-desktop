import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 16
    property string query: ""
    readonly property var results: Object.values(AppIcons.apps).filter(e =>
        (e.name + " " + e.id + " " + e.genericName).toLowerCase().includes(query.toLowerCase()))
        .sort((a, b) => Number(PinnedApps.contains(b.id)) - Number(PinnedApps.contains(a.id)) || a.name.localeCompare(b.name))
    UiLabel { text: "DESKTOP ICONS"; font.pixelSize: 12; font.letterSpacing: 2; color: Colors.muted }
    UiLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Colors.muted; font.pixelSize: 13
        text: "One icon family for GTK, Qt and Launchpad. Light and dark variants follow your palette. Some open applications need a restart." }
    GridLayout {
        columns: 3; Layout.fillWidth: true; columnSpacing: 12; rowSpacing: 12
        Repeater {
            model: AppIcons.data.families
            Rectangle {
                id: card
                required property var modelData
                Layout.fillWidth: true; implicitHeight: 110; radius: 10
                color: Colors.lightBackground; border.width: 1
                border.color: AppIcons.data.family === modelData.id ? Colors.accent : Colors.selection
                opacity: modelData.available ? 1 : 0.45
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10
                    Row {
                        spacing: 9
                        Repeater {
                            model: card.modelData.preview
                            Image { required property string modelData; source: modelData; width: 30; height: 30; sourceSize: Qt.size(64,64); fillMode: Image.PreserveAspectFit; mipmap: true }
                        }
                    }
                    UiLabel { text: card.modelData.name + (AppIcons.data.family === card.modelData.id ? " · active" : card.modelData.available ? "" : " · not installed") }
                }
                MouseArea {
                    anchors.fill: parent; enabled: card.modelData.available && !DesktopData.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DesktopData.act("appearance", ["icons", card.modelData.id])
                }
            }
        }
    }
    UiLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Colors.muted; font.pixelSize: 12
        text: "Papirus folders follow the palette. Tela, Colloid and Fluent use calm grey folders. Panel icons stay monochrome and follow your chosen group accent." }
    UiLabel { text: "PINNED APPLICATIONS"; font.pixelSize: 12; font.letterSpacing: 2; color: Colors.muted; Layout.topMargin: 8 }
    UiLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Colors.muted; font.pixelSize: 13
        text: "Drag icons on the top panel to reorder. Scroll the strip if it fills up. Pin any application below or use its pin button in Launchpad." }
    TextField {
        id: search
        Layout.fillWidth: true; placeholderText: "Find an application…"
        color: Colors.foreground; selectionColor: Colors.accent
        onTextChanged: root.query = text
        background: Rectangle { radius: 8; color: Colors.lightBackground; border.width: 1; border.color: search.activeFocus ? Colors.accent : Colors.selection }
    }

    ListView {
        Layout.fillWidth: true; Layout.preferredHeight: 330
        clip: true; spacing: 4; model: root.results
        ScrollBar.vertical: ScrollBar {}
        delegate: Rectangle {
            id: app
            required property var modelData
            width: ListView.view.width - 16; height: 52; radius: 8
            color: Colors.lightBackground
            RowLayout {
                anchors.fill: parent; anchors.margins: 8; spacing: 12
                Image { source: AppIcons.icon(app.modelData); Layout.preferredWidth: 30; Layout.preferredHeight: 30; sourceSize: Qt.size(64,64); fillMode: Image.PreserveAspectFit; mipmap: true }
                UiLabel { Layout.fillWidth: true; text: app.modelData.name; elide: Text.ElideRight }
                UiButton {
                    text: PinnedApps.contains(app.modelData.id) ? "Unpin" : "Pin"
                    glyph: "\u{F0403}"; selected: PinnedApps.contains(app.modelData.id)
                    onClicked: PinnedApps.toggle(app.modelData.id)
                }
            }
        }
    }
    UiLabel { visible: !root.results.length; text: "No matching applications"; color: Colors.muted }
}
