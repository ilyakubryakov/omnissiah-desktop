pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: 12
    property string query: ""
    readonly property var rows: DesktopData.clips.filter(c => c.text.toLowerCase().includes(query.toLowerCase()))

    function colorOf(text) {
        const m = text.trim().match(/^#?([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i)
        if (m) return "#" + (m[1].length === 8 ? m[1].slice(6) + m[1].slice(0, 6) : m[1])
        return /^rgba?\(\s*[\d.]+%?\s*,\s*[\d.]+%?\s*,\s*[\d.]+%?\s*(,\s*[\d.]+\s*)?\)$/i.test(text.trim()) ? text.trim() : ""
    }
    function isJson(text) {
        const s = text.trim()
        if (!/^[\[{]/.test(s)) return false
        if (text.length >= 8192) return true
        try { JSON.parse(s); return true } catch (_) { return false }
    }
    function isBase64(text) {
        const s = text.trim()
        return s.length >= 16 && s.length <= 65536 && /^[A-Za-z0-9+/_-]+={0,2}$/.test(s) && /[0-9+/_=-]/.test(s) && !/^\d+$/.test(s)
    }
    function timestampOf(text) {
        const s = text.trim()
        if (!/^\d{10}(\d{3})?$/.test(s)) return ""
        const ms = s.length === 13 ? Number(s) : Number(s) * 1000
        if (ms < Date.UTC(2000, 0, 1) || ms > Date.UTC(2100, 0, 1)) return ""
        return new Date(ms).toLocaleString(Qt.locale(), "yyyy-MM-dd HH:mm:ss")
    }
    TextField {
        id: search
        Layout.fillWidth: true
        placeholderText: "Search text and screenshots…"
        color: Colors.foreground; placeholderTextColor: Colors.muted
        font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(16)
        padding: 12
        background: Rectangle { color: Colors.lightBackground; border.width: 1; border.color: search.activeFocus ? Colors.accent : Colors.selection }
        onTextChanged: root.query = text
        onAccepted: if (root.rows.length && !DesktopData.busy) DesktopData.act("copy", [root.rows[0].id])
        Component.onCompleted: Qt.callLater(() => search.forceActiveFocus())
    }
    UiLabel { text: "Enter copies the first match. Paste with Ctrl+V. Pinned text stays above the history on this machine."; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12); Layout.fillWidth: true; wrapMode: Text.Wrap }
    UiLabel { visible: root.rows.length === 0; text: "No matching entries"; color: Colors.muted }
    Repeater {
        model: root.rows
        Rectangle {
            id: entry
            required property var modelData
            readonly property bool pinned: !!modelData.pinned
            readonly property bool picture: modelData.image !== ""
            readonly property string swatch: picture ? "" : root.colorOf(modelData.text)
            readonly property string stamp: picture ? "" : root.timestampOf(modelData.text)
            Layout.fillWidth: true
            implicitHeight: content.implicitHeight + 24
            color: Colors.lightBackground
            border.width: pinned ? 1 : 0; border.color: Colors.accent
            ColumnLayout {
                id: content
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10
                Image {
                    Layout.fillWidth: true; Layout.preferredHeight: visible ? 160 : 0
                    visible: entry.modelData.image !== ""
                    source: entry.modelData.image
                    sourceSize.width: 580; sourceSize.height: 160
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true; cache: false
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(10)
                    UiLabel {
                        visible: entry.pinned; text: "\uf08d"; color: Colors.accent
                        font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(13); Layout.alignment: Qt.AlignTop
                        Accessible.name: "Pinned"
                    }
                    Rectangle {
                        visible: entry.swatch !== ""
                        implicitWidth: Shared.DesktopStyle.px(22); implicitHeight: implicitWidth; radius: implicitWidth / 2
                        color: entry.swatch || "transparent"; border.width: 1; border.color: Colors.selection
                        Layout.alignment: Qt.AlignTop
                    }
                    UiLabel {
                        Layout.fillWidth: true
                        text: entry.modelData.text
                        maximumLineCount: 5; elide: Text.ElideRight
                        font.family: entry.picture ? Colors.textFont : "JetBrainsMono Nerd Font"
                        font.pixelSize: Shared.DesktopStyle.px(13)
                    }
                }
                UiLabel { visible: entry.stamp !== ""; text: "Timestamp: " + entry.stamp; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12) }
                RowLayout {
                    spacing: Shared.DesktopStyle.px(6)
                    UiButton { text: "Copy"; enabled: !DesktopData.busy; onClicked: DesktopData.act("copy", [entry.modelData.id]) }
                    UiButton {
                        visible: !entry.picture; text: entry.pinned ? "Unpin" : "Pin"; glyph: "\uf08d"; enabled: !DesktopData.busy
                        onClicked: entry.pinned ? DesktopData.act("delete", [entry.modelData.id]) : DesktopData.act("clip-pin", [entry.modelData.id])
                    }
                    UiButton {
                        visible: !entry.picture && root.isJson(entry.modelData.text); text: "Format JSON"; enabled: !DesktopData.busy
                        Accessible.name: "Copy formatted JSON"
                        onClicked: DesktopData.act("clip-format", [entry.modelData.id, "json"])
                    }
                    UiButton {
                        visible: !entry.picture && root.isBase64(entry.modelData.text); text: "Decode base64"; enabled: !DesktopData.busy
                        Accessible.name: "Copy decoded base64 text"
                        onClicked: DesktopData.act("clip-format", [entry.modelData.id, "base64"])
                    }
                    UiButton {
                        visible: entry.picture; text: "Edit"; enabled: !DesktopData.busy
                        Accessible.name: "Edit in Swappy"
                        onClicked: Quickshell.execDetached(["oninix-app", "swappy", "-f", decodeURIComponent(entry.modelData.image.replace(/^file:\/\//, ""))])
                    }
                    UiButton { visible: !entry.pinned; text: "Delete"; danger: true; enabled: !DesktopData.busy; onClicked: DesktopData.act("delete", [entry.modelData.id]) }
                }
            }
        }
    }
}
