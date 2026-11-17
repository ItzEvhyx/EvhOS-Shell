import QtQuick

// Uses exactly the clock badge's three-column, five-row dot alphabet.
Canvas {
    id: matrix
    property string text: ""
    property color color: "white"
    property real pixelSize: 16
    property real letterSpacing: 0
    property int horizontalAlignment: Text.AlignLeft
    property int wrapMode: Text.NoWrap
    property int maximumLineCount: 1
    property int elide: Text.ElideNone
    readonly property real dotSize: pixelSize / 7.0
    readonly property real dotGap: dotSize * 0.5
    readonly property real characterWidth: 3 * dotSize + 2 * dotGap
    readonly property real characterGap: dotSize + letterSpacing
    readonly property string normalizedText: text.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase()
    implicitWidth: normalizedText.length * (characterWidth + characterGap) - characterGap
    implicitHeight: Math.max(pixelSize, lines.length * pixelSize * 1.3 - pixelSize * 0.3)
    readonly property var lines: layoutLines()
    readonly property var patterns: ({
            "°": [1,1,1, 1,0,1, 1,1,1, 0,0,0, 0,0,0],
            "·": [0,0,0, 0,0,0, 0,1,0, 0,0,0, 0,0,0],
            "+": [0,0,0, 0,1,0, 1,1,1, 0,1,0, 0,0,0],
            "0": [1,1,1, 1,0,1, 1,0,1, 1,0,1, 1,1,1],
            "1": [0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1],
            "2": [1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1],
            "3": [1,1,1, 0,0,1, 1,1,1, 0,0,1, 1,1,1],
            "4": [1,0,1, 1,0,1, 1,1,1, 0,0,1, 0,0,1],
            "5": [1,1,1, 1,0,0, 1,1,1, 0,0,1, 1,1,1],
            "6": [1,1,1, 1,0,0, 1,1,1, 1,0,1, 1,1,1],
            "7": [1,1,1, 0,0,1, 0,0,1, 0,0,1, 0,0,1],
            "8": [1,1,1, 1,0,1, 1,1,1, 1,0,1, 1,1,1],
            "9": [1,1,1, 1,0,1, 1,1,1, 0,0,1, 1,1,1],
            ":": [0,0,0, 0,1,0, 0,0,0, 0,1,0, 0,0,0],
            ".": [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,1,0],
            "-": [0,0,0, 0,0,0, 1,1,1, 0,0,0, 0,0,0],
            "/": [0,0,1, 0,0,1, 0,1,0, 1,0,0, 1,0,0],
            ",": [0,0,0, 0,0,0, 0,0,0, 0,1,0, 1,0,0],
            " ": [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0],
            "A": [0,1,0, 1,0,1, 1,1,1, 1,0,1, 1,0,1],
            "B": [1,1,0, 1,0,1, 1,1,0, 1,0,1, 1,1,0],
            "C": [0,1,1, 1,0,0, 1,0,0, 1,0,0, 0,1,1],
            "D": [1,1,0, 1,0,1, 1,0,1, 1,0,1, 1,1,0],
            "E": [1,1,1, 1,0,0, 1,1,0, 1,0,0, 1,1,1],
            "F": [1,1,1, 1,0,0, 1,1,0, 1,0,0, 1,0,0],
            "G": [0,1,1, 1,0,0, 1,0,1, 1,0,1, 0,1,1],
            "H": [1,0,1, 1,0,1, 1,1,1, 1,0,1, 1,0,1],
            "I": [1,1,1, 0,1,0, 0,1,0, 0,1,0, 1,1,1],
            "J": [0,0,1, 0,0,1, 0,0,1, 1,0,1, 0,1,0],
            "K": [1,0,1, 1,1,0, 1,0,0, 1,1,0, 1,0,1],
            "L": [1,0,0, 1,0,0, 1,0,0, 1,0,0, 1,1,1],
            "M": [1,0,1, 1,1,1, 1,0,1, 1,0,1, 1,0,1],
            "N": [1,1,0, 1,0,1, 1,0,1, 1,0,1, 1,0,1],
            "O": [0,1,0, 1,0,1, 1,0,1, 1,0,1, 0,1,0],
            "P": [1,1,0, 1,0,1, 1,1,0, 1,0,0, 1,0,0],
            "Q": [0,1,0, 1,0,1, 1,0,1, 0,1,1, 0,0,1],
            "R": [1,1,0, 1,0,1, 1,1,0, 1,0,1, 1,0,1],
            "S": [0,1,1, 1,0,0, 0,1,0, 0,0,1, 1,1,0],
            "T": [1,1,1, 0,1,0, 0,1,0, 0,1,0, 0,1,0],
            "U": [1,0,1, 1,0,1, 1,0,1, 1,0,1, 0,1,0],
            "V": [1,0,1, 1,0,1, 1,0,1, 1,0,1, 0,1,0],
            "W": [1,0,1, 1,0,1, 1,0,1, 1,1,1, 1,0,1],
            "X": [1,0,1, 1,0,1, 0,1,0, 1,0,1, 1,0,1],
            "Y": [1,0,1, 1,0,1, 0,1,0, 0,1,0, 0,1,0],
            "Z": [1,1,1, 0,0,1, 0,1,0, 1,0,0, 1,1,1]
        })
    function layoutLines() {
        let limit = Math.max(1, Math.floor((Math.max(1,width) + characterGap)/(characterWidth + characterGap)));
        let source = normalizedText;
        if (wrapMode === Text.NoWrap) {
            if (elide===Text.ElideRight && source.length>limit) source=source.slice(0,Math.max(0,limit-3))+"...";
            return [source];
        }
        let result=[], current="";
        for (let word of source.split(/\s+/)) {
            if (current && current.length+1+word.length>limit) { result.push(current); current=""; }
            while (word.length>limit) { result.push(word.slice(0,limit)); word=word.slice(limit); }
            current += (current ? " " : "")+word;
        }
        if(current)result.push(current);
        if (result.length>maximumLineCount) {
            result=result.slice(0,maximumLineCount);
            result[result.length-1]=result[result.length-1].slice(0,Math.max(0,limit-3))+"...";
        }
        return result.length?result:[""];
    }
    onLinesChanged: requestPaint()
    onColorChanged: requestPaint()
    onPixelSizeChanged: requestPaint()
    onLetterSpacingChanged: requestPaint()
    onHorizontalAlignmentChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        let ctx=getContext("2d");ctx.clearRect(0,0,width,height);
        let d=dotSize,g=dotGap,pitch=characterWidth+characterGap;
        let gridHeight=d*5+g*4;
        let totalHeight=gridHeight+(lines.length-1)*pixelSize*1.3;
        let startY=Math.max(0,(height-totalHeight)/2);
        for(let lineIndex=0;lineIndex<lines.length;lineIndex++) {
            let line=lines[lineIndex];
            let lineWidth=Math.max(0,line.length*pitch-characterGap);
            let startX=horizontalAlignment===Text.AlignHCenter ? Math.max(0,(width-lineWidth)/2) : (horizontalAlignment===Text.AlignRight ? Math.max(0,width-lineWidth) : 0);
            for(let c=0;c<line.length;c++) {
                let ch=line[c],pattern=patterns[ch];
                if (!pattern) {
                    ctx.fillStyle=color;ctx.font=Math.round(pixelSize)+"px monospace";
                    ctx.fillText(ch,startX+c*pitch,startY+lineIndex*pixelSize*1.3+gridHeight);
                    continue;
                }
                if(ch===" ")continue;
                for(let i=0;i<15;i++) {
                    ctx.fillStyle=Qt.alpha(color,pattern[i]===1 ? 1 : 0.055);
                    ctx.beginPath();
                    ctx.arc(startX+c*pitch+(i%3)*(d+g)+d/2,startY+lineIndex*pixelSize*1.3+Math.floor(i/3)*(d+g)+d/2,d*0.46,0,Math.PI*2);
                    ctx.fill();
                }
            }
        }
    }
}
