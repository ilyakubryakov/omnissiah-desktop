pragma Singleton
import Quickshell

// Routes the Control Center hotkey to the controls chip on the main screen. With
// no such chip (removed from the panels) the hotkey falls back to the settings.
Singleton {
    property int chips: 0
    signal toggleRequested()
    function toggle() {
        if (chips <= 0) return false
        toggleRequested()
        return true
    }
}
