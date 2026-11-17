import QtQuick
import QtMultimedia
import "../"

Item {
    id: wallpaperSource
    objectName: "workspace-wallpaper-source-" + monitorName
    property string monitorName: ""
    property bool playbackActive: false
    property string registrationName: ""
    readonly property var engine: Wallpaper.engines[monitorName] || null
    readonly property var desktopPlayer: engine && engine.overviewVideoPlayer ? engine.overviewVideoPlayer : null
    readonly property string mediaPath: Wallpaper.getWallpaperPath(monitorName) || ""
    readonly property bool video: /\.(mp4|mkv|mov|webm)(?:[?#].*)?$/i.test(mediaPath)
    readonly property string mediaUrl: mediaPath ? (mediaPath.startsWith("file:") ? mediaPath : "file://" + mediaPath) : ""
    readonly property bool desktopPaused: !!engine && !!engine.playbackPaused
    property bool hasVideoFrame: false
    readonly property bool playerRunning: movie.playbackState === MediaPlayer.PlayingState
    readonly property real previewPosition: movie.position
    readonly property string posterUrl: {
        if (!video || !engine) return "";
        let a = engine.activeLayer === 0;
        if ((a ? engine.pathA : engine.pathB) !== mediaPath || !(a ? engine.snapReadyA : engine.snapReadyB)) return "";
        return "file://" + (a ? engine.layerSnapshotPathA : engine.layerSnapshotPathB) + "?rev=" + (a ? engine.snapRevA : engine.snapRevB);
    }

    function synchronize(forceSeek) {
        if (!playbackActive || !video || !mediaUrl) {
            movie.stop();
            hasVideoFrame = false;
            return;
        }
        if (movie.mediaStatus !== MediaPlayer.LoadedMedia && movie.mediaStatus !== MediaPlayer.BufferedMedia) return;
        let position = desktopPlayer ? desktopPlayer.position : 0;
        if (desktopPlayer && (forceSeek || Math.abs(movie.position - position) > 500)) movie.setPosition(Math.max(0, position));
        if (desktopPaused) movie.pause();
        else movie.play();
    }
    onPlaybackActiveChanged: synchronize(true)
    onMediaPathChanged: { hasVideoFrame = false; synchronizeLater.restart(); }
    onDesktopPlayerChanged: synchronizeLater.restart()
    onDesktopPausedChanged: synchronize(false)
    Component.onDestruction: movie.stop()

    Timer { id: synchronizeLater; interval: 30; onTriggered: wallpaperSource.synchronize(true) }
    Timer {
        interval: 750
        running: wallpaperSource.playbackActive && wallpaperSource.video && !!wallpaperSource.desktopPlayer
        repeat: true
        onTriggered: wallpaperSource.synchronize(false)
    }
    Image {
        anchors.fill: parent
        source: wallpaperSource.video ? wallpaperSource.posterUrl : wallpaperSource.mediaUrl
        visible: !wallpaperSource.video || !wallpaperSource.hasVideoFrame
        sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
        asynchronous: true
        cache: false
        retainWhileLoading: false
        fillMode: Image.PreserveAspectCrop
    }
    MediaPlayer {
        id: movie
        objectName: "workspace-wallpaper-player-" + wallpaperSource.monitorName
        source: wallpaperSource.playbackActive && wallpaperSource.video ? wallpaperSource.mediaUrl : ""
        loops: MediaPlayer.Infinite
        audioOutput: null // Video preview only; never creates an audio output.
        videoOutput: videoOutput
        onMediaStatusChanged: wallpaperSource.synchronize(true)
        onErrorOccurred: (error, message) => {
            wallpaperSource.hasVideoFrame = false;
            console.warn("Workspace wallpaper preview:", message);
        }
    }
    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        visible: wallpaperSource.video && wallpaperSource.hasVideoFrame
        fillMode: VideoOutput.PreserveAspectCrop
    }
    Connections {
        target: videoOutput.videoSink
        function onVideoFrameChanged() {
            wallpaperSource.hasVideoFrame = wallpaperSource.playbackActive && wallpaperSource.video && movie.hasVideo;
        }
    }
}
