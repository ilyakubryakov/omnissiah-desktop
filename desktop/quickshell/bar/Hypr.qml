pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property var clients: []
    property var monitors: []
    property var active: ({})
    property string layout: ""

    function exec(cmd) {
        Hyprland.dispatch("hl.dsp.exec_cmd(" + JSON.stringify("oninix-app " + cmd) + ")")
    }

    function refresh() {
        debounce.restart()
    }

    Timer {
        id: debounce
        interval: 60
        onTriggered: {
            for (const p of [clientsProc, activeProc, monitorsProc]) {
                if (p.running) p.again = true
                else p.running = true
            }
        }
    }

    function classesOn(wsId) {
        return clients.filter(c => c.workspace && c.workspace.id === wsId).map(c => c["class"])
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
        return "\u{F05AF}"
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.layout = event.data.split(",").slice(1).join(",")
            root.refresh()
        }
    }

    Component.onCompleted: {
        refresh()
        devicesProc.running = true
    }

    Process {
        id: monitorsProc
        property bool again: false
        onExited: if (again) { again = false; running = true }
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.monitors = JSON.parse(text) } catch (_) {} } }
    }

    Process {
        id: clientsProc
        property bool again: false
        onExited: if (again) { again = false; running = true }
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.clients = JSON.parse(text) } catch (e) {} }
        }
    }

    Process {
        id: activeProc
        property bool again: false
        onExited: if (again) { again = false; running = true }
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.active = JSON.parse(text) } catch (e) { root.active = {} } }
        }
    }

    Process {
        id: devicesProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards.find(k => k.main) || JSON.parse(text).keyboards[0]
                    if (kb) root.layout = kb.active_keymap
                } catch (e) {}
            }
        }
    }
}
