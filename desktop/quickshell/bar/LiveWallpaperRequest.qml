import QtQuick
import Quickshell
import Quickshell.Io
import "LiveWallpaper.js" as Live

Process {
    id: request
    property bool pending: false
    signal finished(var result)

    function run(args) {
        if (pending) return
        command = ["oninix-livewall"].concat(args)
        pending = true
        running = true
    }

    function finish(result) {
        pending = false
        finished(result)
    }

    stdout: StdioCollector { id: output }
    onExited: code => finish(Live.response(output.text, code))
    onRunningChanged: {
        if (running || !pending) return
        Qt.callLater(() => {
            if (pending && !running)
                finish({ error: "Could not start oninix-livewall" })
        })
    }
}
