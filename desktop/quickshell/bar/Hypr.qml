pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    readonly property var clients: Array.isArray(clientsProc.data) ? clientsProc.data : []
    readonly property var monitors: Array.isArray(monitorsProc.data) ? monitorsProc.data : []
    readonly property var active: activeProc.data || ({})
    property string layout: ""
    property string layoutName: ""
    property var focusedAddress: null
    property var pending: new Set()

    function exec(cmd) {
        Hyprland.dispatch("hl.dsp.exec_cmd(" + JSON.stringify("oninix-app " + cmd) + ")")
    }

    function enqueue(...processes) {
        for (const process of processes) pending.add(process)
        if (!debounce.running) debounce.start()
    }

    function refresh() { enqueue(clientsProc, activeProc, monitorsProc) }

    Timer {
        id: debounce
        interval: 60
        onTriggered: {
            for (const p of root.pending) {
                if (p.running) p.again = true
                else p.running = true
            }
            root.pending.clear()
        }
    }

    function classesOn(wsId) {
        return clients.filter(c => c.workspace && c.workspace.id === wsId).map(c => c["class"])
    }

    function addressOf(value) { return value && !value.startsWith("0x") ? "0x" + value : value }

    function title(client) {
        const window = Hyprland.toplevels.values.find(w => addressOf(w.address) === client.address)
        return window?.title || client.title || ""
    }

    function icon(cls) {
        const c = (cls || "").toLowerCase()
        const web = c.startsWith("chrome-") || c.startsWith("crx_")
        const entry = web ? AppIcons.windowEntry(cls) : null
        const identity = (c + " " + (entry ? entry.name : "")).toLowerCase()
        if (identity.includes("teams")) return "\u{F02BB}"
        if (identity.includes("outlook")) return "\u{F0D22}"
        if (identity.includes("powerpoint")) return "\u{F1390}"
        if (identity.includes("excel")) return "\u{F138F}"
        if (identity.includes("word.cloud") || identity.includes("microsoft word")) return "\u{F1392}"
        if (identity.includes("onedrive") || identity.includes("office.com__launch_onedrive")) return "\u{F03CA}"
        if (web && identity.includes("meet.google")) return "\u{F0567}"
        if (web) return "\u{F059F}"
        if (c.includes("nextcloud")) return "\u{F015F}"
        if (c.includes("kdeconnect")) return "\u{F011C}"
        if (c.includes("kitty")) return "\u{F018D}"
        if (c.includes("chrome")) return "\u{F02AF}"
        if (c.includes("dolphin")) return "\u{F024B}"
        if (c.includes("slack")) return "\u{F04B1}"
        if (c.includes("telegram")) return "\u{F048A}"
        if (c.includes("obsidian")) return "\u{F082E}"
        if (c === "code" || c.includes("vscode")) return "\u{F0A1E}"
        if (c.includes("spotify")) return "\u{F04C7}"
        if ((c.includes("1password") || c.includes("onepassword"))) return "\u{F0881}"
        if (c.includes("okular")) return "\u{F0219}"
        if (c.includes("claude")) return "\u{EC82}"
        if (c.includes("chatgpt") || c.includes("codex")) return "\u{EC81}"
        if (c.includes("steam")) return "\u{F04D3}"
        if (c.includes("battle.net")) return "\u{EF94}"
        if (c.includes("remmina")) return "\u{F08B9}"
        if (c.includes("thunderbird")) return "\u{F01EE}"
        if (c.includes("emacs")) return "\u{E632}"
        if (c.includes("orca-slicer") || c.includes("orcaslicer")) return "\u{F0E5B}"
        return "\u{F05AF}"
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "activelayout":
                root.layoutName = event.data.split(",").slice(1).join(",")
                root.enqueue(devicesProc)
                break
            case "activewindowv2": {
                const address = root.addressOf(event.data)
                if (address !== root.focusedAddress) {
                    root.focusedAddress = address
                    root.enqueue(clientsProc, activeProc)
                }
                break
            }
            case "activewindow": {
                const cls = event.data.split(",", 1)[0]
                if (cls && cls !== (root.active["class"] || ""))
                    root.enqueue(clientsProc, activeProc)
                break
            }
            case "windowtitlev2": {
                const address = root.addressOf(event.data.split(",", 1)[0])
                if (address === (root.focusedAddress ?? root.active.address))
                    root.enqueue(activeProc)
                const known = root.clients.find(c => c.address === address)
                if (!known || !known["class"])
                    root.enqueue(clientsProc)
                break
            }
            case "openwindow": case "closewindow": case "changefloatingmode":
            case "minimized": case "pin": case "togglegroup":
            case "moveintogroup": case "moveoutofgroup":
                root.enqueue(clientsProc, activeProc)
                break
            case "workspacev2": case "focusedmon": case "activespecialv2":
                root.enqueue(monitorsProc)
                break
            case "movewindowv2": case "moveworkspacev2": case "renameworkspace":
            case "fullscreen": case "monitoraddedv2": case "monitorremoved":
                root.refresh()
                break
            case "configreloaded":
                root.refresh()
                root.enqueue(devicesProc)
                break
            }
        }
    }

    Component.onCompleted: {
        refresh()
        enqueue(devicesProc)
    }

    component Snapshot: Process {
        id: sample
        required property string subject
        required property bool list
        property var data: list ? [] : ({})
        property string snapshot: ""
        property bool again: false
        onExited: if (again) { again = false; root.enqueue(sample) }
        command: ["hyprctl", subject, "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (sample.snapshot === text) return
                try {
                    const result = JSON.parse(text)
                    if (!result || typeof result !== "object" || Array.isArray(result) !== sample.list) return
                    sample.snapshot = text
                    sample.data = result
                } catch (_) {}
            }
        }
    }

    Snapshot { id: monitorsProc; subject: "monitors"; list: true }
    Snapshot { id: clientsProc; subject: "clients"; list: true }
    Snapshot { id: activeProc; subject: "activewindow"; list: false }

    Process {
        id: devicesProc
        property bool again: false
        onExited: if (again) { again = false; root.enqueue(devicesProc) }
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards || []
                    const kb = keyboards.find(k => k.main) || keyboards[0]
                    root.layout = kb?.layout?.split(",")[kb.active_layout_index]?.trim() || ""
                    root.layoutName = kb?.active_keymap || ""
                } catch (e) {}
            }
        }
    }
}
