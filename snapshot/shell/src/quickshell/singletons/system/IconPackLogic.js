.pragma library

function normalize(value) {
    let text = String(value || "").trim();
    try { text = decodeURIComponent(text); } catch (error) {}
    text = text.split("?")[0].split("#")[0];
    text = text.substring(text.lastIndexOf("/") + 1).toLowerCase();
    text = text.replace(/\.(desktop|png|svg|svgz|xpm|ico)$/i, "");
    text = text.replace(/^evhos-(satin|facet|mono-soft|pixel-arcade|type-density|sticker-pals|icon)-/, "");
    text = text.replace(/([_-](tray|indicator|status|icon|idle|active|attention|panel|symbolic))+$/i, "");
    return text.replace(/[^a-z0-9]/g, "");
}

function lookupFor(catalog) {
    let result = Object.create(null);
    let designs = catalog.designs || [];
    for (let design of designs) result[normalize(design)] = design;
    for (let mapping of [catalog.aliases || {}, catalog.desktop_icons || {}]) {
        for (let key of Object.keys(mapping)) {
            if (designs.includes(mapping[key])) result[normalize(key)] = mapping[key];
        }
    }
    for (let pair of [["OpenAI","chatgpt"],["Codex","chatgpt"],["Microsoft Teams","teams"],["TwintailLauncher","twintail"],["OBS Studio","obs"],["btop++","btop"]]) {
        if (designs.includes(pair[1])) result[normalize(pair[0])] = pair[1];
    }
    return result;
}

function designFor(values, lookup) {
    for (let value of values) {
        let design = lookup[normalize(value)];
        if (design) return design;
    }
    return "";
}

function trayDesign(item, lookup) {
    if (!item) return "";
    let exact = designFor([item.id, item.title, item.tooltipTitle, item.icon], lookup);
    if (exact) return exact;
    let title = [item.title || "", item.tooltipTitle || ""].join(" ");
    for (let pair of [[/\bchatgpt\b|\bopenai\b|\bcodex\b/i,"chatgpt"],[/\bcursor\b/i,"cursor"],[/\bslack\b/i,"slack"],[/\bmicrosoft\s+teams\b/i,"teams"],[/\bbrave\b/i,"brave"],[/\bpostman\b/i,"postman"],[/\btwintaillauncher\b/i,"twintail"],[/\bshelly\b/i,"shelly"],[/\bobs\s+studio\b/i,"obs"]]) {
        if (pair[0].test(title) && lookup[normalize(pair[1])]) return pair[1];
    }
    return "";
}

function effectiveTheme(pack, lightBackground) {
    return ["EvhOs-Mono-Soft", "EvhOs-Type-Density"].includes(pack) && lightBackground ? pack + "-Light" : pack;
}

function fileUrl(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/"); }
