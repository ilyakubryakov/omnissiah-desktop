//@ pragma UseQApplication

import QtQuick
import Quickshell
import "shared" as Shared
import "bar"

ShellRoot {
    id: station
    function openPanel(page) {
        PopupState.close()
        if (page === "launchpad") { calendar.opened = false; launchpad.toggle() }
        else if (page === "calendar") calendar.toggle()
        else if (page === "notifications") { calendar.opened = false; notifications.toggle() }
        else if (page === "notebook") { calendar.opened = false; notebook.toggle() }
        else { calendar.opened = false; desktop.show(page) }
    }

    readonly property var workScreens: Quickshell.screens.filter(s => s.name !== Shared.Screens.output("edge"))

    Binding { target: Shared.DesktopStyle; property: "fullscreen"; value: (Hypr.active.fullscreen || 0) >= 2 }

    AudioOsd {}
    WindowSwitcher {}
    MonthCalendar { id: calendar; cal: agenda; onAccountsRequested: desktop.show("calendars") }
    CalData { id: agenda }
    DesktopPanel { id: desktop; cal: agenda; onCalendarRequested: calendar.toggle() }
    Launchpad { id: launchpad }
    WallpaperPicker {}
    Notebook { id: notebook }
    NotificationDrawer { id: notifications }
    Connections { target: DesktopData; function onNotificationsRequested() { notifications.show() } }

    Variants {
        model: workScreens
        TopBar { cal: agenda; onOpenPanel: page => station.openPanel(page); onOpenCalendar: calendar.toggle() }
    }
    Variants {
        model: workScreens
        BottomBar {
            cal: agenda
            onOpenCalendar: calendar.toggle()
            onOpenPanel: page => station.openPanel(page)
        }
    }
}
