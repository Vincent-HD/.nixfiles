import QtQuick
import qs.Modules.Plugins

PluginSettings {
    pluginId: "serviceHub"

    ToggleSetting {
        settingKey: "showBarLabel"
        label: "Show bar label"
        description: "Display Services beside the hub icon in the horizontal bar."
        defaultValue: false
    }
}
