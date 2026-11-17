.pragma library

function workspaceIds(workspaces, focusedId) {
    let occupied = [];
    let available = [];
    for (let workspace of workspaces) {
        if (!workspace || workspace.id <= 0) continue;
        let windows = workspace.toplevels && workspace.toplevels.values ? workspace.toplevels.values : [];
        let count = workspace.lastIpcObject ? Number(workspace.lastIpcObject.windows || 0) : 0;
        if (windows.length > 0 || count > 0 || workspace.id === focusedId || workspace.active)
            occupied.push(workspace.id);
        else available.push(workspace.id);
    }
    if (focusedId > 0 && occupied.indexOf(focusedId) < 0) occupied.push(focusedId);
    if (occupied.length === 0) occupied.push(1);
    available.sort((a,b) => a-b);
    let extra = available.length ? available[0] : Math.max.apply(null, occupied) + 1;
    if (occupied.indexOf(extra) < 0) occupied.push(extra);
    return occupied.sort((a,b) => a-b);
}

function moveIndex(index, key, columns, count) {
    if (count < 1) return -1;
    index = Math.max(0, Math.min(count - 1, index));
    if (key === "left") return index % columns > 0 ? index - 1 : index;
    if (key === "right") return index % columns < columns - 1 && index + 1 < count ? index + 1 : index;
    if (key === "up") return index >= columns ? index - columns : index;
    if (key === "down") return Math.floor(index / columns) < Math.floor((count - 1) / columns) ? Math.min(index + columns, count - 1) : index;
    if (key === "home") return 0;
    if (key === "end") return count - 1;
    return index;
}

function layout(width, height, count, scale) {
    let gap = 22 * scale;
    let columns = Math.min(width < 850 * scale ? 2 : 3, Math.max(1, count));
    let availableWidth = Math.max(1, width - 80 * scale);
    let availableHeight = Math.max(120 * scale, height - 170 * scale);
    let rows = Math.ceil(Math.max(1, count) / columns);
    let maxWidth = (availableWidth - (columns - 1) * gap) / columns;
    let heightWidth = ((availableHeight - (Math.min(3,rows)-1)*gap) / Math.min(3,rows) - 44*scale) * 16/9;
    let cardWidth = Math.floor(Math.max(Math.min(240*scale,maxWidth),Math.min(520*scale,maxWidth,heightWidth)));
    let cardHeight = Math.round(cardWidth * 9/16 + 44*scale);
    return {columns:columns, gap:gap, cardWidth:cardWidth, cardHeight:cardHeight,
            width:columns*cardWidth+(columns-1)*gap,
            height:Math.min(availableHeight,rows*cardHeight+(rows-1)*gap)};
}

function monitorRect(monitor) {
    let data = monitor && monitor.lastIpcObject ? monitor.lastIpcObject : {};
    let scale = Number(data.scale || (monitor ? monitor.scale : 1) || 1);
    let width = Number(data.width || (monitor ? monitor.width : 1920) || 1920) / scale;
    let height = Number(data.height || (monitor ? monitor.height : 1080) || 1080) / scale;
    if (Number(data.transform || 0) % 2 === 1) { let swap = width; width = height; height = swap; }
    return {x:Number(data.x || (monitor ? monitor.x : 0) || 0), y:Number(data.y || (monitor ? monitor.y : 0) || 0), width:width, height:height};
}

function windowRect(client, monitor, width, height) {
    let data = client && client.lastIpcObject ? client.lastIpcObject : {};
    let rect = monitorRect(monitor);
    let at = data.at || [rect.x, rect.y];
    let size = data.size || [rect.width, rect.height];
    return {x:(at[0]-rect.x)/rect.width*width, y:(at[1]-rect.y)/rect.height*height,
            width:Math.max(1,size[0]/rect.width*width), height:Math.max(1,size[1]/rect.height*height)};
}
