pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared
import "LiveWallpaper.js" as Live

ColumnLayout {
    id: panel
    spacing: Shared.DesktopStyle.cardSpacing
    readonly property var properties: LiveWallpaperData.properties
    readonly property var values: new Map(properties.map(setting => [setting.key, setting.value]))

    RowLayout {
        Layout.fillWidth: true
        spacing: Shared.DesktopStyle.cardSpacing
        UiLabel {
            Layout.fillWidth: true
            text: LiveWallpaperData.status.item?.title || ""
            font.weight: Font.DemiBold
        }
        UiButton {
            text: "Reset all"
            enabled: !LiveWallpaperData.busy
            onClicked: LiveWallpaperData.customize()
        }
    }

    ScrollView {
        id: scroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: scroll.availableWidth - Shared.DesktopStyle.px(14)
            spacing: Shared.DesktopStyle.cardSpacing

            Repeater {
                model: panel.properties.length
                delegate: RowLayout {
                    id: row
                    required property int index
                    readonly property var setting: panel.properties[index] ?? ({text: ""})
                    readonly property bool modified: !!setting.type
                        && !Live.samePropertyValue(setting.type, setting.value, setting.default)
                    Layout.fillWidth: true
                    spacing: Shared.DesktopStyle.cardSpacing
                    visible: !!setting.type && Live.propertyVisible(setting, panel.values)
                    enabled: !LiveWallpaperData.busy

                    function save(value) {
                        if (enabled && !Live.samePropertyValue(setting.type, setting.value, value))
                            LiveWallpaperData.customize(setting.key, value)
                    }

                    UiLabel {
                        Layout.fillWidth: true
                        text: row.setting.text
                        wrapMode: Text.WrapAnywhere
                    }

                    Loader {
                        Layout.preferredWidth: Shared.DesktopStyle.px(340)
                        active: row.visible
                        sourceComponent: {
                            switch (row.setting.type) {
                            case "bool": return toggleEditor
                            case "combo": return comboEditor
                            case "slider": return sliderEditor
                            default: return fieldEditor
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: reset.implicitWidth
                        Layout.preferredHeight: reset.implicitHeight
                        UiButton {
                            id: reset
                            anchors.fill: parent
                            visible: row.modified
                            text: "Reset"
                            Accessible.name: "Reset " + row.setting.text
                            onClicked: LiveWallpaperData.customize(row.setting.key)
                        }
                    }

                    Component {
                        id: toggleEditor
                        Item {
                            implicitHeight: toggle.implicitHeight
                            Switch {
                                id: toggle
                                implicitHeight: Shared.DesktopStyle.controlHeight
                                implicitWidth: Shared.DesktopStyle.px(48)
                                padding: 0
                                checked: Live.boolValue(row.setting.value)
                                Accessible.name: row.setting.text
                                onToggled: {
                                    row.save(checked)
                                    checked = Qt.binding(() => Live.boolValue(row.setting.value))
                                }
                                indicator: Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: toggle.width
                                    height: Shared.DesktopStyle.px(24)
                                    radius: height / 2
                                    color: toggle.checked ? Colors.accent : Colors.selection
                                    border.width: toggle.activeFocus ? Shared.DesktopStyle.focusWidth : 0
                                    border.color: Colors.foreground
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: toggle.checked ? parent.width - width - Shared.DesktopStyle.px(3)
                                            : Shared.DesktopStyle.px(3)
                                        width: Shared.DesktopStyle.px(18)
                                        height: width
                                        radius: width / 2
                                        color: toggle.checked ? Colors.background : Colors.foreground
                                    }
                                }
                            }
                        }
                    }

                    Component {
                        id: comboEditor
                        UiComboBox {
                            id: combo
                            model: row.setting.options
                            textRole: "label"
                            valueRole: "value"
                            currentIndex: indexOfValue(String(row.setting.value ?? ""))
                            Accessible.name: row.setting.text
                            onActivated: {
                                row.save(currentValue)
                                currentIndex = Qt.binding(() => combo.indexOfValue(String(row.setting.value ?? "")))
                            }
                        }
                    }

                    Component {
                        id: sliderEditor
                        RowLayout {
                            spacing: Shared.DesktopStyle.cardSpacing
                            UiSlider {
                                id: slider
                                Layout.fillWidth: true
                                readonly property real savedValue: Number(row.setting.value ?? 0)
                                property real startValue: 0
                                readonly property real step: Number(row.setting.step ?? 0.01)
                                from: Number(row.setting.min ?? 0)
                                to: Number(row.setting.max ?? 1)
                                stepSize: row.setting.integer ? Math.max(1, step) : step
                                value: savedValue
                                wheelEnabled: false
                                Accessible.name: row.setting.text
                                Keys.onReleased: event => {
                                    if (event.isAutoRepeat && (event.key === Qt.Key_Left || event.key === Qt.Key_Right))
                                        event.accepted = true
                                }
                                onPressedChanged: {
                                    if (pressed) {
                                        startValue = value
                                        return
                                    }
                                    const next = Number(value.toFixed(row.setting.integer ? 0 : 4))
                                    const changed = value !== startValue
                                    value = Qt.binding(() => slider.savedValue)
                                    if (changed) row.save(next)
                                }
                            }
                            UiLabel {
                                Layout.preferredWidth: Shared.DesktopStyle.px(72)
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.NoWrap
                                elide: Text.ElideLeft
                                text: String(Number(slider.value.toFixed(row.setting.integer ? 0 : 4)))
                            }
                        }
                    }

                    Component {
                        id: fieldEditor
                        RowLayout {
                            id: editor
                            spacing: Shared.DesktopStyle.cardSpacing
                            readonly property bool isColor: row.setting.type === "color"
                            readonly property var value: isColor ? Live.colorValue(field.text) : Live.textValue(field.text)
                            readonly property var rgb: isColor && value !== null ? value.split(" ").map(Number) : null
                            readonly property bool canSave: value !== null
                                && !Live.samePropertyValue(row.setting.type, row.setting.value, value)

                            Rectangle {
                                visible: editor.isColor
                                Layout.preferredWidth: Shared.DesktopStyle.px(28)
                                Layout.preferredHeight: Shared.DesktopStyle.px(24)
                                radius: Shared.DesktopStyle.radiusSmall
                                border.width: Shared.DesktopStyle.focusWidth
                                border.color: Colors.selection
                                color: editor.rgb ? Qt.rgba(editor.rgb[0], editor.rgb[1], editor.rgb[2], 1) : Colors.background
                            }
                            TextField {
                                id: field
                                Layout.fillWidth: true
                                readonly property string savedText: String(row.setting.value ?? "")
                                text: savedText
                                placeholderText: editor.isColor ? "#RRGGBB or 0.0 0.0 0.0" : ""
                                Accessible.name: row.setting.text
                                implicitHeight: Shared.DesktopStyle.controlHeight
                                leftPadding: Shared.DesktopStyle.controlPadding
                                rightPadding: leftPadding
                                font.family: Colors.textFont
                                font.pixelSize: Shared.DesktopStyle.fontSize
                                color: Colors.foreground
                                selectionColor: Colors.accent
                                background: Rectangle {
                                    color: Colors.lightBackground
                                    radius: Shared.DesktopStyle.radiusControl
                                    border.width: Shared.DesktopStyle.focusWidth
                                    border.color: editor.value === null ? Colors.red
                                        : field.activeFocus ? Colors.accent : Colors.selection
                                }
                                ToolTip.visible: editor.value === null && activeFocus
                                ToolTip.text: editor.isColor ? "Enter #RRGGBB or three numbers from 0 to 1"
                                    : "Text cannot contain line breaks or ="
                                onAccepted: if (editor.canSave) row.save(editor.value)
                            }
                            UiButton {
                                text: "Save"
                                enabled: editor.canSave
                                Accessible.name: "Save " + row.setting.text
                                onClicked: row.save(editor.value)
                            }
                        }
                    }
                }
            }
        }
    }
}
