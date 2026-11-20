.pragma library

function normalized(value) {
    return String(value || "").toLowerCase().replace(/\u0451/g, "е")
        .replace(/\b(super|win|windows|meta)\b/g, "meta").replace(/\b(enter|return)\b/g, "return")
}
function matches(row, section, query) {
    const hay = normalized([row.keys, row.desc, row.detail, row.keywords, row.group, section.label, section.name].join(" "))
    return normalized(query).trim().split(/\s+/).filter(Boolean).every(word => hay.includes(word))
}
function keycaps(keys) {
    const parts = String(keys).split("+")
    if (parts.length > 1 && parts[parts.length - 1] === "") { parts.pop(); parts[parts.length - 1] = "+" }
    return parts.map(p => ({Meta:"Win", Return:"Enter", LMB:"Left click", RMB:"Right click", Mouse_down:"Wheel ↓", Mouse_up:"Wheel ↑"})[p] || p).filter(Boolean)
}
function blocks(sections, selected, query) {
    const source = query.trim() ? sections.filter(s => s.name !== "Home") : sections.filter(s => s.name === selected)
    const result = []
    for (const section of source) {
        const groups = {}, rows = (section.rows || []).filter(row => matches(row, section, query))
        for (const row of rows) {
            if (row.kind === "guide") { result.push({title: row.desc, hint: "", guide: true, rows: [row]}); continue }
            const title = row.group || section.label || section.name
            if (!groups[title]) groups[title] = []
            groups[title].push(row)
        }
        for (const title of Object.keys(groups)) {
            for (let i = 0; i < groups[title].length; i += 8)
                result.push({title: title + (i ? " · " + (i / 8 + 1) : ""), hint: section.curated ? "Curated hints · check in the app" : section.hint || "", guide: false, rows: groups[title].slice(i, i + 8)})
        }
    }
    return result
}
function columns(blocks, count) {
    const lanes = Array.from({length: count}, () => []), heights = Array(count).fill(0)
    for (const block of blocks) {
        const lane = heights.indexOf(Math.min(...heights))
        lanes[lane].push(block)
        heights[lane] += block.guide ? 5 : block.rows.length * 2 + 2
    }
    return lanes
}
