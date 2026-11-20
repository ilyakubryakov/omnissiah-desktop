pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool opened: false
    property bool ready: false
    property string vault: ""
    property bool available: false
    property var notes: []
    property var jobs: []
    property var note: ({})
    property string title: ""
    property string body: ""
    property string query: ""
    property string error: ""
    property string saveState: ""
    property bool dirty: false
    property bool conflict: false
    property bool saving: false
    property bool loading: false
    property int generation: 0
    property int sequence: 0
    property var pending: ({})
    property var outbox: []
    property string nextNote: ""
    property string expression: ""
    property string result: ""
    property string calcError: ""
    property var history: []
    property bool initialized: false
    signal noteLoaded()
    signal captureFailed(string message)

    // Markdown task lines in the body: [{line, done, text}] for the checklist strip.
    readonly property var tasks: {
        const out = [], lines = body.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^\s*[-*+] \[([ xX])\] (.*)$/)
            if (m) out.push({line: i, done: m[1] !== " ", text: m[2]})
        }
        return out
    }
    function toggleTask(index) {
        if (conflict || loading) return
        const lines = body.split("\n")
        const line = lines[index]
        if (line === undefined) return
        const m = line.match(/^(\s*[-*+] \[)([ xX])(\] .*)$/)
        if (!m) return
        lines[index] = m[1] + (m[2] === " " ? "x" : " ") + m[3]
        edit(title, lines.join("\n")); noteLoaded()
    }
    // Primary selection (or clipboard) into the open note, else into a new one.
    function capture(text) {
        const clean = text.replace(/\s+$/, "")
        if (!clean.trim()) { captureFailed("Select some text first."); return false }
        if (loading || conflict) { captureFailed("Finish the open note first."); return false }
        if (!note.id && !title.trim() && !body.trim())
            title = "Captured " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm")
        edit(title, body.trim() ? body.replace(/\s+$/, "") + "\n\n" + clean + "\n" : clean + "\n")
        noteLoaded()
        return true
    }

    function call(value) {
        value.requestId = ++sequence
        pending[value.requestId] = Object.assign({}, value, {generation: generation})
        const line = JSON.stringify(value) + "\n"
        if (ready) backend.write(line)
        else outbox = outbox.concat([line])
    }
    function refresh() {
        call({op:"status"})
        if (available) call({op:"list", query:query})
    }
    function adopt(value) {
        note = value; title = value.title || ""; body = value.body || ""
        dirty = false; conflict = false; saveState = value.id ? "Saved in Obsidian" : "Start typing to create a note"
        generation++; noteLoaded()
    }
    function edit(newTitle, newBody) {
        title = newTitle; body = newBody; dirty = true; generation++
        saveState = "Saving…"; autosave.restart()
    }
    function save(copy) {
        if (saving || (!copy && (conflict || !dirty))) return
        if (!note.id && !title.trim() && !body.trim()) { dirty = false; return }
        saving = true
        call({op:copy || !note.id ? "new" : "save", id:note.id || "", revision:note.revision || "", title:title, body:body})
    }
    function select(id) {
        if (saving || dirty) { nextNote = id; save(false); return }
        if (id === "new") adopt({})
        else { loading = true; call({op:"read", id:id}) }
    }
    function reloadNote() {
        if (note.id) { loading = true; call({op:"reload", id:note.id}) }
    }
    function calculate() {
        calcError = ""
        if (expression.trim()) call({op:"calculate", expression:expression})
    }
    function handle(response) {
        const request = pending[response.requestId]
        if (!request) return
        delete pending[response.requestId]
        const writing = request.op === "save" || request.op === "new"
        if (writing) saving = false
        if (request.op === "read" || request.op === "reload") loading = false
        if (!response.ok) {
            if (request.op === "calculate") { calcError = response.message; result = ""; return }
            error = response.message || "The action failed."
            if (writing) { conflict = true; saveState = "Draft kept locally" }
            return
        }
        const value = response.data
        if (request.op === "status") {
            vault = value.vault; available = value.available; jobs = value.jobs || []
            if (!initialized) {
                initialized = true
                if (value.draft && (value.draft.body || value.draft.title)) {
                    note = value.draft; title = value.draft.title; body = value.draft.body
                    dirty = true; conflict = true; saveState = "Recovered draft"
                    error = "Recovered an unsaved draft. Save a copy, or reload the original."
                    noteLoaded()
                }
                if (available) call({op:"list", query:query})
            }
        } else if (request.op === "list") {
            if (request.query === query) notes = value
        } else if (["read", "reload"].includes(request.op)) {
            if (request.generation === generation) {
                if (value.id !== note.id || value.revision !== note.revision || conflict) { error = ""; adopt(value) }
            }
        } else if (writing) {
            note = value; error = ""; conflict = false
            if (request.generation === generation) {
                dirty = false; saveState = "Saved in Obsidian"
                if (!title.trim()) { title = value.title; noteLoaded() }
            } else { dirty = true; autosave.restart() }
            call({op:"list", query:query})
            if (!dirty && nextNote) { const id = nextNote; nextNote = ""; select(id) }
        } else if (request.op === "calculate") {
            if (request.expression === expression) { result = value; calcError = "" }
            history = [{expression:request.expression, result:value}].concat(history).slice(0, 8)
        } else if (request.op === "vault") {
            vault = value.vault; available = true; error = ""; refresh()
        } else if (["add", "done", "snooze", "pause", "resume"].includes(request.op)) {
            jobs = value; error = ""
        }
    }
    onOpenedChanged: {
        if (opened) refresh()
        else save(false)
    }
    onQueryChanged: search.restart()
    Process {
        id: backend
        command: ["oninix-notebook"]
        stdinEnabled: true
        running: true
        onStarted: {
            root.ready = true
            for (const line of root.outbox) write(line)
            root.outbox = []
            root.call({op:"status"})
            if (root.dirty && !root.conflict) autosave.restart()
        }
        stdout: SplitParser { onRead: line => {
            try { root.handle(JSON.parse(line)) } catch (_) { root.error = "Notebook response could not be read." }
        } }
        onExited: {
            root.ready = false; root.saving = false; root.loading = false; root.pending = ({})
            root.error = "Notebook disconnected. Your text is still in the editor."
            reconnect.restart()
        }
    }
    Timer { id: reconnect; interval: 2000; onTriggered: backend.running = true }
    Timer { id: autosave; interval: 600; onTriggered: root.save(false) }
    Timer { id: search; interval: 180; onTriggered: { if (root.available) root.call({op:"list", query:root.query}) } }
    Timer { interval: 5000; running: root.opened; repeat: true; onTriggered: {
        root.refresh()
        if (root.note.id && !root.dirty && !root.saving) root.call({op:"read", id:root.note.id})
    } }
}
