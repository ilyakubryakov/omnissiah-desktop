pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Machine load for the bottom bar: CPU, memory, CPU temperature, root disk.
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

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload()
            meminfo.reload()
            hwmon.running = true
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
                root.memTotalGiB = v.MemTotal / 1048576
                root.memUsedGiB = (v.MemTotal - v.MemAvailable) / 1048576
            }
        }
    }

    // Only identified CPU sensors; never label an unrelated board sensor CPU.
    Process {
        id: hwmon
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do n=$(cat $d/name); case $n in k10temp|coretemp|cpu_thermal) cat $d/temp1_input; exit;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = parseInt(text)
                root.temp = !isNaN(t) ? Math.round(t / 1000) : -1
            }
        }
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
