pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: 16
    readonly property var appearance: DesktopData.appearance
    property string section: "themes"
    property string wallpaperVariant: ""
    readonly property var wallpaper: appearance.wallpaper || ({})
    readonly property string activeVariant: (appearance.palettes.find(p => p.id === appearance.schedule.palette) || {}).mode || "dark"
    readonly property string targetSlot: wallpaper.mode === "variant" ? (wallpaperVariant || activeVariant) : "shared"
    readonly property string targetName: ({shared:"all themes", light:"light themes", dark:"dark themes"})[targetSlot]
    readonly property string selectedWallpaper: wallpaper[targetSlot] || wallpaper.shared || ""
    function title(id) {
        return ({"tesla-day":"Tesla Day", "tesla-night":"Tesla Night", "graphite":"Graphite", "omnissiah":"Omnissiah", "kanagawa-lotus":"Lotus · light", "kanagawa-dragon":"Dragon · dark"})[id] || id
    }
    function act(args) { DesktopData.act("appearance", args) }
    component Heading: UiLabel { font.pixelSize: 12; font.letterSpacing: 2; color: Colors.muted }

    AppearancePresets { visible: root.section === "themes"; Layout.fillWidth: true }

    ApplicationSettings { visible: root.section === "apps"; Layout.fillWidth: true }

    ColumnLayout {
        visible: root.section === "themes"
        Layout.fillWidth: true
        spacing: 16
        Heading { text: "PALETTE" }
        UiLabel { Layout.fillWidth: true; color: Colors.muted; font.pixelSize: 13; text: "Choose a palette, or select a day / night pair for automatic switching." }
        GridLayout {
            Layout.fillWidth: true; columns: width < 560 ? 2 : 3
            columnSpacing: 12; rowSpacing: 12
            Repeater {
                model: root.appearance.palettes
                Rectangle {
                    id: paletteCard
                    required property var modelData
                    Layout.fillWidth: true; implicitHeight: 104
                    color: modelData.background
                    radius: Shared.DesktopStyle.radiusSmall
                    border.width: 1
                    border.color: root.appearance.schedule.palette === modelData.id || activeFocus || paletteMouse.containsMouse ? modelData.accent : Colors.selection
                    Behavior on border.color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
                    activeFocusOnTab: true
                    enabled: !DesktopData.busy
                    opacity: enabled ? 1 : 0.55
                    function choose() { root.act(["palette", modelData.id]) }
                    Accessible.role: Accessible.Button
                    Accessible.name: root.title(modelData.id)
                    Accessible.onPressAction: choose()
                    Keys.onReturnPressed: choose()
                    Keys.onSpacePressed: choose()
                    Column {
                        anchors.fill: parent; anchors.margins: 16; spacing: 10
                        Rectangle { width: 32; height: 4; color: paletteCard.modelData.accent }
                        Text { text: root.title(paletteCard.modelData.id); color: paletteCard.modelData.foreground; font.family: Colors.textFont; font.pixelSize: 16 }
                        Text { text: root.appearance.schedule.palette === paletteCard.modelData.id ? "ACTIVE" : "Apply palette"; color: paletteCard.modelData.accent; font.family: Colors.textFont; font.pixelSize: 11 }
                    }
                    MouseArea { id: paletteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: paletteCard.choose() }
                }
            }
        }
        RowLayout {
            Repeater {
                model: [{id:"manual",name:"Manual"}, {id:"sun",name:"Sunrise / sunset"}, {id:"fixed",name:"Schedule"}]
                UiButton {
                    required property var modelData
                    text: modelData.name; selected: root.appearance.schedule.mode === modelData.id
                    enabled: !DesktopData.busy
                    onClicked: root.act(["schedule", modelData.id])
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: 12; rowSpacing: 8
            Repeater {
                model: ["light", "dark"]
                ColumnLayout {
                    id: scheduleChoice
                    required property string modelData
                    Layout.fillWidth: true
                    readonly property var choices: root.appearance.palettes.filter(p => p.mode === modelData)
                    UiLabel { text: scheduleChoice.modelData === "light" ? "Day palette" : "Night palette"; color: Colors.muted; font.pixelSize: 12 }
                    SettingCombo {
                        model: scheduleChoice.choices.map(p => root.title(p.id))
                        currentIndex: scheduleChoice.choices.findIndex(p => p.id === root.appearance.schedule[scheduleChoice.modelData + "_palette"])
                        enabled: !DesktopData.busy
                        Accessible.name: scheduleChoice.modelData === "light" ? "Day palette" : "Night palette"
                        onActivated: index => root.act(["schedule-palette", scheduleChoice.modelData, scheduleChoice.choices[index].id])
                    }
                }
            }
        }
        RowLayout {
            visible: root.appearance.schedule.mode === "fixed"
            Repeater {
                model: ["light", "dark"]
                RowLayout {
                    id: boundary
                    required property string modelData
                    UiLabel { text: boundary.modelData === "light" ? "Light" : "Dark" }
                    TextField {
                        id: timeField
                        Layout.preferredWidth: 82
                        text: root.appearance.schedule[boundary.modelData + "_at"] || ""
                        placeholderText: "HH:MM"
                        validator: RegularExpressionValidator { regularExpression: /([01][0-9]|2[0-3]):[0-5][0-9]/ }
                        color: Colors.foreground; selectionColor: Colors.accent
                        background: Rectangle { color: Colors.lightBackground; border.color: timeField.activeFocus ? Colors.accent : Colors.selection; border.width: 1 }
                        onAccepted: if (acceptableInput) root.act(["time", boundary.modelData, text])
                    }
                    UiButton { text: "Save"; enabled: timeField.acceptableInput && !DesktopData.busy; onClicked: root.act(["time", boundary.modelData, timeField.text]) }
                }
            }
        }
        UiLabel {
            visible: !!root.appearance.schedule.next_human && root.appearance.schedule.mode !== "manual"
            text: "Next transition · " + (root.appearance.schedule.next_human || "") + (root.appearance.schedule.override_until ? " · manual hold" : "")
            color: Colors.muted; font.pixelSize: 12
        }

        Heading { text: "WALLPAPER"; Layout.topMargin: 8 }
        RowLayout {
            UiLabel { text: "Use wallpaper"; Layout.preferredWidth: 120 }
            UiButton { text: "Same for all themes"; selected: root.wallpaper.mode !== "variant"; enabled: !DesktopData.busy; onClicked: root.act(["wallpaper-mode", "shared"]) }
            UiButton { text: "Light / dark"; selected: root.wallpaper.mode === "variant"; enabled: !DesktopData.busy; onClicked: root.act(["wallpaper-mode", "variant"]) }
        }
        RowLayout {
            visible: root.wallpaper.mode === "variant"
            UiLabel { text: "Choose for"; Layout.preferredWidth: 120 }
            UiButton { text: "Light themes"; selected: root.targetSlot === "light"; onClicked: root.wallpaperVariant = "light" }
            UiButton { text: "Dark themes"; selected: root.targetSlot === "dark"; onClicked: root.wallpaperVariant = "dark" }
        }
        UiLabel {
            Layout.fillWidth: true; font.pixelSize: 12; elide: Text.ElideMiddle
            text: root.selectedWallpaper ? "Selected · " + root.selectedWallpaper : "No image selected"
        }
        RowLayout {
            UiButton {
                text: "Open wallpaper gallery"; glyph: "\u{F03E}"
                onClicked: DesktopData.showWallpapers(root.targetSlot)
            }
            UiLabel { text: "Opens in a separate window"; color: Colors.muted; font.pixelSize: 12 }
        }
        UiLabel { Layout.fillWidth: true; text: "Lock screen follows the current wallpaper with blur. Your distribution manages the login screen and boot appearance."; color: Colors.muted; font.pixelSize: 12 }
    }

    ColumnLayout {
        visible: root.section === "panels"
        Layout.fillWidth: true
        spacing: 16
        PanelEditor { Layout.fillWidth: true }
        LayoutSettings { Layout.fillWidth: true }

        Heading { text: "PANEL SHAPE" }
        GridLayout {
            columns: 2
            Layout.fillWidth: true; columnSpacing: 12; rowSpacing: 12
            Repeater {
                model: PanelStyle.presets
                Rectangle {
                    id: styleCard
                    required property var modelData
                    Layout.fillWidth: true; implicitHeight: 142
                    radius: 14
                    color: Colors.lightBackground
                    border.width: 1
                    border.color: PanelStyle.style === modelData.id || activeFocus ? Colors.accent : Colors.selection
                    activeFocusOnTab: true
                    enabled: !DesktopData.busy
                    function choose() { root.act(["panels", modelData.id]) }
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name + " panels"
                    Accessible.onPressAction: choose()
                    Keys.onReturnPressed: choose()
                    Keys.onSpacePressed: choose()
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                        height: 64; color: Colors.darkBackground; clip: true
                        Repeater {
                            model: [true, false]
                            Rectangle {
                                required property bool modelData
                                readonly property bool flat: styleCard.modelData.id === "flat"
                                readonly property bool floating: styleCard.modelData.id === "floating"
                                x: flat ? 0 : 7; width: styleCard.modelData.id === "islands" ? parent.width * 0.35 : parent.width - 2 * x; height: 10
                                y: modelData ? (floating ? 6 : 0) : parent.height - height - (floating ? 6 : 0)
                                color: Colors.accent
                                topLeftRadius: flat || (!floating && modelData) ? 0 : 4
                                topRightRadius: topLeftRadius
                                bottomLeftRadius: flat || (!floating && !modelData) ? 0 : 4
                                bottomRightRadius: bottomLeftRadius
                            }
                        }
                    }
                    Column {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                        spacing: 6
                        UiLabel { text: styleCard.modelData.name + (PanelStyle.style === styleCard.modelData.id ? " · active" : ""); font.pixelSize: 14 }
                        UiLabel { text: styleCard.modelData.detail; color: Colors.muted; font.pixelSize: 11 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: styleCard.choose() }
                }
            }
        }
        UiLabel { Layout.fillWidth: true; text: "Panel shape applies to both bars. Your palette is independent."; color: Colors.muted; font.pixelSize: 12 }
        RowLayout {
            UiLabel { text: "Filled workspace"; Layout.preferredWidth: 170 }
            UiButton { text: "Adapt panels"; selected: ShellLayout.adaptivePanels; onClicked: ShellLayout.change(["adaptive-panels", "on"]) }
            UiButton { text: "Keep my style"; selected: !ShellLayout.adaptivePanels; onClicked: ShellLayout.change(["adaptive-panels", "off"]) }
        }
        UiLabel {
            Layout.fillWidth: true; color: Colors.muted; font.pixelSize: 12; wrapMode: Text.WordWrap
            text: "Islands join when tiled windows fill this display, or a window is maximized. Floating windows keep islands. The solid panel follows the shared theme of the focused tiled app."
        }

        Heading { text: "WINDOWS & MOTION" }
        Repeater {
            model: [
                {key: "windows", name: "Windows", choices: [{id:"flat",label:"Square"},{id:"soft",label:"Soft corners + shadow"}]},
                {key: "motion", name: "Animations", choices: [{id:"off",label:"Off"},{id:"subtle",label:"Subtle"},{id:"smooth",label:"Smooth"}]},
                {key: "density", name: "Panel density", choices: [{id:"compact",label:"Compact"},{id:"comfortable",label:"Comfortable"}]}
            ]
            RowLayout {
                id: setting
                required property var modelData
                UiLabel { Layout.preferredWidth: 120; text: setting.modelData.name }
                Repeater {
                    model: setting.modelData.choices
                    UiButton {
                        required property var modelData
                        text: modelData.label
                        selected: (root.appearance.desktop || {})[setting.modelData.key] === modelData.id
                        enabled: !DesktopData.busy
                        onClicked: root.act(["desktop", setting.modelData.key, modelData.id])
                    }
                }
            }
        }
        Repeater {
            model: [{key:"gap", name:"Between tiled windows"}, {key:"outer", name:"Around tiled windows"}]
            RowLayout {
                id: gapSetting
                required property var modelData
                Layout.fillWidth: true
                UiLabel { Layout.preferredWidth: 170; text: gapSetting.modelData.name }
                UiSlider {
                    id: gapSlider
                    Layout.fillWidth: true; implicitHeight: 32; from: 0; to: 24; stepSize: 2
                    snapMode: Slider.SnapAlways
                    value: Number((root.appearance.desktop || {})[gapSetting.modelData.key] || 0)
                    enabled: !DesktopData.busy
                    Accessible.name: gapSetting.modelData.name
                    onPressedChanged: if (!pressed) root.act(["desktop", gapSetting.modelData.key, String(Math.round(value / 2) * 2)])
                    Keys.onReleased: event => { if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Home, Qt.Key_End].includes(event.key)) root.act(["desktop", gapSetting.modelData.key, String(Math.round(value / 2) * 2)]) }
                }
                UiLabel { Layout.preferredWidth: 42; text: Math.round(gapSlider.value) + " px" }
            }
        }
        UiLabel { Layout.fillWidth: true; color: Colors.muted; font.pixelSize: 12; text: "Logical pixels. Window style, gaps and motion stay independent of your panel shape and palette." }
    }

}
