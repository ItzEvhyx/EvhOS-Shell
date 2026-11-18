import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as Guide
import "../../"
import "../../desktop"

Guide.GuideTab {
    id: tab
    property var searchItems: [{id:"app-icon-packs", tab:"icons", title:"Icons", description:"Choose application icon packs", keywords:"icon pack theme satin facet mono soft pixel arcade ascii type density sticker pals pastel die-cut apps"}]
    function s(value) { return rootObj.s(value); }
    component Copy: Text {
        font.family: "sans-serif"
        font.pixelSize: tab.s(13)
        color: ThemeBackend.subtext0
        wrapMode: Text.Wrap
    }
    Flickable {
        objectName:"iconPacksScroll"
        anchors.fill: parent
        anchors.margins: tab.s(24)
        anchors.topMargin: tab.s(12)
        contentWidth: width
        contentHeight: body.implicitHeight + tab.s(20)
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Guide.MouseWheelScroll {}
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout {
            id: body
            width: parent.width
            spacing: tab.s(18)
            Copy { text:"Make every app feel at home"; color:ThemeBackend.text; font.pixelSize:tab.s(23); font.bold:true; Layout.fillWidth:true }
            Copy { text:"Choose a pack for this desktop. Your active preset remembers the selection automatically."; Layout.fillWidth:true }
            Rectangle {
                Layout.fillWidth:true
                implicitHeight: currentRow.implicitHeight + tab.s(28)
                radius:tab.s(15)
                color:Qt.alpha(ThemeBackend.text,0.045)
                border.width:1
                border.color:Qt.alpha(ThemeBackend.text,0.12)
                RowLayout {
                    id: currentRow
                    anchors { left:parent.left; right:parent.right; top:parent.top; margins:tab.s(14) }
                    spacing:tab.s(12)
                    Image { source:IconPacks.sourceForDesign("ski",IconPacks.selected,64); Layout.preferredWidth:tab.s(46); Layout.preferredHeight:tab.s(46); fillMode:Image.PreserveAspectFit; smooth:!IconPacks.pixelated; mipmap:!IconPacks.pixelated }
                    ColumnLayout {
                        Layout.fillWidth:true
                        spacing:tab.s(3)
                        Copy { text:"CURRENT ICON PACK"; font.pixelSize:tab.s(10); font.letterSpacing:tab.s(1); font.bold:true; Layout.fillWidth:true }
                        Copy { text:IconPacks.nameFor(IconPacks.selected); color:ThemeBackend.text; font.pixelSize:tab.s(18); font.bold:true; Layout.fillWidth:true }
                    }
                    Copy { text:IconPacks.syncing ? "Applying…" : "Selected"; color:ThemeBackend.text; font.bold:true }
                }
            }
            GridLayout {
                id: packGrid
                Layout.fillWidth:true
                columns:width >= tab.s(820) ? 3 : width >= tab.s(520) ? 2 : 1
                columnSpacing:tab.s(14)
                rowSpacing:tab.s(14)
                Repeater {
                    model:IconPacks.packs
                    delegate:Rectangle {
                        id: pack
                        required property var modelData
                        readonly property bool selected:IconPacks.selected === modelData.id
                        objectName:"iconPack_"+modelData.id
                        Layout.fillWidth:true
                        Layout.minimumWidth:0
                        implicitHeight:packBody.implicitHeight + tab.s(32)
                        radius:tab.s(17)
                        color:Qt.alpha(ThemeBackend.mantle,hover.hovered ? 0.98 : 0.87)
                        border.width:selected ? 2 : 1
                        border.color:Qt.alpha(selected ? ThemeBackend.mauve : ThemeBackend.text, selected ? 0.75 : hover.hovered ? 0.3 : 0.12)
                        Behavior on color { ColorAnimation { duration:160 } }
                        Behavior on border.color { ColorAnimation { duration:180 } }
                        HoverHandler { id:hover }
                        transform:Translate { y:hover.hovered ? -tab.s(2) : 0; Behavior on y { NumberAnimation { duration:160; easing.type:Easing.OutCubic } } }
                        ColumnLayout {
                            id:packBody
                            anchors { left:parent.left; right:parent.right; top:parent.top; margins:tab.s(16) }
                            spacing:tab.s(12)
                            RowLayout {
                                Layout.fillWidth:true
                                Copy { text:pack.modelData.name; color:ThemeBackend.text; font.pixelSize:tab.s(18); font.bold:true; Layout.fillWidth:true }
                                Copy { text:pack.modelData.default ? "DEFAULT" : pack.selected ? "ACTIVE" : ""; font.pixelSize:tab.s(9); font.bold:true; font.letterSpacing:tab.s(0.8) }
                            }
                            Rectangle {
                                Layout.fillWidth:true
                                implicitHeight:previewGrid.implicitHeight + tab.s(24)
                                radius:tab.s(12)
                                color:Qt.alpha(ThemeBackend.text,0.025)
                                Grid {
                                    id:previewGrid
                                    x:tab.s(12); y:tab.s(12)
                                    width:parent.width-tab.s(24)
                                    columns:4
                                    spacing:tab.s(8)
                                    Repeater {
                                        model:["ski","cursor","brave","chatgpt","kitty","postman","resources","slack","teams","obs","mpv","settings"]
                                        delegate:Image {
                                            required property string modelData
                                            width:(previewGrid.width-previewGrid.spacing*3)/4
                                            height:width
                                            source:IconPacks.sourceForDesign(modelData,pack.modelData.id,64)
                                            sourceSize:Qt.size(128,128)
                                            fillMode:Image.PreserveAspectFit
                                            smooth:!IconPacks.isPixelated(pack.modelData.id); mipmap:!IconPacks.isPixelated(pack.modelData.id); asynchronous:true
                                        }
                                    }
                                }
                            }
                            Copy { text:pack.modelData.description; Layout.fillWidth:true; Layout.preferredHeight:tab.s(52); font.pixelSize:tab.s(12) }
                            Copy { text:String((IconPacks.catalog.designs || []).length)+" app designs"; font.pixelSize:tab.s(11) }
                            PresetAction {
                                objectName:"select_"+pack.modelData.id
                                Layout.fillWidth:true
                                text:pack.selected ? "✓ Selected" : "Use "+pack.modelData.name
                                primary:!pack.selected
                                enabled:!pack.selected && !Config.desktopPresetApplying
                                onClicked:IconPacks.select(pack.modelData.id)
                            }
                        }
                    }
                }
            }
            Copy { Layout.fillWidth:true; text:"Applies to the dock, launcher, overview and recognized tray apps. Mono Soft and Type Density adapt to light and dark themes. Pixel Arcade keeps its crisp pixel edges. Some running apps refresh their own icons when reopened."; font.pixelSize:tab.s(11) }
            Copy { Layout.fillWidth:true; visible:IconPacks.syncError !== ""; text:IconPacks.syncError; color:ThemeBackend.red }
            PresetAction { visible:IconPacks.syncError !== ""; text:"Retry application icons"; onClicked:IconPacks.scheduleSync() }
        }
    }
}
