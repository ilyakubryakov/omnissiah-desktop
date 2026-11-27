pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int cpu: -1
    property int mem: -1
    property int temp: -1
    property int disk: -1

    property real memTotalGiB: 0
    property real memUsedGiB: 0
    property real diskTotalGiB: 0
    property real diskUsedGiB: 0

    property var lastIdle: 0
    property var lastTotal: 0
    function rounded(value) { return Number.isFinite(value) ? Math.round(value) : -1 }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload()
            meminfo.reload()
            if (hwmon.path !== "") hwmon.reload()
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = f[3] + f[4]
            const total = f.reduce((a, b) => a + b, 0)
            if (root.lastTotal > 0 && total > root.lastTotal)
                root.cpu = Math.round(100 * (1 - (idle - root.lastIdle) / (total - root.lastTotal)))
            root.lastIdle = idle
            root.lastTotal = total
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const v = {}
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/)
                if (m) v[m[1]] = Number(m[2])
            }
            if (v.MemTotal && v.MemAvailable !== undefined) {
                root.mem = Math.round(100 * (1 - v.MemAvailable / v.MemTotal))
                root.memTotal = v.MemTotal / 1048576
                root.memUsed = (v.MemTotal - v.MemAvailable) / 1048576
            }
        }
    }

    FileView {
        id: hwmon
        printErrors: false
        onLoaded: root.temp = root.rounded(parseInt(text()) / 1000)
        onLoadFailed: {
            root.temp = -1
            path = ""
        }
    }
    Timer {
        interval: 30000
        running: hwmon.path === ""
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!findHwmon.running) findHwmon.running = true
    }
    Process {
        id: findHwmon
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do read -r n < \"$d/name\" || continue; case $n in k10temp|coretemp|cpu_thermal) [ -r \"$d/temp1_input\" ] && printf '%s\\n' \"$d/temp1_input\" && exit;; esac; done"]
        stdout: StdioCollector { onStreamFinished: hwmon.path = text.trim() }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=pcent,size,used", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const values = (text.split("\n")[1] || "").trim().split(/\s+/)
                const t = parseInt(values[0])
                if (!isNaN(t)) {
                    root.disk = t
                    root.diskTotalGiB = Number(values[1]) / 1073741824
                    root.diskUsedGiB = Number(values[2]) / 1073741824
                }
            }
        }
    }
}
