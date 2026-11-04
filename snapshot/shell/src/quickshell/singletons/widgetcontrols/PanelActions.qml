pragma Singleton
import QtQuick
import Quickshell
import "../../"

QtObject {
    signal requested(string action, string name, string arg)
    function invoke(action, name, arg) {
        requested(action, name, arg || "");
        // Preserve launcher ranking without delaying the panel.
        let rank = Caching.qsDir + "/launcher/app_rank.py";
        Quickshell.execDetached(["python3", rank, "--log-launch", "--name", name]);
        let key = name === "settings" ? "guide" : name;
        let translated = I18n.t("widgets." + key + ".name");
        if (translated && translated !== name && translated.indexOf("widgets.") !== 0)
            Quickshell.execDetached(["python3", rank, "--log-launch", "--name", translated]);
    }
}
