import QtQuick

Canvas {
    id: graph
    property var samples: []
    property real maximum: 100
    property color ink: "white"
    onSamplesChanged: requestPaint()
    onMaximumChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        let ctx=getContext("2d");
        ctx.clearRect(0,0,width,height);
        if (samples.length === 0 || width<=0 || height<=0) return;
        // Fit the available real samples; retain at most 60 readings.
        let points=[];
        for (let i=0;i<samples.length;i++) {
            let value=samples[i];
            if (value===null || value===undefined || !Number.isFinite(value)) continue;
            points.push({x:(samples.length===1?1:i/(samples.length-1))*(width-2)+1,
                         y:Math.max(2,Math.min(height-2,height-2-value/maximum*(height-4)))});
        }
        if (!points.length) return;
        if (points.length===1) {
            ctx.fillStyle=ink;
            ctx.beginPath();ctx.arc(points[0].x,points[0].y,1.5,0,Math.PI*2);ctx.fill();
            return;
        }
        let gradient=ctx.createLinearGradient(0,0,0,height);
        gradient.addColorStop(0,Qt.alpha(ink,0.22));
        gradient.addColorStop(1,Qt.alpha(ink,0.015));
        ctx.beginPath();ctx.moveTo(points[0].x,height);
        for(let p of points)ctx.lineTo(p.x,p.y);
        ctx.lineTo(points[points.length-1].x,height);ctx.closePath();
        ctx.fillStyle=gradient;ctx.fill();
        ctx.beginPath();ctx.moveTo(points[0].x,points[0].y);
        for(let i=1;i<points.length;i++)ctx.lineTo(points[i].x,points[i].y);
        ctx.strokeStyle=ink;ctx.lineWidth=1.3;ctx.lineJoin="round";ctx.stroke();
    }
}
