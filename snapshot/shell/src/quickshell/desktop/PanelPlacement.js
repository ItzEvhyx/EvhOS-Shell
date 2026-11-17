.pragma library

// All coordinates are logical screen pixels, including the bar's actual margins.
function place(layout, bar, screenWidth, screenHeight, scale) {
    let result = Object.assign({}, layout);
    let padding = Math.max(1, Math.round(6 * scale));
    let gap = Math.max(1, Math.round(8 * scale));
    let minX = padding, minY = padding;
    let maxX = screenWidth - padding, maxY = screenHeight - padding;
    if (bar.position === "top") minY = Math.max(minY, bar.y + bar.height + gap);
    else if (bar.position === "bottom") maxY = Math.min(maxY, bar.y - gap);
    else if (bar.position === "left") minX = Math.max(minX, bar.x + bar.width + gap);
    else if (bar.position === "right") maxX = Math.min(maxX, bar.x - gap);
    result.w = Math.max(1, Math.min(result.w, maxX - minX));
    result.h = Math.max(1, Math.min(result.h, maxY - minY));
    if (bar.position === "top") result.ry = minY;
    else if (bar.position === "bottom") result.ry = maxY - result.h;
    else if (bar.position === "left") result.rx = minX;
    else if (bar.position === "right") result.rx = maxX - result.w;
    result.rx = Math.round(Math.max(minX, Math.min(maxX - result.w, result.rx)));
    result.ry = Math.round(Math.max(minY, Math.min(maxY - result.h, result.ry)));
    return result;
}
