// Calendar data for CalPanel. Everything expensive - fetching the iCal feeds,
// expanding recurrences, computing holidays - happens in caldash-helper, driven
// by caldash.timer. This side only reads the JSON it leaves behind, for the same
// reason SysData does: nothing here may ever spawn a process.

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
    // The helper wakes every ten minutes; an hour of silence means it stopped.
    readonly property bool stale: ready && (now - d.ts) > 3600

    // Calendars that failed their last fetch, so the panel can say so rather
    // than quietly showing an empty month.
    readonly property var broken: {
        var out = []
        for (var k in cals) if (cals[k] && cals[k].ok === false) out.push(cals[k].name || k)
        return out
    }

    function parse() {
        try {
            root.d = JSON.parse(file.text())
        } catch (e) {
            // A half-written or absent file just leaves the last good data up.
        }
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.cache/caldash.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse()
    }

    // The helper replaces the file by rename, so the inotify watch can be left
    // pointing at the old inode. This poll is the safety net.
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: { root.now = Date.now() / 1000; file.reload() }
    }
}
