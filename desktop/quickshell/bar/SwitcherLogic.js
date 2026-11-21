.pragma library

function layout(count, screenWidth, screenHeight) {
    const maxWidth = Math.max(220, Math.min(1200, screenWidth - 80))
    const maxColumns = Math.max(1, Math.floor((maxWidth - 30) / 178))
    const rows = Math.max(1, Math.ceil(count / maxColumns))
    const columns = Math.max(1, Math.min(maxColumns, Math.ceil(count / rows)))
    const visibleRows = Math.min(rows, Math.max(1, Math.min(4, Math.floor((screenHeight - 150) / 170))))
    const cellWidth = Math.min(178, Math.floor((maxWidth - 40) / columns))
    return {columns: columns, rows: rows, visibleRows: visibleRows, cellWidth: cellWidth,
        width: columns * cellWidth + 40, height: visibleRows * 170 + 94}
}
