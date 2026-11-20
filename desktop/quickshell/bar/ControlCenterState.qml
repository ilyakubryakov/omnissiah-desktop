pragma Singleton
import Quickshell

Singleton {
    property int chips: 0
    signal toggleRequested()
    function toggle() {
        if (chips <= 0) return false
        toggleRequested()
        return true
    }
}
