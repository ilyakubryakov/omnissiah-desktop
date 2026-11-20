pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool floating: false
    // A file created after start is not watched yet; poll only while it is missing.
    property bool missing: false
    Timer { interval: 2000; running: root.missing; repeat: true; onTriggered: store.reload() }
    FileView {
        id: store
        path: (Quickshell.env('XDG_STATE_HOME') || Quickshell.env('HOME') + '/.local/state') + '/oninix/window-mode.conf'
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { root.missing = false; root.floating = text().split('\n').includes('mode=floating') }
        onLoadFailed: { root.missing = true; root.floating = false }
    }
}
