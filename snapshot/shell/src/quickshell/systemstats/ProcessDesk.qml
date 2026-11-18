import QtQuick
import QtQuick.Layouts

Rectangle {
    id: desk
    property var stats: ({})
    property var histories: ({})
    property string sortKey: "cpu"
    property bool descending: true
    property color ink: "white"
    property color base: "black"
    property string textFamily: "monospace"
    property string iconFamily: textFamily
    property real cornerRadius: s(10)
    property real unit: Math.max(0.65, Math.min(width / 1360, height / 510))
    readonly property real metricsHeight: s(184)
    readonly property real bodyHeight: Math.max(0, height - s(52) - metricsHeight - s(16))
    implicitWidth: 1360
    implicitHeight: 510
    radius: cornerRadius
    clip: true
    color: Qt.alpha(base,0.78)
    border.width: 1
    border.color: Qt.alpha(ink,0.11)
    signal dismissRequested()
    function s(v) { return v*unit; }
    function valid(v) { return v!==null && v!==undefined && Number.isFinite(Number(v)); }
    function percent(v) { return valid(v) ? Math.round(v)+"%" : "—"; }
    function temp(v) { return valid(v) ? Math.round(v)+"°C" : "—"; }
    function memory(bytes) {
        if (!valid(bytes)) return "—";
        return bytes>=1073741824 ? (bytes/1073741824).toFixed(1)+" GiB" : Math.round(bytes/1048576)+" MiB";
    }
    function capacity(used,total,decimal) {
        if (!valid(used) || !valid(total) || total<=0) return "—";
        let factor=decimal?1e9:1073741824;
        return (used/factor).toFixed(decimal?0:1)+" / "+(total/factor).toFixed(decimal?0:1)+(decimal?" GB":" GiB");
    }
    function rate(v) {
        if (!valid(v)) return "—";
        return v>=1e6 ? (v/1e6).toFixed(1)+" MB/s" : Math.round(v/1000)+" KB/s";
    }
    function uptime(v) {
        if (!valid(v)) return "—";
        let d=Math.floor(v/86400),h=Math.floor(v/3600)%24,m=Math.floor(v/60)%60;
        return (d?d+"d ":"")+h+"h "+m+"m";
    }
    readonly property var metrics: [
        {title:"CPU",icon:"󰍛",value:percent(stats.cpu_percent),detail:temp(stats.cpu_temp),secondary:"Whole system",key:"cpu_percent",max:100},
        {title:"RAM",icon:"󰘚",value:percent(stats.ram_percent),detail:"",secondary:capacity(stats.ram_used,stats.ram_total,false),key:"ram_percent",max:100},
        {title:"GPU",icon:"󰢮",value:percent(stats.gpu_percent),detail:temp(stats.gpu_temp),secondary:(stats.gpu_name||"GPU")+(valid(stats.gpu_frequency)?" · "+Math.round(stats.gpu_frequency)+" MHz":""),key:"gpu_percent",max:100},
        {title:"TEMP",icon:"󰔏",value:temp(stats.cpu_temp),detail:"",secondary:"CPU package",key:"cpu_temp",max:110},
        {title:"STORAGE",icon:"󰋊",value:percent(stats.disk_percent),detail:"",secondary:capacity(stats.disk_used,stats.disk_total,true),key:"disk_percent",max:100}
    ]
    readonly property var sortedProcesses: {
        let items=stats.processes||[];
        let key=sortKey, direction=descending?-1:1;
        return items.slice().sort((a,b)=> {
            if(key==="name")return direction*a.name.localeCompare(b.name);
            let av=key==="memory"?a.memory:a.cpu,bv=key==="memory"?b.memory:b.cpu;
            return direction*((av||0)-(bv||0)) || b.memory-a.memory;
        });
    }
    function sortBy(key) {
        if(sortKey===key)descending=!descending;
        else {sortKey=key;descending=key!=="name";}
    }
    onSortKeyChanged: processList.contentY=0

    component Label: Text {
        color: desk.ink
        font.family: desk.textFamily
        font.pixelSize: desk.s(16)
        font.weight: Font.Bold
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        renderType: Text.QtRendering
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: desk.s(26)
        spacing: desk.s(16)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: desk.metricsHeight
            spacing: desk.s(14)
            Repeater {
                model: desk.metrics
                delegate: Rectangle {
                    id: metric
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: desk.s(20)
                    color: Qt.alpha(desk.ink,0.055)
                    border.width: 1
                    border.color: Qt.alpha(desk.ink,0.11)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: desk.s(18)
                        spacing: desk.s(6)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: desk.s(6)
                            Label { text: metric.modelData.icon; font.family:desk.iconFamily;font.pixelSize:desk.s(20) }
                            Label { text:metric.modelData.title;Layout.fillWidth:true;font.pixelSize:desk.s(14) }
                            Label { text:metric.modelData.detail;opacity:0.8;font.pixelSize:desk.s(13) }
                        }
                        Label { text:metric.modelData.value; Layout.fillWidth:true; font.family:"sans-serif";font.pixelSize:desk.s(40);font.weight:Font.Bold }
                        Label { text:metric.modelData.secondary;Layout.fillWidth:true;opacity:0.8;font.pixelSize:desk.s(14) }
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: desk.s(42)
                            HistoryGraph { anchors.fill:parent;samples:desk.histories[metric.modelData.key]||[];maximum:metric.modelData.max;ink:desk.ink }
                            Label { anchors.centerIn:parent;visible:metric.modelData.value==="—";text:"Reading unavailable";font.pixelSize:desk.s(16);opacity:0.65 }
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: desk.bodyHeight
            spacing: desk.s(16)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: desk.s(20)
                color: Qt.alpha(desk.ink,0.055)
                border.width: 1
                border.color: Qt.alpha(desk.ink,0.11)
                ColumnLayout {
                    anchors.fill:parent
                    anchors.margins:desk.s(16)
                    spacing:desk.s(6)
                    Row {
                        Layout.fillWidth:true
                        Layout.preferredHeight:desk.s(26)
                        Repeater {
                            model:[{key:"name",label:"Process",fraction:0.52},{key:"cpu",label:"CPU",fraction:0.20},{key:"memory",label:"Memory",fraction:0.28}]
                            delegate:Label {
                                required property var modelData
                                width:parent.width*modelData.fraction
                                height:desk.s(26)
                                text:modelData.label+(desk.sortKey===modelData.key?(desk.descending?" ▾":" ▴"):"")
                                opacity:0.8
                                horizontalAlignment:modelData.key==="name"?Text.AlignLeft:Text.AlignRight
                                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:desk.sortBy(parent.modelData.key) }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth:true;Layout.preferredHeight:1;color:Qt.alpha(desk.ink,0.13) }
                    ListView {
                        id:processList
                        Layout.fillWidth:true
                        Layout.fillHeight:true
                        clip:true
                        model:desk.sortedProcesses
                        boundsBehavior:Flickable.StopAtBounds
                        delegate:Item {
                            required property var modelData
                            width:processList.width
                            height:desk.s(36)
                            Row {
                                anchors.fill:parent
                                Label { width:parent.width*0.52;height:parent.height;text:modelData.name+(modelData.count>1?" ×"+modelData.count:"");font.pixelSize:desk.s(16) }
                                Label { width:parent.width*0.20;height:parent.height;text:desk.valid(modelData.cpu)?modelData.cpu.toFixed(1)+"%":"—";horizontalAlignment:Text.AlignRight }
                                Label { width:parent.width*0.28;height:parent.height;text:desk.memory(modelData.memory);horizontalAlignment:Text.AlignRight }
                            }
                            Rectangle { anchors.bottom:parent.bottom;width:parent.width;height:1;color:Qt.alpha(desk.ink,0.07) }
                        }
                        Label { anchors.centerIn:parent;visible:processList.count===0;text:"Sampling processes…";opacity:0.7 }
                    }
                }
            }
            Rectangle {
                Layout.preferredWidth:parent.width*0.29
                Layout.fillHeight:true
                radius:desk.s(20)
                color:Qt.alpha(desk.ink,0.055)
                border.width:1
                border.color:Qt.alpha(desk.ink,0.11)
                ColumnLayout {
                    anchors.fill:parent
                    anchors.margins:desk.s(16)
                    spacing:0
                    ColumnLayout {
                        Layout.fillWidth:true
                        Layout.fillHeight:true
                        spacing:desk.s(3)
                        Label { text:"󰛳  NETWORK";font.pixelSize:desk.s(14) }
                        Label { Layout.fillWidth:true;text:"↓ "+desk.rate(desk.stats.net_rx)+"   ↑ "+desk.rate(desk.stats.net_tx);font.pixelSize:desk.s(14) }
                    }
                    Repeater {
                        model:[{name:"󰈐  FAN",value:desk.valid(desk.stats.fan_rpm)?Math.round(desk.stats.fan_rpm)+" RPM":"—"},
                               {name:"󰓡  SWAP",value:desk.capacity(desk.stats.swap_used,desk.stats.swap_total,false)},
                               {name:"󰥔  UPTIME",value:desk.uptime(desk.stats.uptime)}]
                        delegate:Item {
                            required property var modelData
                            Layout.fillWidth:true
                            Layout.fillHeight:true
                            Rectangle { width:parent.width;height:1;color:Qt.alpha(desk.ink,0.12) }
                            RowLayout {
                                anchors.fill:parent
                                Label { text:modelData.name;Layout.fillWidth:true;font.pixelSize:desk.s(14) }
                                Label { text:modelData.value;font.pixelSize:desk.s(14) }
                            }
                        }
                    }
                }
            }
        }
    }
}
