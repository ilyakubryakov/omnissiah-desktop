.pragma library

function layout(count, screenWidth, screenHeight, px = n => n) {
    const maxWidth = Math.min(screenWidth, Math.max(px(220), Math.min(px(1200), screenWidth - px(80))))
    const padding = Math.max(0, Math.min(px(20), Math.floor((maxWidth - 1) / 2)))
    const contentWidth = maxWidth - 2 * padding
    const maxCellWidth = px(178)
    const chromeHeight = 2 * padding + px(54)
    const cellHeight = Math.max(1, Math.min(px(170), screenHeight - chromeHeight))
    const maxColumns = Math.max(1, Math.floor(contentWidth / maxCellWidth))
    const rows = Math.max(1, Math.ceil(count / maxColumns))
    const columns = Math.max(1, Math.min(maxColumns, Math.ceil(count / rows)))
    const visibleRows = Math.min(rows, Math.max(1, Math.min(4, Math.floor((screenHeight - px(150)) / cellHeight))))
    const cellWidth = Math.max(1, Math.min(maxCellWidth, Math.floor(contentWidth / columns)))
    return {columns, rows, visibleRows, cellWidth, cellHeight, padding,
        width: Math.min(screenWidth, columns * cellWidth + 2 * padding),
        height: Math.min(screenHeight, visibleRows * cellHeight + chromeHeight)}
}

function newer(token, than) {
    const a = String(token || "").split("-"), b = String(than || "").split("-");
    if (a.length !== 2 || b.length !== 2) return true;
    if (a[0] === b[0]) return Number(a[1]) > Number(b[1]);
    const ga = /^(\d+)c(\d+)x/.exec(a[0]), gb = /^(\d+)c(\d+)x/.exec(b[0]);
    if (!ga || !gb) return true;
    if (Number(ga[1]) !== Number(gb[1])) return Number(ga[1]) > Number(gb[1]);
    return Number(ga[2]) >= Number(gb[2]);
}
