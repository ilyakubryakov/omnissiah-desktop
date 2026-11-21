function groupbarHeight(client) {
    return client.grouped && client.grouped.length > 1 ? 20 : 0;
}

function coversArea(windows, area, padding) {
    const rects = windows.filter(c => c.at && c.size && c.size[0] > 0 && c.size[1] > 0).map(c => [
        Math.max(area[0], c.at[0] - padding), Math.max(area[1], c.at[1] - padding - groupbarHeight(c)),
        Math.min(area[2], c.at[0] + c.size[0] + padding), Math.min(area[3], c.at[1] + c.size[1] + padding)
    ]).filter(r => r[2] > r[0] && r[3] > r[1]);
    const edges = [area[0], area[2]];
    for (const rect of rects) edges.push(rect[0], rect[2]);
    edges.sort((a, b) => a - b);
    for (let i = 1; i < edges.length; i++) {
        if (edges[i] - edges[i - 1] < 0.001) continue;
        const x = (edges[i - 1] + edges[i]) / 2;
        const spans = rects.filter(r => r[0] <= x && r[2] >= x).sort((a, b) => a[1] - b[1]);
        let covered = area[1];
        for (const span of spans) {
            if (span[1] > covered + 1) return false;
            covered = Math.max(covered, span[3]);
        }
        if (covered < area[3] - 1) return false;
    }
    return rects.length > 0;
}

function surfaceWindow(clients, monitors, screenName, outerGap, innerGap) {
    const monitor = monitors.find(m => m.name === screenName);
    if (!monitor || monitor.disabled || monitor.dpmsStatus === false) return null;
    const scale = monitor.scale || 1;
    const rotated = (monitor.transform || 0) % 2 !== 0;
    const width = (rotated ? monitor.height : monitor.width) / scale;
    const height = (rotated ? monitor.width : monitor.height) / scale;
    const reserved = monitor.reserved || [0, 0, 0, 0];
    const area = [monitor.x + reserved[0], monitor.y + reserved[1],
        monitor.x + width - reserved[2], monitor.y + height - reserved[3]];
    if (!(area[2] > area[0] && area[3] > area[1])) return null;
    const padding = Math.min(32, Math.max(4, Number(outerGap) || 0, (Number(innerGap) || 0) / 2) + 4);
    const workspace = (monitor.activeWorkspace || {}).id;
    const special = (monitor.specialWorkspace || {}).id;
    const visible = clients.filter(c => c.monitor === monitor.id && !c.hidden && c.mapped !== false
        && c.visible !== false
        && c.workspace && (c.workspace.id === workspace || (special && c.workspace.id === special) || c.pinned));
    visible.sort((a, b) => (a.focusHistoryID ?? 9999) - (b.focusHistoryID ?? 9999));
    const expanded = visible.find(c => c.fullscreen === 1 || c.fullscreen === 2 || c.fullscreen === 3);
    if (expanded) return expanded;
    for (const id of special ? [special, workspace] : [workspace]) {
        const tiled = visible.filter(c => !c.floating && c.workspace.id === id);
        if (coversArea(tiled, area, padding)) return tiled[0];
    }
    return null;
}

function surfaceRole(appClass) {
    const name = (appClass || "").toLowerCase();
    if (name === "kitty" || name.startsWith("kitty-")) return "background";
    if (["code", "code-url-handler", "vscodium"].includes(name)) return "darkBackground";
    return "windowBackground";
}
