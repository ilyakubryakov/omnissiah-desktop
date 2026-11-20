pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

// Panel size, surface and accent colors, as System Settings style groups.
ColumnLayout {
    id: root
    spacing: Shared.DesktopStyle.px(20)
    readonly property int sliderWidth: Shared.DesktopStyle.px(300)
    readonly property var backgrounds: ["plain", "accent", "wallpaper"]
    readonly property var buttonModes: ["neutral", "theme", "groups"]

    SettingsGroup {
        title: "Panel size"
        footer: "Centered on each display. Narrow screens keep enough room for controls."
        SettingsRow {
            title: "Length"
            SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 60; to: 100; stepSize: 1; value: PanelStyle.widthPercent; format: v => Math.round(v) + "%"; onCommitted: v => ShellLayout.change(["panel-width", String(Math.round(v))]) }
        }
        SettingsRow {
            title: "Height"
            SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 28; to: 56; stepSize: 2; value: PanelStyle.barHeight; format: v => Math.round(v) + " px"; onCommitted: v => ShellLayout.change(["panel-height", String(Math.round(v))]) }
        }
        SettingsRow {
            title: "Rounded corners"
            SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 0; to: 24; stepSize: 2; value: ShellLayout.state.panelRadius ?? PanelStyle.cornerRadius; format: v => v === 0 ? "Square" : Math.round(v) + " px"; onCommitted: v => ShellLayout.change(["panel-radius", String(Math.round(v))]) }
        }
    }

    SettingsGroup {
        title: "Panel surface"
        footer: ShellLayout.panelBackground !== "wallpaper" ? ""
            : ShellLayout.wallpaperColorsReady
                ? "Panel and group colors follow your wallpaper, balanced for readable text. Filled workspaces still follow the application theme."
                : "Choose a wallpaper to tint the panels. The theme background is used while its colors are unavailable."
        SettingsRow {
            title: "Background"
            SettingCombo {
                Layout.preferredWidth: Shared.DesktopStyle.px(220)
                model: ["Theme background", "Soft accent tint", "Wallpaper tint"]
                currentIndex: root.backgrounds.indexOf(ShellLayout.panelBackground)
                onActivated: ShellLayout.change(["panel-background", root.backgrounds[currentIndex]])
            }
        }
        SettingsRow {
            title: "Panel opacity"
            SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 40; to: 100; stepSize: 5; value: ShellLayout.panelOpacity * 100; format: v => Math.round(v) + "%"; onCommitted: v => ShellLayout.change(["panel-opacity", String(Math.round(v))]) }
        }
    }

    SettingsGroup {
        title: "Group colors"
        footer: ShellLayout.panelBackground === "wallpaper"
            ? "Group colors come from the wallpaper. Your manual choices return with Theme background or Soft accent tint."
            : "Subtle backgrounds keep icons readable. Colors follow the active light or dark palette."
        Repeater {
            model: ShellLayout.panelBackground !== "wallpaper" ? ShellLayout.groups : []
            SettingsRow {
                id: groupSetting
                required property var modelData
                title: modelData.name
                Rectangle { width: Shared.DesktopStyle.px(12); height: Shared.DesktopStyle.px(12); radius: Shared.DesktopStyle.px(6); color: ShellLayout.toneColor(ShellLayout.toneName(groupSetting.modelData.id)) }
                SettingCombo {
                    Layout.preferredWidth: Shared.DesktopStyle.px(180)
                    model: ShellLayout.tones.map(t => t.name)
                    currentIndex: ShellLayout.tones.findIndex(t => t.id === ShellLayout.toneName(groupSetting.modelData.id))
                    onActivated: ShellLayout.change(["group-tone", groupSetting.modelData.id, ShellLayout.tones[currentIndex].id])
                }
            }
        }
        SettingsRow {
            title: "Tint strength"
            SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 0; to: 30; stepSize: 1; value: ShellLayout.groupStrength * 100; format: v => Math.round(v) + "%"; onCommitted: v => ShellLayout.change(["group-strength", String(Math.round(v))]) }
        }
    }

    SettingsGroup {
        title: "Button accents"
        footer: "Color the icons and fine button outlines. Labels stay readable, and warning colors keep their meaning. Independent of the panel background."
        SettingsRow {
            title: "Accents"
            Segmented {
                model: [{id: "neutral", title: "Neutral"}, {id: "theme", title: "Theme accent"}, {id: "groups", title: "By group"}]
                current: ShellLayout.buttonMode
                onChosen: id => ShellLayout.change(["button-mode", id])
            }
        }
        SettingsRow {
            visible: ShellLayout.buttonMode !== "neutral"
            title: "Color strength"
            SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 0; to: 100; stepSize: 1; value: ShellLayout.buttonStrength * 100; format: v => Math.round(v) + "%"; onCommitted: v => ShellLayout.change(["button-strength", String(Math.round(v))]) }
        }
        Repeater {
            model: ShellLayout.buttonMode === "groups" ? ShellLayout.groups : []
            SettingsRow {
                id: buttonSetting
                required property var modelData
                title: modelData.name
                Rectangle { width: Shared.DesktopStyle.px(12); height: Shared.DesktopStyle.px(12); radius: Shared.DesktopStyle.px(6); color: ShellLayout.buttonColor(buttonSetting.modelData.id) }
                SettingCombo {
                    Layout.preferredWidth: Shared.DesktopStyle.px(180)
                    model: ShellLayout.tones.map(t => t.name)
                    currentIndex: ShellLayout.tones.findIndex(t => t.id === ShellLayout.buttonTone(buttonSetting.modelData.id))
                    onActivated: ShellLayout.change(["button-tone", buttonSetting.modelData.id, ShellLayout.tones[currentIndex].id])
                }
            }
        }
    }
    UiLabel { visible: ShellLayout.error !== ""; text: ShellLayout.error; color: Colors.red; Layout.fillWidth: true; wrapMode: Text.WordWrap }
}
