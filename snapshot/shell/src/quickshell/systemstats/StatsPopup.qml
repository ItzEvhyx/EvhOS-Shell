import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../reusables"
import "../WindowRegistry.js" as Registry
import "../desktop/PanelPlacement.js" as PanelPlacement

PanelWindow {
    id: popup
    required property var hostWindow
    required property Item anchorItem
    screen: hostWindow.screen
    property bool opened: false
    property var stats: ({})
    property var histories: ({})
    property bool streamFailed: false
    readonly property string collector: Caching.qsDir + "/systemstats/stats.py"
    readonly property rect barRect: {
        // Explicit geometry dependencies also track content-width and scale changes.
        let gx=anchorItem.x,gy=anchorItem.y,gw=anchorItem.width,gh=anchorItem.height;
        let p=anchorItem.mapToItem(null,0,0);
        let bottom=hostWindow.barPosition==="bottom";
        let offsetY=bottom?(screen.height-hostWindow.height-hostWindow.margins.bottom):hostWindow.margins.top;
        return Qt.rect(p.x+hostWindow.margins.left,p.y+offsetY,gw,gh);
    }
    // Share the calendar popup's dimensions and screen-edge placement.
    readonly property real uiScale: {
        let general = Config.getSetting("general", {});
        let value = Number(general.uiScale !== undefined ? general.uiScale : Config.getSetting("uiScale", 1));
        return Number.isFinite(value) && value > 0 ? value : 1;
    }
    readonly property var panelLayout: {
        let position = hostWindow.barPosition;
        let bar = BarGeometry.bars[screen.name];
        if (!bar || bar.position !== position)
            bar = {position: position, x: barRect.x, y: barRect.y, width: barRect.width, height: barRect.height};
        let layout = Registry.getLayout("calendar", 0, 0, screen.width, screen.height, uiScale, position);
        return PanelPlacement.place(layout, bar, screen.width, screen.height, uiScale);
    }
    color:"transparent"
    visible: opened || reveal > 0.001
    exclusionMode: ExclusionMode.Ignore
    anchors { top:true;bottom:true;left:true;right:true }
    WlrLayershell.namespace:"evhos-process-desk"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:opened?WlrKeyboardFocus.OnDemand:WlrKeyboardFocus.None
    focusable:opened
    mask:Region { item:panel }
    property real reveal:opened?1:0
    Behavior on reveal { NumberAnimation { duration:160;easing.type:Easing.OutCubic } }
    function close() { opened=false; }
    function toggle() {
        if(opened) { close();return; }
        // Request existing shell panels to dismiss before taking focus.
        PanelActions.requested("close","","");
        histories=({});stats=({});streamFailed=false;
        opened=true;
        Qt.callLater(function(){if(popup.opened)panel.forceActiveFocus();});
    }
    onOpenedChanged: hostWindow.statsPanelOpen=opened
    Component.onDestruction: if(hostWindow)hostWindow.statsPanelOpen=false
    Connections {
        target:hostWindow
        function onBarPositionChanged(){popup.close();}
        function onShouldHideForRedactChanged(){if(popup.hostWindow.shouldHideForRedact)popup.close();}
        function onVisibleChanged(){if(!popup.hostWindow.visible)popup.close();}
    }
    Connections {
        target:PanelActions
        function onRequested(action,name,arg) { if(popup.opened && (action==="open" || action==="toggle"))popup.close(); }
    }
    Connections {
        target:Hyprland
        function onRawEvent(event) {
            if(["workspacev2","activespecialv2","focusedmonv2"].includes(event.name))popup.close();
        }
    }
    HyprlandFocusGrab {
        id:grab
        windows:[popup,popup.hostWindow]
        active:popup.opened
        onCleared:popup.close()
    }
    Process {
        id:stream
        running:popup.opened
        command:["python3",popup.collector,"--interval","2"]
        stdout:SplitParser {
            onRead:line=> {
                if(!popup.opened)return;
                try {
                    let data=JSON.parse(line),next=Object.assign({},popup.histories);
                    for(let key of ["cpu_percent","ram_percent","gpu_percent","cpu_temp","disk_percent"])
                        next[key]=(next[key]||[]).concat([data[key]===undefined?null:data[key]]).slice(-60);
                    popup.stats=data;popup.histories=next;
                } catch(e) { console.warn("Process Desk sample: "+e); }
            }
        }
        onExited:exitCode=>{if(popup.opened && exitCode!==0)popup.streamFailed=true;}
    }
    ProcessDesk {
        id:panel
        x:popup.panelLayout.rx
        y:popup.panelLayout.ry
        width:popup.panelLayout.w
        height:popup.panelLayout.h
        textFamily:ThemeBackend.fontFamily
        iconFamily:ThemeBackend.iconFont
        cornerRadius:ThemeBackend.borderRadius
        opacity:popup.reveal
        transform:Translate { y:(1-popup.reveal)*-Scaler.s(8) }
        enabled:popup.opened
        focus:true
        ink:ThemeBackend.text
        base:ThemeBackend.base
        stats:popup.stats
        histories:popup.histories
        Keys.onEscapePressed:event=>{popup.close();event.accepted=true;}
        onDismissRequested:popup.close()
        WallpaperBlur {
            z:-1
            anchors.fill:parent
            radius:parent.radius
            standalone:true
            screenOverride:popup.screen
            rim:0
        }
        Text {
            anchors.bottom:parent.bottom
            anchors.left:parent.left
            anchors.margins:panel.s(26)
            text:"Stats collector stopped — close and reopen to retry"
            visible:popup.streamFailed
            color:panel.ink
            font.family:panel.textFamily
            font.pixelSize:panel.s(14)
            font.weight:Font.Bold
        }
    }
}
