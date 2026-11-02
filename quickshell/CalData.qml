import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property var d: ({})
    property double now: Date.now() / 1000

    readonly property var days:   d.days   || ({})
    readonly property var events: d.events || []
    readonly property var cals:   d.cals   || ({})
    readonly property var clocks: d.clocks || ({})
    readonly property var nextHoliday: d.next_holiday || null
    readonly property bool configured: d.configured === true

    readonly property bool ready: d.ts !== undefined

    readonly property bool stale: ready && (now - d.ts) > 3600

    readonly property var broken: {
        var out = []
        for (var k in cals) if (cals[k] && cals[k].ok === false) out.push(cals[k].name || k)
        return out
    }

    function parse() {
        try {
            root.d = JSON.parse(file.text())
        } catch (e) {

        }
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.cache/caldash.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse()
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: { root.now = Date.now() / 1000; file.reload() }
    }
}
