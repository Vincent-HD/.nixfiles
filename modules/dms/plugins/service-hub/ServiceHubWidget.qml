import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "service-hub"

    readonly property string catalogPath: Paths.strip(Qt.resolvedUrl("services.json").toString())
    readonly property string wallpaperSource: {
        const wallpaper = Theme.wallpaperPath;
        if (!wallpaper || wallpaper.startsWith("#"))
            return "";
        if (wallpaper.startsWith("file://"))
            return wallpaper;
        return "file://" + wallpaper.split("/").map(segment => encodeURIComponent(segment)).join("/");
    }

    function isImageIcon(icon) {
        if (typeof icon !== "string")
            return false;
        return icon.startsWith("http://") || icon.startsWith("https://") || icon.startsWith("file://") || icon.startsWith("qrc:/") || icon.startsWith("/") || icon.startsWith("./");
    }

    function imageIconSource(icon) {
        if (!root.isImageIcon(icon))
            return "";
        if (icon.startsWith("./"))
            return Qt.resolvedUrl(icon).toString();
        if (icon.startsWith("/"))
            return "file://" + icon;
        return icon;
    }

    function materialIconName(icon) {
        return root.isImageIcon(icon) ? "web" : (icon || "web");
    }

    property var serviceGroups: []
    readonly property int serviceCount: {
        let count = 0;
        for (const group of serviceGroups) {
            if (Array.isArray(group.services))
                count += group.services.length;
        }
        return count;
    }

    function loadCatalog(rawCatalog) {
        try {
            const catalog = JSON.parse(rawCatalog);
            if (!catalog || !Array.isArray(catalog.groups))
                throw new Error("expected a groups array");

            root.serviceGroups = catalog.groups.filter(group => group && typeof group.name === "string" && Array.isArray(group.services));
        } catch (error) {
            root.serviceGroups = [];
            console.warn("Service Hub: failed to load services.json:", error);
        }
    }

    FileView {
        id: catalogFile

        path: root.catalogPath
        blockLoading: false
        blockWrites: true
        watchChanges: true
        printErrors: false

        onLoaded: root.loadCatalog(catalogFile.text())
        onFileChanged: reload()
        onLoadFailed: root.serviceGroups = []
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "hub"
                size: root.iconSize - 4
                color: Theme.widgetTextColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "Services"
                color: Theme.widgetTextColor
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS

            DankIcon {
                name: "hub"
                size: root.iconSize - 4
                color: Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.serviceCount.toString()
                color: Theme.widgetTextColor
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: 640

    popoutContent: Component {
        PopoutComponent {
            id: popout

            width: parent.width
            headerText: "Local services"
            detailsText: root.serviceCount === 0 ? "No services configured" : root.serviceCount + (root.serviceCount === 1 ? " web interface" : " web interfaces")
            showCloseButton: true

            Item {
                id: body

                width: parent.width
                readonly property real catalogContentHeight: root.serviceCount === 0 ? 80 : serviceColumn.height + Theme.spacingM * 2
                readonly property real maxBodyHeight: {
                    const screenHeight = root.parentScreen?.height ?? 0;
                    if (screenHeight <= 0)
                        return 520;
                    return Math.max(240, Math.min(720, screenHeight * 0.72));
                }
                implicitHeight: Math.min(catalogContentHeight, maxBodyHeight)
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.wallpaperSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    opacity: 0.11
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.withAlpha(Theme.surfaceContainer, 0.78)
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.wallpaperPath.startsWith("#") ? Theme.wallpaperPath : Theme.primary
                    opacity: Theme.wallpaperPath.startsWith("#") ? 0.10 : 0.035
                }

                DankFlickable {
                    id: serviceViewport

                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: body.catalogContentHeight

                    Column {
                        id: serviceColumn

                        x: Theme.spacingM
                        y: Theme.spacingM
                        width: parent.width - Theme.spacingM * 2
                        height: childrenRect.height
                        spacing: Theme.spacingM

                        Repeater {
                            model: root.serviceGroups

                            delegate: Column {
                                id: group

                                width: parent.width
                                spacing: Theme.spacingS
                                height: groupHeader.height + spacing + serviceFlow.height

                                Row {
                                    id: groupHeader

                                    width: parent.width
                                    height: 28
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: modelData.icon || "apps"
                                        size: Theme.iconSizeSmall
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: modelData.name
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.DemiBold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: modelData.services.length.toString()
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Flow {
                                    id: serviceFlow

                                    width: parent.width
                                    spacing: Theme.spacingS
                                    height: childrenRect.height

                                    Repeater {
                                        model: modelData.services

                                        delegate: Rectangle {
                                            id: serviceCard

                                            width: Math.max(0, (serviceFlow.width - Theme.spacingS) / 2)
                                            height: 96
                                            radius: Theme.cornerRadius
                                            color: cardMouse.containsMouse ? Theme.withAlpha(Theme.primaryContainer, 0.86) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.82)
                                            border.width: 1
                                            border.color: cardMouse.containsMouse ? Theme.primary : Theme.outlineLight

                                            Row {
                                                id: cardContent

                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingM
                                                spacing: Theme.spacingM

                                                Item {
                                                    id: iconFrame

                                                    width: 42
                                                    height: 42
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 14
                                                        color: Theme.withAlpha(Theme.primaryContainer, 0.92)
                                                    }

                                                    Image {
                                                        id: serviceImage

                                                        anchors.fill: parent
                                                        anchors.margins: 7
                                                        source: root.imageIconSource(modelData.icon)
                                                        fillMode: Image.PreserveAspectFit
                                                        asynchronous: true
                                                        smooth: true
                                                        visible: root.isImageIcon(modelData.icon) && status === Image.Ready
                                                    }

                                                    DankIcon {
                                                        anchors.centerIn: parent
                                                        name: root.materialIconName(modelData.icon)
                                                        size: 26
                                                        color: Theme.primary
                                                        visible: !serviceImage.visible
                                                    }
                                                }

                                                Column {
                                                    width: Math.max(0, cardContent.width - iconFrame.width - arrowFrame.width - cardContent.spacing * 2)
                                                    spacing: Theme.spacingXXS
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    StyledText {
                                                        width: parent.width
                                                        text: modelData.name || "Unnamed service"
                                                        color: Theme.surfaceText
                                                        font.pixelSize: Theme.fontSizeMedium
                                                        font.weight: Font.DemiBold
                                                        elide: Text.ElideRight
                                                    }

                                                    StyledText {
                                                        width: parent.width
                                                        text: modelData.description || ""
                                                        color: Theme.surfaceVariantText
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        maximumLineCount: 2
                                                        elide: Text.ElideRight
                                                    }

                                                    Rectangle {
                                                        width: portText.implicitWidth + Theme.spacingS * 2
                                                        height: 22
                                                        radius: 11
                                                        color: Theme.withAlpha(Theme.primaryContainer, 0.78)

                                                        StyledText {
                                                            id: portText

                                                            anchors.centerIn: parent
                                                            text: modelData.port === undefined ? "local" : ":" + modelData.port
                                                            color: Theme.primary
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            isMonospace: true
                                                        }
                                                    }
                                                }

                                                Item {
                                                    id: arrowFrame

                                                    width: 22
                                                    height: 22
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    DankIcon {
                                                        anchors.centerIn: parent
                                                        name: "open_in_new"
                                                        size: Theme.iconSizeSmall
                                                        color: cardMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: cardMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                onClicked: {
                                                    if (modelData.url)
                                                        Qt.openUrlExternally(modelData.url);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        StyledRect {
                            width: parent.width
                            height: visible ? 64 : 0
                            visible: root.serviceCount === 0
                            radius: Theme.cornerRadius
                            color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.72)
                            border.width: 1
                            border.color: Theme.outlineLight

                            StyledText {
                                anchors.centerIn: parent
                                text: "Add services to services.json"
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeMedium
                            }
                        }
                    }
                }
            }
        }
    }
}
