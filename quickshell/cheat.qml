//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import "shared" as Shared

ShellRoot {
    CheatPanel { id: cheat; screenTarget: Shared.Screens.main }
    IpcHandler {
        target: "cheat"
        function toggle(): void { cheat.toggle() }
        function show(): void { cheat.open() }
        function hide(): void { cheat.close() }
    }
}
