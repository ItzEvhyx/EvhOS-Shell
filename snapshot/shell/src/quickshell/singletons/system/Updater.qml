pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    property bool isChecking: false
    property string localVersion: "2.0.0"
    property string remoteVersion: ""
    property bool updateAvailable: false
    property string lastNotifiedVersion: ""

    property string stateVersion: ""
    property string packageVersion: ""

    // Keep the locally installed version for the About and Welcome pages.
    function syncLocalVersion() {
        if (root.stateVersion !== "") root.localVersion = root.stateVersion;
        else if (root.packageVersion !== "") root.localVersion = root.packageVersion;
    }

    FileView {
        id: pkgVersionFileView
        path: (typeof Caching !== "undefined" && Caching.serpantinumDir ? Caching.serpantinumDir : "") + "/version.txt"
        onFileChanged: {
            pkgVersionFileView.reload();
        }
        onLoaded: {
            let content = this.text();
            if (!content) return;
            let v = content.trim();
            if (v) {
                root.packageVersion = v;
                root.syncLocalVersion();
            }
        }
    }

    FileView {
        id: versionFileView
        path: (typeof Caching !== "undefined" ? Caching.getStateDir() : "") + "/version"
        onFileChanged: {
            versionFileView.reload();
        }
        onLoaded: {
            let content = this.text();
            if (!content) return;
            let lines = content.split("\n");
            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim();
                if (line.indexOf("SERPANTINUM_VERSION=") === 0) {
                    let v = line.substring("SERPANTINUM_VERSION=".length).replace(/["']/g, "").trim();
                    if (v) {
                        root.stateVersion = v;
                        root.syncLocalVersion();
                    }
                    break;
                }
            }
        }
    }

}
