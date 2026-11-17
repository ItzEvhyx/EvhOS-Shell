import QtQuick
import "../"

// A fine, mirrored silhouette driven by the player's existing Cava subscription.
Canvas {
    id: wave
    objectName: "playerBackgroundWaveform"
    property bool active: false
    property var levels: []
    property color ink: ThemeBackend.text
    property var smoothed: []
    property bool settling: false
    readonly property int sampleCount: 64
    property real energy: 0

    function levelAt(index) {
        if (!active || !levels || levels.length === 0) return 0;
        let pos = index / (sampleCount - 1) * (levels.length - 1);
        let lower = Math.floor(pos);
        let a = Number(levels[lower]) || 0;
        let b = Number(levels[Math.min(levels.length - 1, lower + 1)]) || 0;
        return Math.max(0, Math.min(1, a + (b - a) * (pos - lower)));
    }
    onLevelsChanged: if (active) settling = true
    onActiveChanged: {
        if (active) settling = true;
        else {
            settling = false;
            smoothed = [];
            energy = 0;
            requestPaint();
        }
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onInkChanged: requestPaint()
    Component.onCompleted: if (active) settling = true

    Timer {
        interval: 33
        repeat: true
        running: wave.active && wave.visible && wave.settling
        onTriggered: {
            let next = [], sum = 0, moving = false;
            for (let i = 0; i < wave.sampleCount; i++) {
                let target = wave.levelAt(i);
                let old = wave.smoothed[i] || 0;
                let delta = target - old;
                let value = Math.abs(delta) < 0.001 ? target : old + delta * (delta > 0 ? 0.58 : 0.17);
                if (Math.abs(target - value) > 0.001) moving = true;
                next.push(value);
                sum += value;
            }
            wave.energy = sum / wave.sampleCount;
            wave.smoothed = next;
            wave.settling = moving;
            wave.requestPaint();
        }
    }

    onPaint: {
        let ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (!active || width < 2 || height < 2 || energy < 0.001) return;
        let cy = height * 0.5;
        let pad = width * 0.025;
        let usable = width - pad * 2;
        let count = 384;
        let points = [];
        for (let i = 0; i <= count; i++) {
            let t = i / count;
            let pos = t * (sampleCount - 1);
            let a = Math.floor(pos), f = pos - a;
            let lo = smoothed[a] || 0;
            let hi = smoothed[Math.min(sampleCount - 1, a + 1)] || 0;
            // Keep sharp transients, with a feathered tail towards both ends.
            let value = lo + (hi - lo) * f;
            let envelope = Math.pow(Math.sin(t * Math.PI), 0.8);
            let amplitude = Math.pow(Math.max(0, value), 1.65) * height * 0.43 * envelope;
            points.push({x: pad + usable * t, a: amplitude});
        }
        function silhouette(multiplier) {
            ctx.beginPath();
            ctx.moveTo(points[0].x, cy);
            for (let i = 0; i < points.length; i++) ctx.lineTo(points[i].x, cy - points[i].a * multiplier);
            for (let i = points.length - 1; i >= 0; i--) ctx.lineTo(points[i].x, cy + points[i].a * multiplier);
            ctx.closePath();
        }
        // Several translucent silhouettes give a soft halo without a heavy glow.
        silhouette(1.22);
        ctx.fillStyle = Qt.alpha(ink, 0.045);
        ctx.fill();
        silhouette(1.08);
        ctx.fillStyle = Qt.alpha(ink, 0.075);
        ctx.fill();
        silhouette(1);
        let fill = ctx.createLinearGradient(0, cy - height * 0.43, 0, cy + height * 0.43);
        fill.addColorStop(0, Qt.alpha(ink, 0.08));
        fill.addColorStop(0.5, Qt.alpha(ink, 0.46));
        fill.addColorStop(1, Qt.alpha(ink, 0.08));
        ctx.fillStyle = fill;
        ctx.fill();
        ctx.strokeStyle = Qt.alpha(ink, 0.65);
        ctx.lineWidth = 0.7;
        ctx.lineJoin = "round";
        ctx.stroke();
        // Hairline spine stays quiet; silence clears the entire waveform.
        let spine = ctx.createLinearGradient(pad, 0, width - pad, 0);
        spine.addColorStop(0, Qt.alpha(ink, 0));
        spine.addColorStop(0.5, Qt.alpha(ink, 0.28));
        spine.addColorStop(1, Qt.alpha(ink, 0));
        ctx.beginPath();
        ctx.moveTo(pad, cy);
        ctx.lineTo(width - pad, cy);
        ctx.strokeStyle = spine;
        ctx.lineWidth = 0.65;
        ctx.stroke();
    }
}
