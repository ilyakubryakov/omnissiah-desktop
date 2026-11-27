.pragma library

function clamp(value, low, high) {
    return Math.max(low, Math.min(high, Math.round(value)))
}

function valid(rect) {
    return !!rect && [rect.x, rect.y, rect.width, rect.height].every(Number.isFinite)
        && rect.width > 0 && rect.height > 0
}

function fit(rect, area, minimum, maximum, aspect, heightInset) {
    if (aspect > 0) {
        const maxHeight = Math.min(maximum.height, area.height)
        const inset = Math.min(heightInset, maxHeight)
        const maxWidth = Math.floor(Math.min(maximum.width, area.width, (maxHeight - inset) * aspect))
        const minWidth = Math.min(maxWidth, Math.max(minimum.width, Math.ceil((minimum.height - inset) * aspect)))
        const w = clamp(rect.width, minWidth, maxWidth)
        const h = Math.round(w / aspect) + inset
        return {x: clamp(rect.x, 0, area.width - w), y: clamp(rect.y, 0, area.height - h), width: w, height: h}
    }
    const w = clamp(rect.width, Math.min(minimum.width, area.width), Math.min(maximum.width, area.width))
    const h = clamp(rect.height, Math.min(minimum.height, area.height), Math.min(maximum.height, area.height))
    return {x: clamp(rect.x, 0, area.width - w), y: clamp(rect.y, 0, area.height - h), width: w, height: h}
}

function edit(rect, dx, dy, resize, area, minimum, maximum) {
    if (!resize)
        return fit({x: rect.x + dx, y: rect.y + dy, width: rect.width, height: rect.height}, area, minimum, maximum)

    const room = {width: Math.max(0, area.width - rect.x), height: Math.max(0, area.height - rect.y)}
    const size = fit({x: 0, y: 0, width: rect.width + dx, height: rect.height + dy}, room, minimum, maximum)
    return {x: rect.x, y: rect.y, width: size.width, height: size.height}
}

function snap(rect, step, resize, area, minimum, maximum) {
    if (!(step > 0)) return rect
    const round = v => Math.round(v / step) * step
    if (!resize)
        return fit({x: round(rect.x), y: round(rect.y), width: rect.width, height: rect.height}, area, minimum, maximum)
    const right = round(rect.x + rect.width), bottom = round(rect.y + rect.height)
    const size = fit({x: 0, y: 0, width: right - rect.x, height: bottom - rect.y},
                     {width: Math.max(0, area.width - rect.x), height: Math.max(0, area.height - rect.y)}, minimum, maximum)
    return {x: rect.x, y: rect.y, width: size.width, height: size.height}
}

function resizeAspect(rect, horizontal, delta, step, area, minimum, maximum, aspect, inset) {
    const origin = horizontal ? rect.x : rect.y
    const end = origin + (horizontal ? rect.width : rect.height) + delta
    const length = (step > 0 ? Math.round(end / step) * step : end) - origin
    const width = horizontal ? length : (length - inset) * aspect
    const room = {width: area.width - rect.x, height: area.height - rect.y}
    const size = fit({x: 0, y: 0, width: width}, room, minimum, maximum, aspect, inset)
    return {x: rect.x, y: rect.y, width: size.width, height: size.height}
}
