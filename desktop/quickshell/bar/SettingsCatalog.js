.pragma library
var groups = ["network", "hardware", "personal", "work", "system"]
var pages = [
    {id:"network", group:"network", tone:"blue", title:"Connections", glyph:"\uf0ac", keywords:"wifi lan bluetooth сеть интернет"},
    {id:"audio", group:"hardware", tone:"magenta", title:"Sound", glyph:"\uf028", keywords:"volume microphone output headphones звук громкость микрофон наушники"},
    {id:"displays", group:"hardware", tone:"magenta", title:"Displays", glyph:"\uf26c", keywords:"monitor scale hdr resolution экран монитор масштаб разрешение"},
    {id:"devices", group:"hardware", tone:"magenta", title:"Devices", glyph:"\uf11c", keywords:"keyboard layout mouse printer devices клавиатура раскладка мышь принтер"},
    {id:"power", group:"hardware", tone:"magenta", title:"Power", glyph:"\uf011", keywords:"sleep idle lock screen timeout battery сон экран автоблокировка засыпание питание"},
    {id:"themes", group:"personal", tone:"cyan", title:"Themes & wallpapers", glyph:"\uf03e", keywords:"theme wallpaper colors light dark тема обои цвет светлая темная"},
    {id:"panels", group:"personal", tone:"cyan", title:"Panels & windows", glyph:"\uf009", keywords:"gap gaps tiling panel rounding radius width height opacity appearance font metrics geometry spacing unit density focus ring native unified гап отступ панели скругление длина высота прозрачность шрифт метрики геометрия радиус плотность"},
    {id:"apps", group:"personal", tone:"cyan", title:"Apps & icons", glyph:"\uf03b", keywords:"icons launchers pin applications значки иконки приложения закрепить"},
    {id:"modes", group:"work", tone:"yellow", title:"Work modes", glyph:"\uf0b1", keywords:"call meeting music record game focus режим звонок запись встреча работа"},
    {id:"calendars", group:"work", tone:"yellow", title:"Calendars", glyph:"\uf073", keywords:"google microsoft office calendar meeting календарь встречи аккаунт"},
    {id:"session", group:"work", tone:"yellow", title:"Session", glyph:"\uf135", keywords:"shortcuts capture recording autostart горячие клавиши запись автозапуск"},
    {id:"system", group:"system", tone:"green", title:"System", glyph:"\uf108", keywords:"update services generation system обновления службы"},
    {id:"guide", group:"system", tone:"green", title:"Shortcuts & guide", glyph:"\uf059", keywords:"help cheatsheet manual hotkeys keyboard shortcuts помощь шпаргалка сочетания клавиши подсказки инструкция"}
]
var items = {
    audio: [["Output", "volume speakers headphones громкость наушники колонки"], ["Microphone", "mic input gain микрофон вход"],
            ["Applications", "app volume streams приложения потоки"]],
    network: [["Wi-Fi", "wireless wlan вайфай беспроводная"], ["Wired", "ethernet lan кабель проводная"],
              ["Bluetooth", "pair headset блютуз"], ["Advanced network settings", "nm nmtui сеть"]],
    displays: [["Arrangement", "position layout monitors расположение мониторы"], ["Reset to defaults", "reset сброс"]],
    devices: [["Keyboard", "layout repeat раскладка клавиатура"], ["Mouse", "pointer speed мышь скорость"], ["Touchpad", "tap scroll тачпад"],
              ["Natural scrolling", "scroll direction прокрутка"], ["Printers", "print принтер печать"], ["Scanners", "scan сканер"]],
    power: [["Lock and sleep", "lock suspend блокировка сон"], ["Screen off", "dpms display off экран выключить"],
            ["Keep awake", "caffeine inhibit не засыпать"], ["Battery", "charge батарея заряд"], ["Brightness", "яркость"], ["Power menu", "reboot shutdown перезагрузка выключение"]],
    themes: [["Palette", "colors palette цвета палитра"], ["Light & dark", "schedule sun day night светлая темная расписание"],
             ["Wallpaper", "wallpaper background обои фон"], ["Open wallpaper gallery", "gallery picker галерея"],
             ["Saved looks", "preset look сохраненный вид пресет"]],
    panels: [["UI font", "font typeface шрифт"], ["UI metrics", "radius rounding geometry spacing радиус скругление геометрия"],
             ["Panel size", "height length высота длина"], ["Panel opacity", "transparency opacity прозрачность"],
             ["Rounded corners", "corner radius скругление углы"], ["Panel shape", "islands floating flat острова"],
             ["Windows & motion", "animation анимация окна"], ["Between tiled windows", "gaps гапы отступы"]],
    apps: [["Icon theme", "icons значки иконки"], ["Pinned applications", "pin launchers закрепить"]],
    session: [["Capture shortcuts", "screenshot record скриншот запись"], ["Autostart", "startup автозапуск"],
              ["Apps on workspaces", "workspace rules рабочие столы"], ["Default apps", "browser mail default по умолчанию браузер"]],
    system: [["NixOS", "generation rebuild update поколение обновление"], ["AI / GPU", "ollama cuda nvidia нейросети видеокарта"], ["Voice and machine spirit", "voice whisper dictation spirit agent claude codex голос диктовка дух"],
             ["Time zone", "timezone clock часовой пояс время"], ["Night light", "warm blue light ночной"]],
    modes: [["Recording", "music studio daw музыка студия запись"], ["Restore Normal", "normal reset обычный"]]
}
function matches(query, id) {
    const words = query.toLowerCase().trim().split(/\s+/).filter(Boolean)
    if (!words.length) return []
    return (items[id] || []).filter(i => words.every(w => (i[0] + " " + i[1]).toLowerCase().includes(w)))
        .slice(0, 3).map(i => ({target: i[0], title: i[2] || i[0]}))
}
function search(query) {
    const words = query.toLowerCase().trim().split(/\s+/).filter(Boolean)
    return pages.filter(p => words.every(word => (p.title + " " + p.keywords).toLowerCase().includes(word))
        || matches(query, p.id).length > 0)
}
function page(id) { return pages.find(p => p.id === id) || pages[0] }
function target(query) {
    const text = query.toLowerCase()
    const targets = [[/font size|размер шрифт/, "Font size (pt)"], [/font|шрифт/, "UI font"],
        [/spacing unit|шаг отступ/, "Spacing unit"], [/focus ring/, "Focus ring width"],
        [/radius|rounding|metrics|geometry|радиус|скруглен|метрик|геометр/, "UI metrics"],
        [/gap|гап|отступ/, "Between tiled windows"], [/microphone|микрофон/, "Microphone"],
        [/volume|громкость|output|наушники/, "Output"],
        [/bluetooth/, "Bluetooth"], [/keyboard|расклад|клавиат/, "Keyboard"], [/wallpaper|обои/, "Wallpaper"],
        [/battery|батаре/, "Battery"], [/idle|автоблок|засып|sleep/, "Lock and sleep"]]
    for (const pair of targets) if (pair[0].test(text)) return pair[1]
    return ""
}
