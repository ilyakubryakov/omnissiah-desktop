//@ pragma UseQApplication
// Tray context menus are platform menus, which need QApplication.
// Started by oninix-panel.service using the packaged shell configuration.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "shared" as Shared
import "bar"

ShellRoot {
    id: shell
    function openPanel(page) {
        PopupState.close()
        if (page === "launchpad") { calendar.opened = false; launchpad.toggle() }
        else if (page === "calendar") calendar.toggle()
        else if (page === "notifications") { calendar.opened = false; notifications.toggle() }
        else if (page === "notebook") { calendar.opened = false; notebook.toggle() }
        else { calendar.opened = false; desktop.show(page) }
    }

    readonly property var workScreens: Quickshell.screens

    Binding { target: Shared.DesktopStyle; property: "fullscreen"; value: (Hypr.active.fullscreen || 0) >= 2 }

    AudioOsd {}
    DictationOsd {}
    WindowSwitcher {}
    MonthCalendar { id: calendar; cal: agenda; onAccountsRequested: desktop.show("calendars") }
    CalData { id: agenda }
    DesktopPanel { id: desktop; cal: agenda; onCalendarRequested: calendar.toggle(); onGuideRequested: cheat.open(); onToolRequested: tool => (tool === "overview" ? windowsTool : clipboardTool).toggle() }
    CheatPanel { id: cheat; screenTarget: Shared.Screens.main }
    // Tools outside the settings window (macOS: Mission Control, a clipboard manager).
    QuickKeys { id: quickKeys }
    IpcHandler {
        target: "keys"
        function toggle(): void { quickKeys.toggle() }
    }
    ToolOverlay {
        id: windowsTool
        title: "Windows"
        Loader { Layout.fillWidth: true; active: windowsTool.opened; sourceComponent: WindowOverview { onChosen: windowsTool.close() } }
    }
    ToolOverlay {
        id: clipboardTool
        title: "Clipboard"
        cardWidth: Shared.DesktopStyle.px(760)
        onOpenedChanged: { DesktopData.clipboardOpen = opened; if (opened) DesktopData.refresh() }
        Loader { Layout.fillWidth: true; active: clipboardTool.opened; sourceComponent: ClipboardPanel {} }
    }
    IpcHandler {
        target: "cheat"
        function toggle(): void { cheat.toggle() }
        function show(): void { cheat.open() }
        function hide(): void { cheat.close() }
    }
    Launchpad { id: launchpad }
    WallpaperPicker {}
    DesktopMenu { screens: shell.workScreens; onOpenPanel: page => shell.openPanel(page) }
    Notebook { id: notebook }
    NotificationDrawer { id: notifications }
    ActionNotifications {}
    Connections { target: DesktopData; function onNotificationsRequested() { notifications.show() } }

    Variants {
        model: workScreens
        TopBar { cal: agenda; onOpenPanel: page => shell.openPanel(page); onOpenCalendar: calendar.toggle() }
    }
    Variants {
        model: workScreens
        BottomBar {
            cal: agenda
            onOpenCalendar: calendar.toggle()
            onOpenPanel: page => shell.openPanel(page)
        }
    }
}
