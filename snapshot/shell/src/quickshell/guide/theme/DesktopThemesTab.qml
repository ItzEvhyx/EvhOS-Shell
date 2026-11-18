import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as GuideScroll
import "../../"

GuideScroll.GuideTab {
    id: themesTab
    property var searchItems: [
        {
            id: "desktop-themes",
            tab: "preset_themes",
            title: "Presets Themes",
            description: "Create and switch saved desktops",
            keywords: "wallpaper pinned apps bar dock widgets autosave recovery history"
        }
    ]
    function activateSearchItem(id) {
        page.contentY = 0;
        return true;
    }

    Flickable {
        id: page
        anchors.fill: parent
        anchors.margins: rootObj.s(24)
        anchors.topMargin: rootObj.s(12)
        contentWidth: width
        contentHeight: section.implicitHeight + rootObj.s(12)
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        GuideScroll.MouseWheelScroll {}
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
        DesktopPresetsSection {
            id: section
            objectName: "desktopPresetGallery"
            tab: themesTab
            width: page.width
        }
    }
}
