import QtQuick

WheelHandler {
    id: wheelHandler
    target: null
    acceptedDevices: PointerDevice.Mouse

    onWheel: function(event) {
        if (!parent) return;
        const pixelDelta = event.pixelDelta.y;
        const angleDelta = event.angleDelta.y;
        if (pixelDelta === 0 && angleDelta === 0) return;

        const top = parent.originY;
        const bottom = top + Math.max(0, parent.contentHeight - parent.height);
        const distance = pixelDelta !== 0 ? pixelDelta * 2.2 : angleDelta * 1.5;
        const next = Math.max(top, Math.min(bottom, parent.contentY - distance));
        if (next !== parent.contentY) {
            parent.contentY = next;
            event.accepted = true;
        }
    }
}
