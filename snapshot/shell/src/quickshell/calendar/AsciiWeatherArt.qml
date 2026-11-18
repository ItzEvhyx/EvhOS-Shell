import QtQuick

Item {
    id: art
    objectName: "asciiWeatherArt"
    // evhos-weather-art-v2: heavier ASCII inside the existing layout allocation.
    clip: true
    property string condition: "cloud"
    property bool active: false
    property bool interacting: false
    property color ink: "white"
    property int frame: 0
    property real hoverAmount: interacting ? 1 : 0
    Behavior on hoverAmount { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    readonly property bool animating: active && interacting
    Timer {
        interval: 120
        running: art.animating
        repeat: true
        onTriggered: art.frame = (art.frame + 1) % 120
    }
    function ellipse(x, y, cx, cy, rx, ry) {
        return Math.pow((x-cx)/rx, 2) + Math.pow((y-cy)/ry, 2) <= 1;
    }
    function glyphGrid() {
        let lines = [], cols = 49, rows = 23;
        let drift = Math.sin(frame * 0.10) * 0.016 * hoverAmount;
        for (let row = 0; row < rows; row++) {
            let line = "";
            for (let col = 0; col < cols; col++) {
                let x = (col / (cols-1) * 2 - 1) - drift;
                let y = row / (rows-1) * 1.36 - 0.68;
                let cloud = ellipse(x,y,-0.40,0.15,0.34,0.27) || ellipse(x,y,0,-0.015,0.36,0.41)
                    || ellipse(x,y,0.36,0.17,0.39,0.26) || (x>-.51 && x<.54 && y>0.08 && y<0.36);
                let char = " ";
                if (condition === "sun") {
                    let r = Math.hypot(x,y*1.06);
                    let angle = Math.atan2(y*1.06,x) + Math.sin(frame*0.025)*0.07*hoverAmount;
                    if (r<0.31) char = "#";
                    else if (r>0.38 && r<0.55 && Math.cos(angle*10)>0.68) char = "+";
                } else if (condition === "moon") {
                    let disc = ellipse(x,y,-0.10,0,0.30,0.47);
                    let crater = ellipse(x,y,-0.19,-0.14,0.045,0.065)
                        || ellipse(x,y,-0.03,0.15,0.05,0.075) || ellipse(x,y,-0.16,0.27,0.03,0.045);
                    if (disc && !crater) char = "#";
                    for (let star of [{c:6,r:6},{c:39,r:4},{c:42,r:18}]) {
                        let dx = Math.abs(col-star.c), dy = Math.abs(row-star.r);
                        if ((dx===0 && dy<=1) || (dy===0 && dx<=1)) char = "+";
                    }
                } else if (condition === "fog") {
                    if (row>=5 && row<=19 && row%4<2 && Math.abs(x)<0.70-Math.abs(row-12)*0.025)
                        char = "=";
                } else {
                    let wet = condition === "rain" || condition === "snow" || condition === "storm";
                    if (condition === "partly-cloudy-night") {
                        if (ellipse(x,y,-0.33,-0.30,0.26,0.30) && !ellipse(x,y,-0.22,-0.39,0.25,0.28)) char = "#";
                    } else if (condition === "partly-cloudy") {
                        let r = Math.hypot(x+0.33,(y+0.30)*1.04);
                        if (r<0.25 || (r>0.30 && r<0.40 && Math.cos(Math.atan2(y+0.30,x+0.33)*10)>0.72)) char = "+";
                    }
                    if (cloud && (!wet || y<0.15)) char = "#";
                    if (wet && y>=0.24 && y<0.62 && Math.abs(x)<0.59) {
                        let shift = interacting ? Math.floor(frame/2) : 0;
                        if ((col + Math.floor(row/3))%6===0 && (row+shift)%4<2)
                            char = condition==="snow" ? "*" : "/";
                    }
                    if (condition === "storm" && y>0.12 && y<0.62
                        && Math.abs(x-(0.19-y*0.45 + (y>0.35?0.14:0)))<0.07) char = "@";
                }
                line += char;
            }
            lines.push(line);
        }
        // Fit the symbol itself, rather than shrinking it around empty padding.
        let first = lines.findIndex(line => /\S/.test(line));
        if (first < 0) return "";
        let last = lines.length-1;
        while (last>first && !/\S/.test(lines[last])) last--;
        let left=cols, right=0;
        for (let i=first; i<=last; i++) {
            if (!/\S/.test(lines[i])) continue;
            left=Math.min(left,lines[i].search(/\S/));
            right=Math.max(right,lines[i].search(/\s*$/));
        }
        return lines.slice(first,last+1).map(line => line.slice(left,right)).join("\n");
    }
    Text {
        id: glyphs
        anchors.centerIn: parent
        text: art.glyphGrid()
        color: art.ink
        opacity: 0.96 + art.hoverAmount * 0.04
        font.family: "monospace"
        font.pixelSize: 16
        font.letterSpacing: 0.3
        font.weight: Font.Bold
        lineHeightMode: Text.FixedHeight
        lineHeight: 12
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignLeft
        scale: Math.max(0, Math.min((art.width-8) / Math.max(1,implicitWidth), (art.height-8) / Math.max(1,implicitHeight))) * 0.96
        renderType: Text.QtRendering
    }
}
