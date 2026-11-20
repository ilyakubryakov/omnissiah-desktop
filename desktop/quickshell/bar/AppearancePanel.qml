pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

// Appearance pages of the Control Station: Themes, Panels & windows, Apps & icons
// and Login screen. Long pages are split into tabs by meaning (macOS style).
ColumnLayout {
    id: root
    spacing: Shared.DesktopStyle.px(20)
    readonly property var appearance: DesktopData.appearance
    property string section: "themes"
    property string themeTab: "palette"
    property string panelTab: "layout"
    property string loginTab: "look"
    property string wallpaperVariant: ""
    readonly property var wallpaper: appearance.wallpaper || ({})
    readonly property var desktop: appearance.desktop || ({})
    readonly property string activeVariant: (appearance.palettes.find(p => p.id === appearance.schedule.palette) || {}).mode || "dark"
    readonly property string targetSlot: wallpaper.mode === "variant" ? (wallpaperVariant || activeVariant) : "shared"
    readonly property string selectedWallpaper: wallpaper[targetSlot] || wallpaper.shared || ""
    readonly property int sliderWidth: Shared.DesktopStyle.px(300)
    function title(id) {
        return ({"tesla-day":"Tesla Day", "tesla-night":"Tesla Night", "graphite":"Graphite", "omnissiah":"Omnissiah", "kanagawa-lotus":"Lotus · light", "kanagawa-dragon":"Dragon · dark"})[id] || id.split("-").map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(" ")
    }
    function act(args) { DesktopData.act("appearance", args) }
    // Search targets that live on a tab other than the first: switch to it first.
    // Returns true when a tab changed, so the caller waits for the layout.
    readonly property var targetTabs: ({
        "Light & dark": ["themeTab", "schedule"], "Day palette": ["themeTab", "schedule"],
        "Wallpaper": ["themeTab", "wallpaper"], "Open wallpaper gallery": ["themeTab", "wallpaper"],
        "Saved looks": ["themeTab", "looks"],
        "Panel size": ["panelTab", "look"], "Panel opacity": ["panelTab", "look"], "Rounded corners": ["panelTab", "look"],
        "Panel shape": ["panelTab", "look"], "Group colors": ["panelTab", "look"], "Button accents": ["panelTab", "look"],
        "Windows & motion": ["panelTab", "windows"], "Between tiled windows": ["panelTab", "windows"],
        "UI font": ["panelTab", "text"], "Font size (pt)": ["panelTab", "text"], "UI metrics": ["panelTab", "text"],
        "Spacing unit": ["panelTab", "text"], "Focus ring width": ["panelTab", "text"],
        "Login card": ["loginTab", "card"], "Greeting": ["loginTab", "card"]
    })
    function reveal(target) {
        const tab = targetTabs[target]
        if (!tab || root[tab[0]] === tab[1]) return false
        root[tab[0]] = tab[1]
        return true
    }

    // ---- Themes --------------------------------------------------------------
    Segmented {
        visible: root.section === "themes"
        Layout.alignment: Qt.AlignHCenter
        model: [{id: "palette", title: "Palette"}, {id: "schedule", title: "Light & dark"}, {id: "wallpaper", title: "Wallpaper"}, {id: "looks", title: "Saved looks"}]
        current: root.themeTab
        onChosen: id => root.themeTab = id
    }

    SettingsGroup {
        visible: root.section === "themes" && root.themeTab === "palette"
        title: "Palette"
        footer: "Applies to the panels, terminals, GTK/Qt apps and Chrome. Day / night switching is on the Light & dark tab."
        SettingsRow {
            stacked: true
            GridLayout {
                Layout.fillWidth: true; columns: width < 560 ? 2 : 3
                columnSpacing: Shared.DesktopStyle.px(12); rowSpacing: Shared.DesktopStyle.px(12)
                Repeater {
                    model: root.appearance.palettes
                    Rectangle {
                        id: paletteCard
                        required property var modelData
                        readonly property bool active: root.appearance.schedule.palette === modelData.id
                        Layout.fillWidth: true; implicitHeight: Shared.DesktopStyle.px(84)
                        color: modelData.background
                        radius: Shared.DesktopStyle.radiusSmall
                        border.width: active ? 2 : 1
                        border.color: active || activeFocus || paletteMouse.containsMouse ? modelData.accent : Colors.selection
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
                            anchors.fill: parent; anchors.margins: Shared.DesktopStyle.px(14); spacing: Shared.DesktopStyle.px(8)
                            Rectangle { width: Shared.DesktopStyle.px(32); height: Shared.DesktopStyle.px(4); radius: 2; color: paletteCard.modelData.accent }
                            Text { text: root.title(paletteCard.modelData.id); color: paletteCard.modelData.foreground; font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(15) }
                            Text { text: paletteCard.active ? "Active" : paletteCard.modelData.mode === "light" ? "Light" : "Dark"; color: paletteCard.modelData.accent; font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(11) }
                        }
                        MouseArea { id: paletteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: paletteCard.choose() }
                    }
                }
            }
        }
    }

    SettingsGroup {
        visible: root.section === "themes" && root.themeTab === "schedule"
        title: "Light & dark"
        footer: root.appearance.schedule.next_human && root.appearance.schedule.mode !== "manual"
            ? "Next transition · " + root.appearance.schedule.next_human + (root.appearance.schedule.override_until ? " · manual hold" : "")
            : "Manual keeps the palette you choose until you change it."
        SettingsRow {
            title: "Switch"
            subtitle: "Night light follows the same schedule"
            Segmented {
                model: [{id: "manual", title: "Manual"}, {id: "sun", title: "Sunrise / sunset"}, {id: "fixed", title: "Schedule"}]
                current: root.appearance.schedule.mode || "manual"
                enabled: !DesktopData.busy
                onChosen: id => root.act(["schedule", id])
            }
        }
        Repeater {
            model: ["light", "dark"]
            SettingsRow {
                id: scheduleChoice
                required property string modelData
                readonly property var choices: root.appearance.palettes.filter(p => p.mode === modelData)
                title: modelData === "light" ? "Day palette" : "Night palette"
                SettingCombo {
                    Layout.preferredWidth: Shared.DesktopStyle.px(220)
                    model: scheduleChoice.choices.map(p => root.title(p.id))
                    currentIndex: scheduleChoice.choices.findIndex(p => p.id === root.appearance.schedule[scheduleChoice.modelData + "_palette"])
                    enabled: !DesktopData.busy
                    Accessible.name: scheduleChoice.title
                    onActivated: index => root.act(["schedule-palette", scheduleChoice.modelData, scheduleChoice.choices[index].id])
                }
            }
        }
        Repeater {
            model: root.appearance.schedule.mode === "fixed" ? ["light", "dark"] : []
            SettingsRow {
                id: boundary
                required property string modelData
                title: modelData === "light" ? "Light from" : "Dark from"
                TextField {
                    id: timeField
                    Layout.preferredWidth: Shared.DesktopStyle.px(82)
                    text: root.appearance.schedule[boundary.modelData + "_at"] || ""
                    placeholderText: "HH:MM"
                    validator: RegularExpressionValidator { regularExpression: /([01][0-9]|2[0-3]):[0-5][0-9]/ }
                    color: Colors.foreground; selectionColor: Colors.accent
                    background: Rectangle { radius: Shared.DesktopStyle.radiusSmall; color: Colors.background; border.color: timeField.activeFocus ? Colors.accent : Colors.selection; border.width: 1 }
                    onAccepted: if (acceptableInput) root.act(["time", boundary.modelData, text])
                }
                UiButton { text: "Save"; enabled: timeField.acceptableInput && !DesktopData.busy; onClicked: root.act(["time", boundary.modelData, timeField.text]) }
            }
        }
    }

    SettingsGroup {
        visible: root.section === "themes" && root.themeTab === "wallpaper"
        title: "Wallpaper"
        footer: "Lock screen follows the current wallpaper with blur. The login screen has its own page; boot keeps the dark Mechanicus artwork."
        SettingsRow {
            title: "Use wallpaper"
            Segmented {
                model: [{id: "shared", title: "Same for all themes"}, {id: "variant", title: "Light / dark"}]
                current: root.wallpaper.mode === "variant" ? "variant" : "shared"
                enabled: !DesktopData.busy
                onChosen: id => root.act(["wallpaper-mode", id])
            }
        }
        SettingsRow {
            visible: root.wallpaper.mode === "variant"
            title: "Choose for"
            Segmented {
                model: [{id: "light", title: "Light themes"}, {id: "dark", title: "Dark themes"}]
                current: root.targetSlot
                onChosen: id => root.wallpaperVariant = id
            }
        }
        SettingsRow {
            title: "Image"
            subtitle: root.selectedWallpaper ? root.selectedWallpaper.split("/").pop() : "No image selected"
            UiButton { text: "Open wallpaper gallery"; glyph: "\u{F03E}"; onClicked: DesktopData.showWallpapers(root.targetSlot) }
        }
    }

    AppearancePresets { visible: root.section === "themes" && root.themeTab === "looks" }

    // ---- Panels & windows ----------------------------------------------------
    Segmented {
        visible: root.section === "panels"
        Layout.alignment: Qt.AlignHCenter
        model: [{id: "layout", title: "Layout"}, {id: "look", title: "Panels"}, {id: "windows", title: "Windows"}, {id: "text", title: "Text & metrics"}]
        current: root.panelTab
        onChosen: id => root.panelTab = id
    }

    PanelEditor { visible: root.section === "panels" && root.panelTab === "layout"; Layout.fillWidth: true }

    SettingsGroup {
        visible: root.section === "panels" && root.panelTab === "look"
        title: "Panel shape"
        footer: "Panel shape applies to both bars. Islands join when tiled windows fill this display, or a window is maximized; floating windows keep islands."
        SettingsRow {
            stacked: true
            GridLayout {
                columns: width < 560 ? 2 : 4
                Layout.fillWidth: true; columnSpacing: Shared.DesktopStyle.px(12); rowSpacing: Shared.DesktopStyle.px(12)
                Repeater {
                    model: PanelStyle.presets
                    Rectangle {
                        id: styleCard
                        required property var modelData
                        readonly property bool active: PanelStyle.style === modelData.id
                        Layout.fillWidth: true; implicitHeight: Shared.DesktopStyle.px(124)
                        radius: Shared.DesktopStyle.radiusSmall
                        color: Colors.background
                        border.width: active ? 2 : 1
                        border.color: active || activeFocus ? Colors.accent : Colors.selection
                        activeFocusOnTab: true
                        enabled: !DesktopData.busy
                        function choose() { root.act(["panels", modelData.id]) }
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.name + " panels"
                        Accessible.onPressAction: choose()
                        Keys.onReturnPressed: choose()
                        Keys.onSpacePressed: choose()
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Shared.DesktopStyle.px(10) }
                            height: Shared.DesktopStyle.px(54); color: Colors.darkBackground; clip: true; radius: Shared.DesktopStyle.px(4)
                            Repeater {
                                model: [true, false]
                                Rectangle {
                                    required property bool modelData
                                    readonly property bool flat: styleCard.modelData.id === "flat"
                                    readonly property bool floating: styleCard.modelData.id === "floating"
                                    x: flat ? 0 : 7; width: styleCard.modelData.id === "islands" ? parent.width * 0.35 : parent.width - 2 * x; height: Shared.DesktopStyle.px(9)
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
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Shared.DesktopStyle.px(10) }
                            spacing: Shared.DesktopStyle.px(4)
                            UiLabel { width: parent.width; text: styleCard.modelData.name; font.pixelSize: Shared.DesktopStyle.px(13); font.weight: styleCard.active ? Font.DemiBold : Font.Normal }
                            UiLabel { width: parent.width; text: styleCard.modelData.detail; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11); elide: Text.ElideRight; wrapMode: Text.NoWrap }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: styleCard.choose() }
                    }
                }
            }
        }
        SettingsRow {
            title: "Filled workspace"
            subtitle: "The solid panel follows the shared theme of the focused tiled app"
            Segmented {
                model: [{id: "on", title: "Adapt panels"}, {id: "off", title: "Keep my style"}]
                current: ShellLayout.adaptivePanels ? "on" : "off"
                onChosen: id => ShellLayout.change(["adaptive-panels", id])
            }
        }
    }

    LayoutSettings { visible: root.section === "panels" && root.panelTab === "look"; Layout.fillWidth: true }

    SettingsGroup {
        visible: root.section === "panels" && root.panelTab === "windows"
        title: "Windows & motion"
        Repeater {
            model: [
                {key: "windows", name: "Windows", choices: [{id:"flat",title:"Square"},{id:"soft",title:"Soft corners + shadow"}]},
                {key: "motion", name: "Animations", choices: [{id:"off",title:"Off"},{id:"subtle",title:"Subtle"},{id:"smooth",title:"Smooth"}]},
                {key: "density", name: "Panel density", choices: [{id:"compact",title:"Compact"},{id:"comfortable",title:"Comfortable"}]}
            ]
            SettingsRow {
                id: setting
                required property var modelData
                title: modelData.name
                Segmented {
                    model: setting.modelData.choices
                    current: root.desktop[setting.modelData.key] || ""
                    enabled: !DesktopData.busy
                    onChosen: id => root.act(["desktop", setting.modelData.key, id])
                }
            }
        }
    }

    SettingsGroup {
        visible: root.section === "panels" && root.panelTab === "windows"
        title: "Gaps"
        footer: "Logical pixels. Window style, gaps and motion stay independent of your panel shape and palette."
        Repeater {
            model: [{key:"gap", name:"Between tiled windows"}, {key:"outer", name:"Around tiled windows"}]
            SettingsRow {
                id: gapSetting
                required property var modelData
                title: modelData.name
                SettingSlider {
                    Layout.preferredWidth: root.sliderWidth; from: 0; to: 24; stepSize: 2
                    value: Number(root.desktop[gapSetting.modelData.key] || 0)
                    format: v => Math.round(v) + " px"
                    enabled: !DesktopData.busy
                    onCommitted: v => root.act(["desktop", gapSetting.modelData.key, String(Math.round(v / 2) * 2)])
                }
            }
        }
    }

    SettingsGroup {
        visible: root.section === "panels" && root.panelTab === "text"
        title: "Text"
        footer: "Larger fonts can increase the minimum control height. GTK4/libadwaita and custom application interfaces may retain their own layout. Some apps need reopening."
        SettingsRow {
            title: "UI font"
            UiComboBox {
                readonly property string chosenFont: root.desktop.ui_font || Shared.DesktopStyle.fontFamily
                Layout.preferredWidth: Shared.DesktopStyle.px(220)
                model: Array.from(new Set([chosenFont, "Inter", "Noto Sans"]))
                currentIndex: model.indexOf(chosenFont)
                enabled: !DesktopData.busy
                onActivated: root.act(["desktop", "ui_font", currentText])
            }
        }
        SettingsRow {
            title: "Font size (pt)"
            SettingSlider {
                Layout.preferredWidth: root.sliderWidth; from: 8; to: 20; stepSize: 1
                value: Number(root.desktop.ui_font_size || ((root.appearance.metrics || {}).settings || {}).font_size || 0)
                format: v => String(Math.round(v))
                enabled: !DesktopData.busy
                onCommitted: v => root.act(["desktop", "ui_font_size", String(Math.round(v))])
            }
        }
    }

    SettingsGroup {
        visible: root.section === "panels" && root.panelTab === "text"
        title: "UI metrics"
        footer: "Native keeps the current toolkit geometry. Unified shares control metrics across GTK and the shell and follows Square/Soft. Breeze keeps its own widget geometry."
        SettingsRow {
            title: "Control geometry"
            Segmented {
                model: [{id: "native", title: "Native"}, {id: "unified", title: "Unified"}]
                current: root.desktop.ui_geometry || "native"
                enabled: !DesktopData.busy
                onChosen: id => root.act(["desktop", "ui_geometry", id])
            }
        }
        Repeater {
            model: [
                {key: "ui_radius_small", token: "radius_small", name: "Small radius", low: 0, high: 24},
                {key: "ui_radius_control", token: "radius_control", name: "Control radius", low: 0, high: 24},
                {key: "ui_radius_card", token: "radius_card", name: "Card radius", low: 0, high: 32},
                {key: "ui_radius_window", token: "radius_window", name: "Window radius (Soft)", low: 0, high: 24},
                {key: "ui_space_unit", token: "space_unit", name: "Spacing unit", low: 2, high: 8},
                {key: "ui_control_height", token: "control_height", name: "Control height", low: 28, high: 56},
                {key: "ui_focus_width", token: "focus_width", name: "Focus ring width", low: 1, high: 3}
            ]
            SettingsRow {
                id: metricSetting
                required property var modelData
                title: modelData.name
                SettingSlider {
                    Layout.preferredWidth: root.sliderWidth
                    from: metricSetting.modelData.low; to: metricSetting.modelData.high; stepSize: 1
                    value: Number(root.desktop[metricSetting.modelData.key]
                        || (((root.appearance.metrics || {}).settings || {})[metricSetting.modelData.token]) || 0)
                    format: v => String(Math.round(v))
                    enabled: !DesktopData.busy
                    onCommitted: v => root.act(["desktop", metricSetting.modelData.key, String(Math.round(v))])
                }
            }
        }
    }

    // ---- Apps & icons --------------------------------------------------------
    ApplicationSettings { visible: root.section === "apps"; Layout.fillWidth: true }

    // ---- Login screen (ReGreet) ------------------------------------------------
    // Applied by a system service; shown at the next login.
    ColumnLayout {
        id: login
        visible: root.section === "login"
        Layout.fillWidth: true
        spacing: Shared.DesktopStyle.px(20)
        readonly property var greeter: root.appearance.greeter || ({})
        readonly property var prefs: greeter.prefs || ({})
        readonly property var status: greeter.status || ({})
        readonly property string paletteId: prefs.palette === "desktop" ? root.appearance.schedule.palette : (prefs.palette || "omnissiah")
        readonly property var colors: root.appearance.palettes.find(p => p.id === paletteId) || ({ background: Colors.background, accent: Colors.accent, foreground: Colors.foreground })
        // The system service renders asynchronously; re-read a few times to show its result.
        property int pendingReads: 0
        function set(key, value) { root.act(["greeter", key, String(value)]); pendingReads = 4 }
        Timer { interval: 1500; repeat: true; running: login.pendingReads > 0; onTriggered: { DesktopData.readAppearance(); login.pendingReads-- } }

        UiLabel {
            visible: login.greeter.available === false
            Layout.fillWidth: true; color: Colors.yellow
            text: "This machine has no login-screen service yet. Rebuild the system to enable these settings."
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(width * 9 / 16)
            Layout.maximumHeight: Shared.DesktopStyle.px(300)
            radius: Shared.DesktopStyle.radiusCard
            color: Colors.darkBackground
            clip: true
            Image {
                anchors.fill: parent
                source: login.greeter.preview || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Item {
                id: card
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.42, 300); height: width * 0.62
                readonly property real cornerRadius: (login.prefs.radius || 0) * width / 480
                Rectangle { anchors.fill: parent; radius: card.cornerRadius; color: login.colors.background; opacity: (login.prefs.cardOpacity || 92) / 100 }
                Rectangle {
                    anchors.fill: parent; radius: card.cornerRadius; color: "transparent"; opacity: 0.6
                    visible: login.prefs.border !== false; border.width: 1; border.color: login.colors.accent
                }
                Column {
                    anchors.centerIn: parent; spacing: Shared.DesktopStyle.px(8)
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(new Date(), "HH:mm"); color: login.colors.foreground; font.family: "Inter"; font.pixelSize: Shared.DesktopStyle.px(26) }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, 260); elide: Text.ElideRight
                        text: login.prefs.greeting || ""; color: login.colors.foreground; font.family: "Inter"; font.pixelSize: Shared.DesktopStyle.px(11)
                    }
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: Shared.DesktopStyle.px(150); height: Shared.DesktopStyle.px(22); radius: Shared.DesktopStyle.px(3); color: Qt.darker(login.colors.background, 1.25); border.width: 1; border.color: login.colors.accent }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            UiLabel {
                Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(12); wrapMode: Text.Wrap
                color: login.status.ok === false ? Colors.red : Colors.muted
                text: login.status.ok === false ? "Not applied · " + login.status.error
                    : login.status.appliedAt ? "Ready for the next login · rendered " + Qt.formatDateTime(new Date(login.status.appliedAt * 1000), "dd MMM HH:mm")
                    : "Waiting for the first render"
            }
            UiButton {
                text: "Preview"; glyph: "\u{F0208}"
                enabled: !DesktopData.busy && login.status.ok === true
                onClicked: root.act(["greeter-preview"])
            }
            UiButton { text: "Reset login screen"; enabled: !DesktopData.busy; onClicked: login.set("reset", "all") }
        }

        Segmented {
            Layout.alignment: Qt.AlignHCenter
            model: [{id: "look", title: "Colors & background"}, {id: "card", title: "Card & text"}]
            current: root.loginTab
            onChosen: id => root.loginTab = id
        }

        SettingsGroup {
            visible: root.loginTab === "look"
            title: "Palette"
            SettingsRow {
                title: "Same as desktop"
                subtitle: "Follows palette changes, including the day / night schedule"
                Segmented {
                    model: [{id: "on", title: "On"}, {id: "off", title: "Off"}]
                    current: login.prefs.palette === "desktop" ? "on" : "off"
                    enabled: !DesktopData.busy
                    onChosen: id => login.set("palette", id === "on" ? "desktop" : (root.appearance.schedule.palette || "omnissiah"))
                }
            }
            SettingsRow {
                visible: login.prefs.palette !== "desktop"
                stacked: true
                GridLayout {
                    Layout.fillWidth: true; columns: width < 560 ? 3 : 6
                    columnSpacing: Shared.DesktopStyle.px(8); rowSpacing: Shared.DesktopStyle.px(8)
                    Repeater {
                        model: root.appearance.palettes
                        Rectangle {
                            id: greeterPalette
                            required property var modelData
                            Layout.fillWidth: true; implicitHeight: Shared.DesktopStyle.px(50)
                            color: modelData.background
                            radius: Shared.DesktopStyle.radiusSmall
                            border.width: login.prefs.palette === modelData.id ? 2 : 1
                            border.color: login.prefs.palette === modelData.id || greeterMouse.containsMouse ? modelData.accent : Colors.selection
                            Accessible.role: Accessible.Button
                            Accessible.name: "Login palette " + root.title(modelData.id)
                            Column {
                                anchors.fill: parent; anchors.margins: Shared.DesktopStyle.px(10); spacing: Shared.DesktopStyle.px(6)
                                Rectangle { width: Shared.DesktopStyle.px(22); height: Shared.DesktopStyle.px(3); color: greeterPalette.modelData.accent }
                                Text { text: root.title(greeterPalette.modelData.id); color: greeterPalette.modelData.foreground; font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(12); elide: Text.ElideRight; width: parent.width }
                            }
                            MouseArea { id: greeterMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !DesktopData.busy; onClicked: login.set("palette", greeterPalette.modelData.id) }
                        }
                    }
                }
            }
        }

        SettingsGroup {
            visible: root.loginTab === "look"
            title: "Background"
            SettingsRow {
                title: "Image"
                subtitle: login.prefs.wallpaper === "image" && login.prefs.image ? login.prefs.image.split("/").pop() : ""
                Segmented {
                    model: [{id: "desktop", title: "Desktop wallpaper"}, {id: "artwork", title: "Mechanicus artwork"}, {id: "image", title: login.prefs.image ? "Own image" : "Choose image…"}]
                    current: login.prefs.wallpaper || ""
                    enabled: !DesktopData.busy
                    onChosen: id => id !== "image" ? login.set("wallpaper", id)
                        : login.prefs.image && login.prefs.wallpaper !== "image" ? login.set("wallpaper", "image") : DesktopData.showWallpapers("greeter")
                }
                UiButton { visible: !!login.prefs.image; text: "Change…"; enabled: !DesktopData.busy; onClicked: DesktopData.showWallpapers("greeter") }
            }
            SettingsRow {
                title: "Blur"
                SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 0; to: 40; stepSize: 1; value: login.prefs.blur || 0; format: v => v ? String(Math.round(v)) : "Off"; onCommitted: v => login.set("blur", Math.round(v)) }
            }
            SettingsRow {
                title: "Darken"
                SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 0; to: 70; stepSize: 5; value: login.prefs.dim || 0; format: v => Math.round(v) + "%"; onCommitted: v => login.set("dim", Math.round(v)) }
            }
        }

        SettingsGroup {
            visible: root.loginTab === "card"
            title: "Login card"
            SettingsRow {
                title: "Card opacity"
                SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 60; to: 100; stepSize: 1; value: login.prefs.cardOpacity || 92; format: v => Math.round(v) + "%"; onCommitted: v => login.set("cardOpacity", Math.round(v)) }
            }
            SettingsRow {
                title: "Corner radius"
                SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 0; to: 24; stepSize: 1; value: login.prefs.radius || 0; format: v => Math.round(v) + " px"; onCommitted: v => login.set("radius", Math.round(v)) }
            }
            SettingsRow {
                title: "Text size"
                SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 12; to: 22; stepSize: 1; value: login.prefs.fontSize || 16; format: v => Math.round(v) + " pt"; onCommitted: v => login.set("fontSize", Math.round(v)) }
            }
            SettingsRow {
                title: "Accent border"
                Segmented {
                    model: [{id: "on", title: "On"}, {id: "off", title: "Off"}]
                    current: login.prefs.border === false ? "off" : "on"
                    enabled: !DesktopData.busy
                    onChosen: id => login.set("border", id)
                }
            }
        }

        SettingsGroup {
            visible: root.loginTab === "card"
            title: "Text and clock"
            footer: "Changes apply at the next login. If a custom look ever fails to start, the login screen falls back to the built-in Mechanicus design. Boot menu and splash keep their own artwork."
            SettingsRow {
                title: "Greeting"
                TextField {
                    id: greetingField
                    Layout.preferredWidth: Shared.DesktopStyle.px(280)
                    text: login.prefs.greeting || ""
                    maximumLength: 80
                    placeholderText: "Shown above the login form"
                    color: Colors.foreground; selectionColor: Colors.accent
                    background: Rectangle { radius: Shared.DesktopStyle.radiusSmall; color: Colors.background; border.color: greetingField.activeFocus ? Colors.accent : Colors.selection; border.width: 1 }
                    onAccepted: login.set("greeting", text)
                }
                UiButton { text: "Save"; enabled: !DesktopData.busy && greetingField.text !== (login.prefs.greeting || ""); onClicked: login.set("greeting", greetingField.text) }
            }
            SettingsRow {
                title: "Clock"
                Segmented {
                    model: [{id: "date", title: "Time and date"}, {id: "time", title: "Time only"}, {id: "seconds", title: "With seconds"}]
                    current: login.prefs.clock || "date"
                    enabled: !DesktopData.busy
                    onChosen: id => login.set("clock", id)
                }
            }
            SettingsRow {
                title: "User and session"
                Segmented {
                    model: [{id: "on", title: "Show pickers"}, {id: "off", title: "Last used only"}]
                    current: login.prefs.showSelectors === false ? "off" : "on"
                    enabled: !DesktopData.busy
                    onChosen: id => login.set("showSelectors", id)
                }
            }
        }
    }
}
