.pragma library

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

function key(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
}

function easter(year) {
    const a = year % 19, b = Math.floor(year / 100), c = year % 100;
    const d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25);
    const g = Math.floor((b - f + 1) / 3), h = (19 * a + b - d - g + 15) % 30;
    const i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
    const m = Math.floor((a + 11 * h + 22 * l) / 451);
    const month = Math.floor((h + l - 7 * m + 114) / 31);
    return new Date(year, month - 1, ((h + l - 7 * m + 114) % 31) + 1);
}

function nth(year, month, weekday, n) {
    if (n < 0) {
        const last = new Date(year, month + 1, 0);
        return new Date(year, month, last.getDate() - (last.getDay() - weekday + 7) % 7);
    }
    const first = new Date(year, month, 1);
    return new Date(year, month, 1 + (weekday - first.getDay() + 7) % 7 + 7 * (n - 1));
}

function shift(date, days) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
}

function forYear(year) {
    const out = {};
    function add(country, date, name) {
        const k = key(date);
        (out[k] = out[k] || []).push({ country: country, name: name });
    }
    const sunday = easter(year);
    const lt = [
        [0, 1, "New Year's Day"], [1, 16, "Restoration of the State Day"],
        [2, 11, "Restoration of Independence Day"], [4, 1, "Labour Day"], [5, 24, "St John's Day"],
        [6, 6, "Statehood Day"], [7, 15, "Assumption Day"], [10, 1, "All Saints' Day"],
        [10, 2, "All Souls' Day"], [11, 24, "Christmas Eve"], [11, 25, "Christmas Day"],
        [11, 26, "Second Day of Christmas"]
    ];
    for (const [m, d, name] of lt)
        add("LT", new Date(year, m, d), name);
    add("LT", sunday, "Easter Sunday");
    add("LT", shift(sunday, 1), "Easter Monday");
    add("LT", nth(year, 4, 0, 1), "Mother's Day");
    add("LT", nth(year, 5, 0, 1), "Father's Day");

    const ie = [[0, 1, "New Year's Day"], [2, 17, "St Patrick's Day"], [11, 25, "Christmas Day"], [11, 26, "St Stephen's Day"]];
    for (const [m, d, name] of ie)
        add("IE", new Date(year, m, d), name);
    if (year >= 2023)
        add("IE", new Date(year, 1, 1).getDay() === 5 ? new Date(year, 1, 1) : nth(year, 1, 1, 1), "St Brigid's Day");
    add("IE", shift(sunday, 1), "Easter Monday");
    add("IE", nth(year, 4, 1, 1), "May Bank Holiday");
    add("IE", nth(year, 5, 1, 1), "June Bank Holiday");
    add("IE", nth(year, 7, 1, 1), "August Bank Holiday");
    add("IE", nth(year, 9, 1, -1), "October Bank Holiday");
    return out;
}
