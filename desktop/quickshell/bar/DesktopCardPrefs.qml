pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool loaded: false
    property var cards: ({})
    property string error: ""

    function update(id, patch) {
        if (!loaded) return
        cards = Object.assign({}, cards, {[id]: Object.assign({}, cards[id], patch)})
        store.setText(JSON.stringify(cards) + "\n")
    }

    FileView {
        id: store
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/oninix/desktop-cards.json"
        printErrors: false
        blockWrites: true
        atomicWrites: true
        onLoaded: {
            try {
                const value = JSON.parse(text())
                if (value && typeof value === "object" && !Array.isArray(value)) root.cards = value
            } catch (_) {}
            root.loaded = true
        }
        onLoadFailed: root.loaded = true
        onSaved: root.error = ""
        onSaveFailed: root.error = "Could not save desktop card settings."
    }
}
