import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: 12
    UiLabel { text: "PANEL SIZE"; font.pixelSize: 12; font.letterSpacing: 2; color: Colors.muted }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "Length"; Layout.preferredWidth: 130 }
        UiSlider {
            id: lengthSlider
            Layout.fillWidth: true; from: 60; to: 100; stepSize: 1
            value: PanelStyle.widthPercent
            Accessible.name: "Panel length"
            onMoved: if (!pressed) ShellLayout.change(["panel-width", String(Math.round(value))])
            onPressedChanged: if (!pressed) ShellLayout.change(["panel-width", String(Math.round(value))])
        }
        UiLabel { text: Math.round(lengthSlider.value) + "%"; Layout.preferredWidth: 46 }
    }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "Height"; Layout.preferredWidth: 130 }
        UiSlider {
            id: heightSlider
            Layout.fillWidth: true; from: 28; to: 56; stepSize: 2
            value: PanelStyle.barHeight
            Accessible.name: "Panel height"
            onMoved: if (!pressed) ShellLayout.change(["panel-height", String(Math.round(value))])
            onPressedChanged: if (!pressed) ShellLayout.change(["panel-height", String(Math.round(value))])
        }
        UiLabel { text: Math.round(heightSlider.value) + " px"; Layout.preferredWidth: 46 }
    }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "Rounded corners"; Layout.preferredWidth: 130 }
        UiSlider {
            id: cornerSlider
            Layout.fillWidth: true; from: 0; to: 24; stepSize: 2
            value: ShellLayout.state.panelRadius ?? PanelStyle.cornerRadius
            Accessible.name: "Panel corner radius"
            onMoved: if (!pressed) ShellLayout.change(["panel-radius", String(Math.round(value))])
            onPressedChanged: if (!pressed) ShellLayout.change(["panel-radius", String(Math.round(value))])
        }
        UiLabel { text: cornerSlider.value === 0 ? "Square" : Math.round(cornerSlider.value) + " px"; Layout.preferredWidth: 62 }
    }
    UiLabel { text: "Centered on each display. Narrow screens keep enough room for controls."; font.pixelSize: 12; color: Colors.muted; Layout.fillWidth: true }
    UiLabel { text: "PANEL SURFACE"; font.pixelSize: 12; font.letterSpacing: 2; color: Colors.muted }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "Background"; Layout.preferredWidth: 130 }
        SettingCombo {
            model: ["Theme background", "Soft accent tint", "Wallpaper tint"]
            currentIndex: ["plain", "accent", "wallpaper"].indexOf(ShellLayout.panelBackground)
            onActivated: ShellLayout.change(["panel-background", ["plain", "accent", "wallpaper"][currentIndex]])
        }
    }
    UiLabel {
        visible: ShellLayout.panelBackground === "wallpaper"
        Layout.fillWidth: true; font.pixelSize: 12; color: Colors.muted; wrapMode: Text.WordWrap
        text: ShellLayout.wallpaperColorsReady
            ? "Panel and group colors follow your wallpaper, balanced for readable text. Filled workspaces still follow the application theme."
            : "Choose a wallpaper to tint the panels. The theme background is used while its colors are unavailable."
    }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "Panel opacity"; Layout.preferredWidth: 130 }
        UiSlider {
            id: panelOpacity
            Layout.fillWidth: true
            from: 40; to: 100; stepSize: 5
            value: ShellLayout.panelOpacity * 100
            onPressedChanged: if (!pressed) ShellLayout.change(["panel-opacity", String(Math.round(value))])
            Keys.onReleased: event => { if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Home, Qt.Key_End].includes(event.key)) ShellLayout.change(["panel-opacity", String(Math.round(value))]) }
        }
        UiLabel { text: Math.round(panelOpacity.value) + "%"; Layout.preferredWidth: 40 }
    }
    UiLabel { text: "GROUP COLORS"; font.pixelSize: 12; font.letterSpacing: 2; color: Colors.muted; Layout.topMargin: 8 }
    UiLabel { Layout.fillWidth: true; text: ShellLayout.panelBackground === "wallpaper" ? "Group colors come from the wallpaper. Your manual choices return with Theme background or Soft accent tint." : "Subtle backgrounds keep icons readable. Colors follow the active light or dark palette."; color: Colors.muted; font.pixelSize: 12; wrapMode: Text.WordWrap }
    GridLayout {
        visible: ShellLayout.panelBackground !== "wallpaper"
        columns: 2
        Layout.fillWidth: true
        columnSpacing: 20; rowSpacing: 8
        Repeater {
            model: ShellLayout.groups
            RowLayout {
                id: groupSetting
                required property var modelData
                Layout.fillWidth: true
                Rectangle { width: 12; height: 12; radius: 6; color: ShellLayout.toneColor(ShellLayout.toneName(groupSetting.modelData.id)) }
                UiLabel { text: groupSetting.modelData.name; Layout.preferredWidth: 120; font.pixelSize: 12 }
                SettingCombo {
                    Layout.fillWidth: true
                    model: ShellLayout.tones.map(t => t.name)
                    currentIndex: ShellLayout.tones.findIndex(t => t.id === ShellLayout.toneName(groupSetting.modelData.id))
                    onActivated: ShellLayout.change(["group-tone", groupSetting.modelData.id, ShellLayout.tones[currentIndex].id])
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "Tint strength"; Layout.preferredWidth: 130 }
        UiSlider {
            id: strength
            Layout.fillWidth: true
            from: 0; to: 30; stepSize: 1
            value: ShellLayout.groupStrength * 100
            Accessible.name: "Group tint strength"
            onPressedChanged: if (!pressed) ShellLayout.change(["group-strength", String(Math.round(value))])
            Keys.onReleased: event => { if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Home, Qt.Key_End].includes(event.key)) ShellLayout.change(["group-strength", String(Math.round(value))]) }
        }
        UiLabel { text: Math.round(strength.value) + "%"; Layout.preferredWidth: 40 }
    }
    UiLabel { text: "BUTTON ACCENTS"; font.pixelSize: 12; font.letterSpacing: 2; color: Colors.muted; Layout.topMargin: 8 }
    UiLabel { Layout.fillWidth: true; text: "Color the icons and fine button outlines. Labels stay readable, and warning colors keep their meaning. Independent of the panel background."; color: Colors.muted; font.pixelSize: 12 }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "Accents"; Layout.preferredWidth: 130 }
        SettingCombo {
            model: ["Neutral", "Theme accent", "By group"]
            currentIndex: ["neutral", "theme", "groups"].indexOf(ShellLayout.buttonMode)
            onActivated: ShellLayout.change(["button-mode", ["neutral", "theme", "groups"][currentIndex]])
        }
    }
    RowLayout {
        visible: ShellLayout.buttonMode !== "neutral"
        Layout.fillWidth: true
        UiLabel { text: "Color strength"; Layout.preferredWidth: 130 }
        UiSlider {
            id: buttonStrength
            Layout.fillWidth: true; from: 0; to: 100; stepSize: 1
            value: ShellLayout.buttonStrength * 100
            Accessible.name: "Button accent strength"
            onMoved: if (!pressed) ShellLayout.change(["button-strength", String(Math.round(value))])
            onPressedChanged: if (!pressed) ShellLayout.change(["button-strength", String(Math.round(value))])
        }
        UiLabel { text: Math.round(buttonStrength.value) + "%"; Layout.preferredWidth: 40 }
    }
    GridLayout {
        visible: ShellLayout.buttonMode === "groups"
        columns: 2; Layout.fillWidth: true; columnSpacing: 20; rowSpacing: 8
        Repeater {
            model: ShellLayout.groups
            RowLayout {
                id: buttonSetting
                required property var modelData
                Layout.fillWidth: true
                Rectangle { width: 12; height: 12; radius: 6; color: ShellLayout.buttonColor(buttonSetting.modelData.id) }
                UiLabel { text: buttonSetting.modelData.name; Layout.preferredWidth: 120; font.pixelSize: 12 }
                SettingCombo {
                    Layout.fillWidth: true
                    model: ShellLayout.tones.map(t => t.name)
                    currentIndex: ShellLayout.tones.findIndex(t => t.id === ShellLayout.buttonTone(buttonSetting.modelData.id))
                    onActivated: ShellLayout.change(["button-tone", buttonSetting.modelData.id, ShellLayout.tones[currentIndex].id])
                }
            }
        }
    }
    UiLabel { visible: ShellLayout.error !== ""; text: ShellLayout.error; color: Colors.red; Layout.fillWidth: true; wrapMode: Text.WordWrap }
}
