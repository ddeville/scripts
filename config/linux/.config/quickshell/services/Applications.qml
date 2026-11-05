pragma Singleton
import QtQuick
import Quickshell

QtObject {
    function launch(context) {
        const options = Array.isArray(context) ? {command: context} : Object.assign({}, context);
        // Apps survive a shell restart, but still stop when the graphical session ends.
        options.command = ["systemd-run", "--user", "--scope", "--collect", "--quiet",
            "--slice=app.slice", "--property=PartOf=graphical-session.target", "--"].concat(options.command);
        Quickshell.execDetached(options);
    }
}
