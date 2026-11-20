.pragma library
// theme: { text, bright, muted, accent, codeBg, rule, mono, size }

function escape(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

function inline(text, theme) {
    const kept = []
    const keep = html => { kept.push(html); return "\u0000" + (kept.length - 1) + "\u0000" }
    const link = (label, url) => keep('<a href="' + url + '" style="color:' + theme.accent + '; text-decoration:none;">' + label + "</a>")
    let out = escape(text)
        .replace(/`([^`]+)`/g, (_, code) => keep('<span style="font-family:\'' + theme.mono + '\'; background-color:'
            + theme.codeBg + '; color:' + theme.bright + ';">&nbsp;' + code + "&nbsp;</span>"))
        .replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, (_, label, url) => link(label, url))
        .replace(/(^|[\s(])(https?:\/\/[^\s<)]+[^\s<).,;:!?])/g, (_, lead, url) => lead + link(url, url))
    out = out
        .replace(/\*\*([^*]+)\*\*|__([^_]+)__/g, (_, a, b) => '<b style="color:' + theme.bright + ';">' + (a || b) + '</b>')
        .replace(/(^|[^*\w])\*([^*\s][^*]*)\*(?!\w)/g, "$1<i>$2</i>")
        .replace(/(^|[^_\w])_([^_\s][^_]*)_(?!\w)/g, "$1<i>$2</i>")
        .replace(/~~([^~]+)~~/g, "<s>$1</s>")
    return out.replace(/\u0000(\d+)\u0000/g, (_, i) => kept[Number(i)])
}

function paragraph(html, theme, extra) {
    return '<p style="margin-top:0; margin-bottom:' + Math.round(theme.size * 0.6) + 'px; line-height:140%;' + (extra || "") + '">' + html + "</p>"
}

function table(rows, theme) {
    const cells = row => row.replace(/^\s*\|/, "").replace(/\|\s*$/, "").split("|").map(c => c.trim())
    const body = rows.filter((row, i) => !(i === 1 && /^[\s|:-]+$/.test(row)))
    let html = '<table cellspacing="0" cellpadding="' + Math.round(theme.size * 0.3) + '" style="margin-bottom:' + Math.round(theme.size * 0.6) + 'px;">'
    body.forEach((row, i) => {
        html += "<tr>" + cells(row).map(c => i === 0
            ? '<td style="border-bottom:1px solid ' + theme.rule + ';"><b style="color:' + theme.bright + ';">' + inline(c, theme) + "</b></td>"
            : "<td>" + inline(c, theme) + "</td>").join("") + "</tr>"
    })
    return html + "</table>"
}

function toHtml(markdown, theme) {
    const lines = String(markdown || "").replace(/\r/g, "").split("\n")
    const out = []
    let i = 0
    while (i < lines.length) {
        const line = lines[i]
        const fence = line.match(/^\s*(```|~~~)/)
        if (fence) {
            const code = []
            i++
            while (i < lines.length && !lines[i].trim().startsWith(fence[1])) code.push(lines[i++])
            i++
            out.push('<table width="100%" cellspacing="0" cellpadding="' + Math.round(theme.size * 0.55) + '" style="margin-bottom:'
                + Math.round(theme.size * 0.6) + 'px; background-color:' + theme.codeBg + ';"><tr><td><pre style="font-family:\''
                + theme.mono + '\'; font-size:' + Math.round(theme.size * 0.88) + 'px; color:' + theme.bright + '; margin:0;">'
                + escape(code.join("\n")) + '</pre></td></tr></table><p style="margin:0; font-size:' + Math.round(theme.size * 0.4) + 'px;">&nbsp;</p>')
            continue
        }
        if (!line.trim()) { i++; continue }
        const heading = line.match(/^\s*(#{1,6})\s+(.*)$/)
        if (heading) {
            const scale = heading[1].length === 1 ? 1.2 : heading[1].length === 2 ? 1.1 : 1
            out.push('<p style="margin-top:' + Math.round(theme.size * 0.4) + 'px; margin-bottom:' + Math.round(theme.size * 0.35)
                + 'px; font-size:' + Math.round(theme.size * scale) + 'px; font-weight:600; color:' + theme.bright + ';">'
                + inline(heading[2].replace(/\s#+\s*$/, ""), theme) + "</p>")
            i++; continue
        }
        if (/^\s*([-*_])\s*\1\s*\1[\s\1]*$/.test(line)) {
            out.push('<hr style="color:' + theme.rule + ';">')
            i++; continue
        }
        if (/^\s*\|.*\|\s*$/.test(line)) {
            const rows = []
            while (i < lines.length && /^\s*\|.*\|\s*$/.test(lines[i])) rows.push(lines[i++])
            out.push(table(rows, theme))
            continue
        }
        if (/^\s*>/.test(line)) {
            const quote = []
            while (i < lines.length && /^\s*>/.test(lines[i])) quote.push(lines[i++].replace(/^\s*>\s?/, ""))
            out.push(paragraph(inline(quote.join(" "), theme), theme, " color:" + theme.muted + "; margin-left:" + theme.size + "px;"))
            continue
        }
        const item = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/
        if (item.test(line)) {
            const items = []
            while (i < lines.length) {
                const m = lines[i].match(item)
                if (m) { items.push({ depth: Math.floor(m[1].replace(/\t/g, "  ").length / 2), marker: m[2], text: m[3] }); i++ }
                else if (lines[i].trim() && /^\s{2,}/.test(lines[i]) && items.length) { items[items.length - 1].text += " " + lines[i].trim(); i++ }
                else break
            }
            items.forEach((entry, n) => {
                const bullet = /\d/.test(entry.marker) ? entry.marker.replace(")", ".") : entry.depth ? "◦" : "•"
                const indent = theme.size * (0.4 + entry.depth * 1.3)
                out.push('<p style="margin-top:0; margin-bottom:' + Math.round(theme.size * (n === items.length - 1 ? 0.6 : 0.25))
                    + 'px; margin-left:' + Math.round(indent + theme.size * 1.3) + 'px; text-indent:-' + Math.round(theme.size * 1.3)
                    + 'px; line-height:140%;"><span style="color:' + theme.accent + ';">' + bullet + "</span>&nbsp;&nbsp;"
                    + inline(entry.text, theme) + "</p>")
            })
            continue
        }
        const text = []
        while (i < lines.length && lines[i].trim() && !/^\s*(#{1,6}\s|```|~~~|>|\||([-*+]|\d+[.)])\s)/.test(lines[i])) text.push(lines[i++].trim())
        if (!text.length) { text.push(lines[i++].trim()) }
        out.push(paragraph(text.map(t => inline(t, theme)).join("<br>"), theme))
    }
    return out.join("\n")
}
