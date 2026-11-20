pragma Singleton
import Quickshell
Singleton {
    property var current: null
    function claim(card, explicit) {
        if (current && current !== card && current.opened && current.pinned && !explicit) return false
        if (current && current !== card) current.retire()
        current = card
        return true
    }
    function close() { if (current) current.dismiss(); current = null }
}
