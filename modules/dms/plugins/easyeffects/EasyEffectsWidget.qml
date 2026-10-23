import QtQuick
import Quickshell
import Quickshell.Io
import qs.DCommon.Common as DCommon
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string executablePath: pluginData.executablePath || "easyeffects"
    property string activeProfile: ""
    readonly property string profileIcon: activeProfile === "Music Ducking" ? "hearing" : "hearing_disabled"

    property string pendingPreset: ""

    function changeProfile(reset) {
        root.pendingPreset = !reset && root.activeProfile !== "Music Ducking" ? "Music Ducking" : "Without Music Ducking";
        if (profileSocket.linkUp) {
            sendPendingPreset();
        } else {
            // Start independently so a shell restart cannot kill audio effects.
            Quickshell.execDetached([root.executablePath, "--service-mode"]);
        }
    }

    function sendPendingPreset() {
        if (root.pendingPreset) {
            profileSocket.send("load_preset:output:" + root.pendingPreset);
            root.pendingPreset = "";
        }
        profileSocket.send("get_last_loaded_preset:output");
    }

    // Use the same line protocol as EasyEffects' CLI, without launching a
    // status process that can become a persistent app when EasyEffects is down.
    DCommon.DSocket {
        id: profileSocket
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/EasyEffectsServer"
        connected: true
        reconnectMaxMs: 2000
        onConnectionStateChanged: {
            if (linkUp)
                root.sendPendingPreset();
            else
                root.activeProfile = "";
        }
        parser: SplitParser {
            onRead: data => root.activeProfile = data.trim()
        }
    }

    // Each screen observes external profile changes independently.
    Timer {
        interval: 2000
        repeat: true
        running: profileSocket.linkUp
        onTriggered: profileSocket.send("get_last_loaded_preset:output")
    }

    pillClickAction: () => root.changeProfile(false)
    pillRightClickAction: () => root.changeProfile(true)

    // The pill handles left/right clicks; keep middle-click reset on its content.
    component ProfileIcon: MouseArea {
        implicitWidth: icon.implicitWidth
        implicitHeight: icon.implicitHeight
        acceptedButtons: Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.changeProfile(true)

        DIcon {
            id: icon
            name: root.profileIcon
            size: root.iconSize
            color: Theme.widgetTextColor
        }
    }

    horizontalBarPill: Component {
        ProfileIcon {}
    }

    verticalBarPill: Component {
        ProfileIcon {}
    }
}
