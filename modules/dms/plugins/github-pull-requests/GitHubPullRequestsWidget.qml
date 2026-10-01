import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    property var pullRequests: []
    property var knownRepositories: []
    property string selectedAuthor: "@me"
    property string selectedStatus: "all"
    property string selectedRepository: "all"
    property string errorText: ""
    property string pendingApprovalUrl: ""
    property bool pendingRefresh: false
    property var activeRequest: null
    property bool stateReady: false
    property bool configOpen: false

    readonly property string helperCommand: String(pluginSetting("executablePath", "dms-github-prs"))
    readonly property string approvalToken: String(pluginSetting("approvalToken", ""))
    readonly property string defaultRepository: normalizeRepository(
        pluginSetting("defaultRepository", ""))
    readonly property int resultLimit: normalizeNumber(pluginSetting("resultLimit", 50), [25, 50, 100], 50)
    readonly property int refreshIntervalMinutes: normalizeNumber(
        pluginSetting("refreshIntervalMinutes", 5), [1, 5, 15, 30], 5)
    readonly property var statusOptions: [
        { label: "All", value: "all" },
        { label: "Open", value: "open" },
        { label: "Draft", value: "draft" },
        { label: "Merged", value: "merged" },
        { label: "Closed", value: "closed" }
    ]
    readonly property var authorOptions: buildAuthorOptions()
    readonly property var repositoryOptions: buildRepositoryOptions()
    readonly property var displayRows: buildDisplayRows()
    readonly property bool isBusy: listProcess.running
    readonly property int activeCount: pullRequests.filter(function(pr) {
        return pr.status === "open" || pr.status === "draft"
    }).length
    readonly property int barCount: selectedStatus === "all" ? activeCount : pullRequests.length

    layerNamespacePlugin: "github-pull-requests"

    function pluginSetting(key, defaultValue) {
        var value = pluginData ? pluginData[key] : undefined
        return value === undefined ? defaultValue : value
    }

    function normalizeNumber(value, allowed, fallback) {
        var number = Number(value)
        return allowed.indexOf(number) >= 0 ? number : fallback
    }

    function normalizeRepository(value) {
        var repository = String(value || "").trim()
        return repository.length > 0 && repository.toLowerCase() !== "all" ? repository : "all"
    }

    function buildAuthorOptions() {
        var options = [{ label: "My PRs", value: "@me" }]
        var seen = Object.create(null)
        seen["@me"] = true
        String(pluginSetting("additionalAuthors", "")).split(",").forEach(function(raw) {
            var username = raw.trim().replace(/^@/, "").toLowerCase()
            if (!username || seen[username])
                return
            seen[username] = true
            options.push({ label: "@" + username, value: username })
        })
        return options
    }

    function buildRepositoryOptions() {
        var repositories = []
        var seen = Object.create(null)

        function addRepository(repository) {
            var value = String(repository || "").trim()
            var key = value.toLowerCase()
            if (!value || value === "all" || seen[key])
                return
            seen[key] = true
            repositories.push(value)
        }

        knownRepositories.forEach(addRepository)
        addRepository(defaultRepository)
        addRepository(selectedRepository)
        repositories.sort()

        return [{ label: "All repositories", value: "all" }].concat(
            repositories.map(function(repository) {
                return { label: repository, value: repository }
            }))
    }

    function optionLabel(options, value, fallback) {
        for (var i = 0; i < options.length; i++) {
            if (options[i].value === value)
                return options[i].label
        }
        return fallback
    }

    function optionValue(options, label, fallback) {
        for (var i = 0; i < options.length; i++) {
            if (options[i].label === label)
                return options[i].value
        }
        return fallback
    }

    function buildDisplayRows() {
        var rows = []
        var active = pullRequests.filter(function(pr) {
            return pr.status === "open" || pr.status === "draft"
        })
        var finished = pullRequests.filter(function(pr) {
            return pr.status === "merged" || pr.status === "closed"
        })

        if (active.length > 0) {
            rows.push({ rowType: "header", title: "Open & draft", count: active.length })
            active.forEach(function(pr) { rows.push({ rowType: "pullRequest", data: pr }) })
        }
        if (finished.length > 0) {
            rows.push({ rowType: "header", title: "Merged & closed", count: finished.length })
            finished.forEach(function(pr) { rows.push({ rowType: "pullRequest", data: pr }) })
        }
        return rows
    }

    function statusLabel(status) {
        switch (status) {
        case "draft": return "Draft"
        case "merged": return "Merged"
        case "closed": return "Closed"
        default: return "Open"
        }
    }

    function statusColor(status) {
        switch (status) {
        case "draft": return Theme.surfaceVariantText
        case "merged": return Theme.primary
        case "closed": return Theme.error
        default: return Theme.success
        }
    }

    function ciIcon(status) {
        switch (status) {
        case "SUCCESS": return "check_circle"
        case "FAILURE":
        case "ERROR": return "cancel"
        case "PENDING":
        case "EXPECTED": return "pending"
        default: return "radio_button_unchecked"
        }
    }

    function ciColor(status) {
        switch (status) {
        case "SUCCESS": return Theme.success
        case "FAILURE":
        case "ERROR": return Theme.error
        case "PENDING":
        case "EXPECTED": return Theme.warning
        default: return Theme.surfaceVariantText
        }
    }

    function refresh() {
        if (listProcess.running) {
            pendingRefresh = true
            return
        }
        pendingRefresh = false
        errorText = ""
        activeRequest = {
            helper: helperCommand,
            author: selectedAuthor,
            status: selectedStatus,
            repository: selectedRepository,
            limit: resultLimit
        }
        listProcess.command = [activeRequest.helper, "list", "--author", activeRequest.author,
            "--status", activeRequest.status, "--repository", activeRequest.repository,
            "--limit", String(activeRequest.limit)]
        listProcess.running = true
    }

    function isCurrentListRequest() {
        return activeRequest !== null && activeRequest.helper === helperCommand &&
            activeRequest.author === selectedAuthor && activeRequest.status === selectedStatus &&
            activeRequest.repository === selectedRepository && activeRequest.limit === resultLimit
    }

    function approve(pr) {
        if (!pr || approveProcess.running)
            return
        var usesCustomToken = selectedAuthor === "@me"
        if (usesCustomToken && approvalToken.trim().length === 0) {
            ToastService.showError("Approval token required", "Add the alternate reviewer token in Settings.")
            return
        }
        pendingApprovalUrl = pr.url
        approveProcess.command = usesCustomToken
            ? [helperCommand, "approve", pr.url, "--custom-token"]
            : [helperCommand, "approve", pr.url]
        approveProcess.environment = usesCustomToken
            ? ({ "DMS_GITHUB_APPROVAL_TOKEN": approvalToken.trim() })
            : ({})
        approveProcess.running = true
    }

    function restoreState() {
        if (pluginService && pluginId) {
            selectedAuthor = pluginService.loadPluginState(pluginId, "selectedAuthor", "@me")
            selectedStatus = pluginService.loadPluginState(pluginId, "selectedStatus", "all")
        }
        if (!authorOptions.some(function(option) { return option.value === selectedAuthor }))
            selectedAuthor = "@me"
        if (!statusOptions.some(function(option) { return option.value === selectedStatus }))
            selectedStatus = "all"
        selectedRepository = defaultRepository
        stateReady = true
        refresh()
    }

    Component.onCompleted: Qt.callLater(root.restoreState)

    onSelectedAuthorChanged: {
        if (!stateReady)
            return
        pullRequests = []
        knownRepositories = []
        pluginService?.savePluginState(pluginId, "selectedAuthor", selectedAuthor)
        refresh()
    }

    onSelectedStatusChanged: {
        if (!stateReady)
            return
        pullRequests = []
        pluginService?.savePluginState(pluginId, "selectedStatus", selectedStatus)
        refresh()
    }

    onDefaultRepositoryChanged: {
        if (stateReady)
            selectedRepository = defaultRepository
    }

    onSelectedRepositoryChanged: {
        if (!stateReady)
            return
        pullRequests = []
        refresh()
    }

    onResultLimitChanged: {
        if (stateReady)
            refresh()
    }

    onHelperCommandChanged: {
        if (stateReady)
            refresh()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "merge"
                size: root.iconSize
                color: Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.isBusy ? "…" : String(root.barCount)
                color: Theme.widgetTextColor
                font.pixelSize: Theme.barTextSize(
                    root.barThickness,
                    root.barConfig?.fontScale,
                    root.barConfig?.maximizeWidgetText
                )
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS

            DankIcon {
                name: "merge"
                size: root.iconSize
                color: Theme.widgetIconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.isBusy ? "…" : String(root.barCount)
                color: Theme.widgetTextColor
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: 620
    popoutHeight: root.parentScreen && root.parentScreen.height > 0
        ? Math.min(760, Math.max(560, root.parentScreen.height * 0.74))
        : 680

    popoutContent: Component {
        PopoutComponent {
            id: popout

            width: parent.width
            headerText: root.configOpen ? "GitHub PR Settings" : "GitHub Pull Requests"
            detailsText: root.configOpen ? "Configure authors and the alternate approval account" : "Recent pull requests across GitHub"
            showCloseButton: true

            headerActions: Component {
                DankActionButton {
                    buttonSize: 32
                    iconName: root.configOpen ? "arrow_back" : "settings"
                    iconSize: 18
                    iconColor: Theme.surfaceText
                    tooltipText: root.configOpen ? "Back to pull requests" : "Settings"
                    onClicked: root.configOpen = !root.configOpen
                }
            }

            Item {
                width: parent.width
                implicitHeight: Math.max(0, root.popoutHeight - popout.headerHeight -
                    popout.detailsHeight - Theme.spacingXL)
                height: implicitHeight

                Column {
                    id: pullRequestView

                    anchors.fill: parent
                    visible: !root.configOpen
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankDropdown {
                            width: (parent.width - parent.spacing * 2) / 3
                            compactMode: true
                            text: "Author"
                            currentValue: root.optionLabel(root.authorOptions, root.selectedAuthor, "My PRs")
                            options: root.authorOptions.map(function(option) { return option.label })
                            onValueChanged: function(label) {
                                root.selectedAuthor = root.optionValue(root.authorOptions, label, "@me")
                            }
                        }

                        DankDropdown {
                            width: (parent.width - parent.spacing * 2) / 3
                            compactMode: true
                            text: "Status"
                            currentValue: root.optionLabel(root.statusOptions, root.selectedStatus, "All")
                            options: root.statusOptions.map(function(option) { return option.label })
                            onValueChanged: function(label) {
                                root.selectedStatus = root.optionValue(root.statusOptions, label, "all")
                            }
                        }

                        DankDropdown {
                            width: (parent.width - parent.spacing * 2) / 3
                            compactMode: true
                            text: "Repository"
                            currentValue: root.optionLabel(
                                root.repositoryOptions, root.selectedRepository, "All repositories")
                            options: root.repositoryOptions.map(function(option) { return option.label })
                            onValueChanged: function(label) {
                                root.selectedRepository = root.optionValue(
                                    root.repositoryOptions, label, "all")
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        visible: root.errorText.length > 0
                        height: visible ? errorRow.implicitHeight + Theme.spacingM * 2 : 0
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.error, 0.12)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.error, 0.45)

                        Row {
                            id: errorRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "warning"
                                size: Theme.iconSizeSmall
                                color: Theme.error
                            }

                            StyledText {
                                width: Math.max(0, parent.width - Theme.iconSizeSmall - parent.spacing)
                                text: root.errorText
                                color: Theme.error
                                font.pixelSize: Theme.fontSizeSmall + 1
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    DankFlickable {
                        id: listViewport

                        width: parent.width
                        height: Math.max(0, parent.height - y - footer.height - Theme.spacingS)
                        clip: true
                        contentWidth: width
                        contentHeight: listColumn.height

                        Column {
                            id: listColumn
                            width: listViewport.width
                            spacing: Theme.spacingXS

                            Item {
                                width: parent.width
                                height: root.displayRows.length === 0 ? 120 : 0
                                visible: root.displayRows.length === 0

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: root.isBusy ? "sync" : root.errorText.length > 0 ? "warning" : "check_circle"
                                        size: Theme.iconSizeLarge
                                        color: Theme.surfaceVariantText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: root.isBusy ? "Loading pull requests…" : root.errorText.length > 0
                                            ? "Could not load pull requests" : "No pull requests match this filter"
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeMedium
                                    }
                                }
                            }

                            Repeater {
                                model: root.displayRows

                                delegate: Loader {
                                    required property var modelData
                                    width: listColumn.width
                                    sourceComponent: modelData.rowType === "header" ? sectionHeader : pullRequestRow

                                    Component {
                                        id: sectionHeader

                                        Item {
                                            width: listColumn.width
                                            height: 30

                                            StyledText {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.title
                                                color: Theme.surfaceText
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.DemiBold
                                            }

                                            StyledText {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: String(modelData.count)
                                                color: Theme.surfaceVariantText
                                                font.pixelSize: Theme.fontSizeSmall
                                            }
                                        }
                                    }

                                    Component {
                                        id: pullRequestRow

                                        Rectangle {
                                            id: prCard
                                            property var pullRequest: modelData.data

                                            width: listColumn.width
                                            height: 52
                                            radius: Theme.cornerRadius
                                            color: rowMouse.containsMouse
                                                ? Theme.surfaceContainerHighest
                                                : Theme.surfaceContainerHigh

                                            MouseArea {
                                                id: rowMouse
                                                anchors.fill: parent
                                                z: 0
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Qt.openUrlExternally(parent.pullRequest.url)
                                            }

                                            Row {
                                                anchors.fill: parent
                                                z: 1
                                                anchors.leftMargin: Theme.spacingS
                                                anchors.rightMargin: Theme.spacingS
                                                anchors.topMargin: Theme.spacingXS
                                                anchors.bottomMargin: Theme.spacingXS
                                                spacing: Theme.spacingS

                                                Column {
                                                    width: Math.max(0, parent.width - approveButton.width - parent.spacing)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: Theme.spacingXXS

                                                    Row {
                                                        width: parent.width
                                                        spacing: Theme.spacingS

                                                        StyledText {
                                                            text: prCard.pullRequest.repository + " #" +
                                                                prCard.pullRequest.number
                                                            width: Math.max(0, parent.width - stateText.width -
                                                                ciState.width - parent.spacing * 2)
                                                            color: Theme.surfaceVariantText
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            isMonospace: true
                                                            elide: Text.ElideRight
                                                        }

                                                        DankIcon {
                                                            id: ciState
                                                            name: root.ciIcon(prCard.pullRequest.ciStatus)
                                                            size: 14
                                                            color: root.ciColor(prCard.pullRequest.ciStatus)
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        StyledText {
                                                            id: stateText
                                                            text: root.statusLabel(prCard.pullRequest.status)
                                                            color: root.statusColor(prCard.pullRequest.status)
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            font.weight: Font.DemiBold
                                                        }
                                                    }

                                                    StyledText {
                                                        width: parent.width
                                                        text: prCard.pullRequest.title
                                                        color: Theme.surfaceText
                                                        font.pixelSize: Theme.fontSizeMedium
                                                        font.weight: Font.Medium
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                DankActionButton {
                                                    id: approveButton
                                                    buttonSize: 28
                                                    iconName: root.pendingApprovalUrl === prCard.pullRequest.url &&
                                                        approveProcess.running ? "sync" : "check"
                                                    iconSize: 16
                                                    iconColor: Theme.primaryText
                                                    backgroundColor: Theme.primary
                                                    tooltipText: "Approve pull request"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    z: 2
                                                    enabled: !approveProcess.running
                                                    onClicked: root.approve(prCard.pullRequest)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: footer
                        width: parent.width
                        height: 44

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.selectedAuthor === "@me" && root.approvalToken.trim().length === 0
                                ? "Add the approval token in Settings to approve your PRs"
                                : root.pullRequests.length + " pull requests"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            width: Math.max(0, parent.width - refreshButton.width - Theme.spacingS)
                        }

                        DankButton {
                            id: refreshButton
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.isBusy ? "Refreshing…" : "Refresh"
                            iconName: "refresh"
                            buttonHeight: 34
                            horizontalPadding: Theme.spacingS
                            enabled: !root.isBusy
                            onClicked: root.refresh()
                        }
                    }
                }

                DankFlickable {
                    id: settingsViewport
                    anchors.fill: parent
                    visible: root.configOpen
                    clip: true
                    contentWidth: width
                    contentHeight: settingsLoader.height + Theme.spacingM * 2

                    Loader {
                        id: settingsLoader
                        x: Theme.spacingM
                        y: Theme.spacingM
                        width: settingsViewport.width - Theme.spacingM * 2
                        height: item ? item.implicitHeight : 0
                        source: Qt.resolvedUrl("GitHubPullRequestsSettings.qml")

                        onLoaded: {
                            if (item) {
                                item.width = settingsLoader.width
                                item.pluginService = root.pluginService
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: listProcess

        stdout: StdioCollector {
            id: listOutput
        }

        stderr: StdioCollector {
            id: listError
        }

        onExited: function(exitCode, exitStatus) {
            if (root.isCurrentListRequest()) {
                if (exitCode !== 0) {
                    root.errorText = listError.text.trim() || "GitHub CLI failed (exit " + exitCode + ")"
                } else {
                    try {
                        var parsed = JSON.parse(listOutput.text)
                        if (!Array.isArray(parsed))
                            throw new Error("Expected a pull request list")
                        root.pullRequests = parsed
                        var repositories = root.knownRepositories.slice()
                        parsed.forEach(function(pr) {
                            if (repositories.indexOf(pr.repository) < 0)
                                repositories.push(pr.repository)
                        })
                        root.knownRepositories = repositories
                        root.errorText = ""
                    } catch (error) {
                        root.errorText = "Could not read GitHub CLI output: " + String(error)
                    }
                }
            }
            if (root.pendingRefresh || !root.isCurrentListRequest()) {
                root.pendingRefresh = false
                Qt.callLater(root.refresh)
            }
        }
    }

    Process {
        id: approveProcess

        stderr: StdioCollector {
            id: approveError
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                ToastService.showInfo("Pull request approved")
                root.refresh()
            } else {
                var message = approveError.text.trim() || "GitHub CLI failed (exit " + exitCode + ")"
                ToastService.showError("Could not approve pull request", message)
            }
            root.pendingApprovalUrl = ""
            approveProcess.environment = ({})
        }
    }

    Timer {
        interval: root.refreshIntervalMinutes * 60000
        repeat: true
        running: root.stateReady
        onTriggered: root.refresh()
    }

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId !== root.pluginId)
                return
            if (!root.authorOptions.some(function(option) { return option.value === root.selectedAuthor }))
                root.selectedAuthor = "@me"
        }
    }
}
