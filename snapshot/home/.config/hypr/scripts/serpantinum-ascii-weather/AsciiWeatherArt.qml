import QtQuick

Item {
    id: art
    objectName: "asciiWeatherArt"
    property string condition: "cloud"
    property bool active: false
    property bool interacting: false
    property color ink: "white"
    property int frame: 0
    property real hoverAmount: interacting ? 1 : 0
    Behavior on hoverAmount { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    readonly property bool animating: active && interacting
    Timer {
        interval: 100
        running: art.animating
        repeat: true
        onTriggered: art.frame = (art.frame + 1) % 120
    }
    function ellipse(x, y, cx, cy, rx, ry) {
        return Math.pow((x-cx)/rx, 2) + Math.pow((y-cy)/ry, 2) <= 1;
    }
    function glyphGrid() {
        let lines = [], cols = 63, rows = 27;
        let drift = Math.sin(frame * 0.10) * 0.018 * hoverAmount;
        for (let row = 0; row < rows; row++) {
            let line = "";
            for (let col = 0; col < cols; col++) {
                let x = (col / (cols-1) * 2 - 1) - drift;
                let y = (row / (rows-1) * 1.32 - 0.66);
                let cloud = ellipse(x,y,-0.39,0.15,0.32,0.25) || ellipse(x,y,0,0.0,0.34,0.39) || ellipse(x,y,0.36,0.17,0.38,0.24) || (x>-.49 && x<.52 && y>0.08 && y<0.35);
                let char = " ";
                if (condition === "sun") {
                    let r = Math.hypot(x,y*1.08);
                    let angle = Math.atan2(y*1.08,x) + Math.sin(frame*0.025)*0.07*hoverAmount;
                    if (r<0.30 || (r>0.38 && r<0.51 && Math.cos(angle*12)>0.80)) char = ".";
                } else if (condition === "moon") {
                    // Round moon proportions compensate for the character grid.
                    let disc = ellipse(x,y,-0.10,0,0.29,0.48);
                    let crater = ellipse(x,y,-0.19,-0.14,0.035,0.06)
                              || ellipse(x,y,-0.03,0.15,0.045,0.07)
                              || ellipse(x,y,-0.16,0.27,0.025,0.04);
                    if (disc && !crater) char = ".";
                    // Small four-point stars make the clear-night meaning explicit.
                    for (let star of [{c:9,r:8},{c:48,r:6},{c:51,r:20}]) {
                        let dx = Math.abs(col-star.c), dy = Math.abs(row-star.r);
                        if (dx===0 && dy===0) char = "+";
                        else if ((dx===0 && dy<=2) || (dy===0 && dx<=2)) char = ".";
                    }
                } else if (condition === "fog") {
                    if (row>=7 && row<=22 && row%4<2 && Math.abs(x)<0.67-Math.abs(row-15)*0.025) char = row%4===0 ? "." : "-";
                } else {
                    let wet = condition === "rain" || condition === "snow" || condition === "storm";
                    if (cloud && (!wet || y<0.18)) char = ".";
                    if (wet && y>=0.24 && y<0.59 && Math.abs(x)<0.55) {
                        let shift = interacting ? Math.floor(frame/2) : 0;
                        if ((col + Math.floor(row/3))%8===0 && (row+shift)%5<2) char = condition==="snow" ? "+" : "/";
                    }
                    if (condition === "storm" && y>0.12 && y<0.59 && Math.abs(x-(0.19-y*0.45 + (y>0.35?0.14:0)))<0.05) char = "*";
                }
                line += char;
            }
            lines.push(line);
        }
        return lines.join("\n");
    }
    Text {
        id: glyphs
        anchors.centerIn: parent
        text: art.glyphGrid()
        color: art.ink
        opacity: 0.76 + art.hoverAmount * 0.15
        font.family: "monospace"
        font.pixelSize: 13
        font.letterSpacing: 1.6
        font.weight: Font.DemiBold
        lineHeightMode: Text.FixedHeight
        lineHeight: 9
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignLeft
        scale: Math.min(art.width / Math.max(1, implicitWidth), art.height / Math.max(1, implicitHeight)) * (1 + art.hoverAmount * 0.015)
        transform: Translate { y: -art.hoverAmount * 2 }
        renderType: Text.NativeRendering
    }
}
