.pragma library
var pages = [
    {id:"quick", title:"Overview", glyph:"\uf00a", keywords:"quick favorites избранное обзор быстрые"},
    {id:"audio", title:"Sound", glyph:"\uf028", keywords:"volume microphone output headphones звук громкость микрофон наушники"},
    {id:"network", title:"Connections", glyph:"\uf0ac", keywords:"wifi lan vpn tailscale bluetooth сеть интернет впн"},
    {id:"displays", title:"Displays", glyph:"\uf26c", keywords:"monitor scale hdr resolution экран монитор масштаб разрешение"},
    {id:"devices", title:"Devices", glyph:"\uf11c", keywords:"keyboard layout mouse printer devices клавиатура раскладка мышь принтер"},
    {id:"power", title:"Power", glyph:"\uf011", keywords:"sleep idle lock screen timeout battery сон экран автоблокировка засыпание питание"},
    {id:"modes", title:"Work modes", glyph:"\uf0b1", keywords:"call meeting music record game focus режим звонок запись встреча работа"},
    {id:"themes", title:"Themes & wallpapers", glyph:"\uf03e", keywords:"theme wallpaper colors light dark тема обои цвет светлая темная"},
    {id:"panels", title:"Panels & windows", glyph:"\uf009", keywords:"gap gaps tiling panel rounding width height opacity appearance гап отступ панели скругление длина высота прозрачность"},
    {id:"apps", title:"Apps & icons", glyph:"\uf03b", keywords:"icons launchers pin applications значки иконки приложения закрепить"},
    {id:"calendars", title:"Calendars", glyph:"\uf073", keywords:"google microsoft office calendar meeting календарь встречи аккаунт"},
    {id:"clipboard", title:"Clipboard", glyph:"\uf0ea", keywords:"copy paste history буфер копировать вставить"},
    {id:"overview", title:"Windows", glyph:"\uf24d", keywords:"windows minimize restore окна свернуть восстановить"},
    {id:"session", title:"Session", glyph:"\uf135", keywords:"shortcuts capture recording autostart горячие клавиши запись автозапуск"},
    {id:"system", title:"System", glyph:"\uf108", keywords:"backup update services generation system бэкап резервные обновления службы"},
    {id:"guide", title:"Shortcuts & guide", glyph:"\uf059", keywords:"help cheatsheet manual hotkeys keyboard shortcuts помощь шпаргалка сочетания клавиши подсказки инструкция"}
]
function search(query) {
    const words = query.toLowerCase().trim().split(/\s+/).filter(Boolean)
    return pages.filter(p => words.every(word => (p.title + " " + p.keywords).toLowerCase().includes(word)))
}
function page(id) { return pages.find(p => p.id === id) || pages[0] }
function target(query) {
    const text = query.toLowerCase()
    const targets = [[/gap|гап|отступ/, "Between tiled windows"], [/microphone|микрофон/, "Microphone"],
        [/volume|громкость|output|наушники/, "Output"], [/vpn|впн/, "VPN"], [/tailscale/, "Tailscale"],
        [/bluetooth/, "Bluetooth"], [/keyboard|расклад|клавиат/, "Keyboard"], [/wallpaper|обои/, "Wallpaper"],
        [/battery|батаре/, "Battery"], [/idle|автоблок|засып|sleep/, "Idle"], [/backup|бэкап/, "Backup"]]
    for (const pair of targets) if (pair[0].test(text)) return pair[1]
    return ""
}
