import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "githubPullRequests"

    property bool tokenVisible: false
    property bool tokenLoaded: false

    function loadToken() {
        if (!root.pluginService)
            return
        approvalTokenField.text = String(root.loadValue("approvalToken", ""))
        tokenLoaded = true
    }

    function migrateDefaultRepository() {
        if (!root.pluginService)
            return
        if (String(root.loadValue("defaultRepository", "all")).trim().length === 0)
            root.saveValue("defaultRepository", "all")
    }

    function initializeSettings() {
        root.loadToken()
        root.migrateDefaultRepository()
    }

    function saveToken() {
        if (!tokenLoaded)
            return
        root.saveValue("approvalToken", approvalTokenField.text.trim())
    }

    Component.onCompleted: Qt.callLater(root.initializeSettings)

    onPluginServiceChanged: Qt.callLater(root.initializeSettings)

    StyledText {
        width: parent.width
        text: "GitHub pull request settings"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
    }

    StyledText {
        width: parent.width
        text: "The regular GitHub CLI login loads pull requests and approves other users' PRs. The token below is used only when My PRs is selected."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall + 1
        wrapMode: Text.WordWrap
    }

    StyledText {
        text: "Approval token"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
    }

    StyledText {
        width: parent.width
        text: "Use a token for the alternate reviewer account. It needs pull-request write access. DMS stores plugin settings as plaintext on disk."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Row {
        width: parent.width
        spacing: Theme.spacingS

        DankTextField {
            id: approvalTokenField
            width: Math.max(0, parent.width - revealButton.width - parent.spacing)
            placeholderText: "github_pat_… or ghp_…"
            echoMode: root.tokenVisible ? TextInput.Normal : TextInput.Password
            onEditingFinished: root.saveToken()
            onActiveFocusChanged: {
                if (!activeFocus)
                    root.saveToken()
            }
        }

        DankActionButton {
            id: revealButton
            buttonSize: 40
            iconName: root.tokenVisible ? "visibility_off" : "visibility"
            iconSize: 20
            iconColor: Theme.surfaceText
            onClicked: root.tokenVisible = !root.tokenVisible
        }
    }

    StringSetting {
        settingKey: "additionalAuthors"
        label: "Other authors"
        description: "Comma-separated GitHub usernames shown in the author filter."
        placeholder: "octocat, monalisa"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "defaultRepository"
        label: "Default repository filter"
        description: "Repository selected when the widget starts. Use all to show every repository."
        placeholder: "owner/repository"
        defaultValue: "all"
    }

    SelectionSetting {
        settingKey: "refreshIntervalMinutes"
        label: "Refresh interval"
        description: "How often to reload the current selection."
        options: [
            { label: "1 minute", value: "1" },
            { label: "5 minutes", value: "5" },
            { label: "15 minutes", value: "15" },
            { label: "30 minutes", value: "30" }
        ]
        defaultValue: "5"
    }

    SelectionSetting {
        settingKey: "resultLimit"
        label: "Maximum pull requests"
        description: "Maximum number displayed after grouping and filtering."
        options: [
            { label: "25", value: "25" },
            { label: "50", value: "50" },
            { label: "100", value: "100" }
        ]
        defaultValue: "50"
    }
}
