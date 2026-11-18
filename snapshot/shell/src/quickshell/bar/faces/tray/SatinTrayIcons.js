.pragma library

function normalize(value) {
    let text = String(value || "").trim().toLowerCase();
    if (text.startsWith("file://")) text = text.substring(7);
    if (text.startsWith("image://icon/")) text = text.substring(13);
    text = text.split("?")[0].split("#")[0];
    text = text.substring(text.lastIndexOf("/") + 1);
    text = text.replace(/\.(desktop|png|svg|svgz|xpm|ico)$/i, "");
    text = text.replace(/^evhos-satin-/, "");
    text = text.replace(/([_-](tray|indicator|status|icon|idle|active|attention|panel|symbolic))+$/i, "");
    return text.replace(/[^a-z0-9]/g, "");
}

function lookupFor(manifest) {
    let lookup = Object.create(null);
    if (!manifest || !Array.isArray(manifest.designs)) return lookup;
    let designs = Object.create(null);
    for (let design of manifest.designs) {
        if (!/^[a-z0-9-]+$/.test(design)) continue;
        designs[design] = true;
        lookup[normalize(design)] = design;
    }
    for (let aliases of [manifest.aliases || {}, manifest.desktop_icons || {}]) {
        for (let key of Object.keys(aliases)) {
            if (designs[aliases[key]]) lookup[normalize(key)] = aliases[key];
        }
    }
    // Common names published by tray implementations rather than desktop files.
    for (let entry of [
        ["OpenAI", "chatgpt"], ["Codex", "chatgpt"],
        ["Microsoft Teams", "teams"], ["TwintailLauncher", "twintail"],
        ["OBS Studio", "obs"], ["btop++", "btop"]
    ]) {
        if (designs[entry[1]]) lookup[normalize(entry[0])] = entry[1];
    }
    return lookup;
}

function designFor(item, lookup) {
    if (!item || !lookup) return "";
    // Exact app identity wins over tooltip text, including unread badges/titles.
    let candidates = [item.id, item.title, item.tooltipTitle, item.icon];
    for (let candidate of candidates) {
        let match = lookup[normalize(candidate)];
        if (match) return match;
    }
    // Electron appindicators can have anonymous numeric IDs and descriptive titles.
    let title = [item.title || "", item.tooltipTitle || ""].join(" ");
    let brands = [
        [/\bchatgpt\b|\bopenai\b|\bcodex\b/i, "chatgpt"],
        [/\bcursor\b/i, "cursor"], [/\bslack\b/i, "slack"],
        [/\bmicrosoft\s+teams\b/i, "teams"], [/\bbrave\b/i, "brave"],
        [/\bpostman\b/i, "postman"], [/\btwintaillauncher\b/i, "twintail"],
        [/\bshelly\b/i, "shelly"], [/\bobs\s+studio\b/i, "obs"]
    ];
    for (let brand of brands) {
        if (brand[0].test(title) && lookup[normalize(brand[1])]) return brand[1];
    }
    return "";
}
