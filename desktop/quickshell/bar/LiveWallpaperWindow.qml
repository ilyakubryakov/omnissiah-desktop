pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../shared" as Shared
import "LiveWallpaper.js" as Live

FloatingWindow {
    id: root
    title: "Live wallpapers"
    visible: LiveWallpaperData.open
    implicitWidth: Math.min(Shared.DesktopStyle.px(1120), screen ? Math.max(1, screen.width - Shared.DesktopStyle.px(40)) : 1120)
    implicitHeight: Math.min(Shared.DesktopStyle.px(800), screen ? Math.max(1, screen.height - Shared.DesktopStyle.px(80)) : 800)
    minimumSize: Qt.size(Math.min(implicitWidth, Shared.DesktopStyle.px(900)),
        Math.min(implicitHeight, Shared.DesktopStyle.px(540)))
    color: Colors.background
    onClosed: LiveWallpaperData.open = false

    property string tab: "installed"
    readonly property bool workshop: tab === "workshop"
    readonly property bool browsing: visible && workshop
    readonly property bool canQuery: browsing && LiveWallpaperData.status.key === true
    property var localItems: null
    property string librarySnapshot: ""
    property var tags: ({})
    property bool tagsLoaded: false
    property string libraryError: ""
    property string tagsError: ""
    property string queryError: ""
    property bool queryNeeded: false
    property int total: -1
    property string nextCursor: ""
    property var workshopIds: new Set()

    onVisibleChanged: {
        if (!visible) return
        refresh()
        body.forceActiveFocus()
    }
    onTabChanged: grid.positionViewAtBeginning()
    onBrowsingChanged: if (browsing && !tagsLoaded) readTags()
    onCanQueryChanged: if (canQuery) scheduleQuery()

    function refresh() {
        LiveWallpaperData.refresh()
        libraryRead.run(["library"])
    }

    Connections {
        target: LiveWallpaperData
        function onLibraryChanged() {
            if (libraryRead.pending) libraryRead.reread = true
            else if (root.visible) libraryRead.run(["library"])
        }
    }

    function readTags() {
        tagsError = ""
        tagsRead.run(["tags"])
    }

    function scheduleQuery() {
        if (!canQuery) return
        queryNeeded = true
        queryError = ""
        nextCursor = ""
        queryDelay.restart()
    }

    function query(more) {
        if (!canQuery || queryRead.pending || (more && !nextCursor)) return
        queryDelay.stop()
        queryNeeded = false
        queryError = ""
        if (!more) {
            workshopRows.clear()
            workshopIds.clear()
            total = -1
            nextCursor = ""
            grid.positionViewAtBeginning()
        }
        queryRead.cursor = nextCursor
        queryRead.run(Live.queryArgs(filters.filters, queryRead.cursor))
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }

    Timer {
        id: queryDelay
        interval: 350
        onTriggered: root.query(false)
    }

    ListModel { id: installedRows }
    ListModel { id: workshopRows }

    LiveWallpaperRequest {
        id: libraryRead
        property bool reread: false
        onFinished: raw => {
            const result = Live.plain(raw)
            if (reread) {
                reread = false
                Qt.callLater(() => { if (root.visible) libraryRead.run(["library"]) })
                return
            }
            root.libraryError = result.error || (Array.isArray(result.items) ? "" : "Invalid live wallpaper library")
            if (root.libraryError) return
            const snapshot = JSON.stringify(result.items)
            if (snapshot === root.librarySnapshot) return
            const byId = Object.create(null)
            installedRows.clear()
            for (const item of result.items) {
                if (Object.prototype.hasOwnProperty.call(byId, item.id)) continue
                byId[item.id] = item
                installedRows.append(Live.gridItem(item, false))
            }
            root.localItems = byId
            root.librarySnapshot = snapshot
        }
    }

    LiveWallpaperRequest {
        id: tagsRead
        onFinished: raw => {
            const result = Live.plain(raw)
            root.tagsError = result.error || (Array.isArray(result.genre) && Array.isArray(result.misc)
                && Array.isArray(result.resolution) ? "" : "Invalid Workshop tags")
            if (!root.tagsError) {
                root.tags = result
                root.tagsLoaded = true
            }
        }
    }

    LiveWallpaperRequest {
        id: queryRead
        property string cursor: ""
        onFinished: raw => {
            const result = Live.plain(raw)
            if (root.queryNeeded) {
                if (!queryDelay.running) Qt.callLater(() => root.query(false))
                return
            }
            if (!root.canQuery) return
            root.queryError = result.error || (Array.isArray(result.items) ? "" : "Invalid Workshop results")
            if (root.queryError) return
            const page = Live.workshopPage(result, cursor, root.workshopIds)
            for (const item of page.items)
                workshopRows.append(item)
            root.nextCursor = page.nextCursor
            root.total = result.total
        }
    }

    component Badge: Rectangle {
        property alias text: label.text
        property alias textColor: label.color
        implicitWidth: label.implicitWidth + 2 * Shared.DesktopStyle.spaceUnit
        implicitHeight: label.implicitHeight + Shared.DesktopStyle.spaceUnit
        radius: Shared.DesktopStyle.radiusSmall
        color: Colors.selection
        UiLabel {
            id: label
            anchors.centerIn: parent
            font.pixelSize: Shared.DesktopStyle.px(11)
            wrapMode: Text.NoWrap
        }
    }

    FocusScope {
        id: body
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (LiveWallpaperData.customizing) LiveWallpaperData.customizeId = ""
            else LiveWallpaperData.open = false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Shared.DesktopStyle.px(20)
            spacing: Shared.DesktopStyle.px(12)

            RowLayout {
                Layout.fillWidth: true
                UiLabel {
                    Layout.fillWidth: true
                    text: LiveWallpaperData.customizing ? "Customize" : "Live wallpapers"
                    font.pixelSize: Shared.DesktopStyle.px(20)
                    font.weight: Font.DemiBold
                    MouseArea { anchors.fill: parent; onPressed: root.startSystemMove() }
                }
                UiButton {
                    visible: LiveWallpaperData.customizing
                    text: "Back · Esc"
                    onClicked: LiveWallpaperData.customizeId = ""
                }
                UiButton {
                    text: LiveWallpaperData.customizing ? "Close" : "Close · Esc"
                    onClicked: LiveWallpaperData.open = false
                }
            }
            UiLabel {
                Layout.fillWidth: true
                text: LiveWallpaperData.serviceChecked && !LiveWallpaperData.serviceRunning
                    ? "The live wallpaper service is unavailable." : LiveWallpaperData.statusText
                color: LiveWallpaperData.statusError || LiveWallpaperData.status.error ? Colors.red : Colors.accent
            }
            RowLayout {
                Layout.fillWidth: true
                visible: !LiveWallpaperData.customizing && LiveWallpaperData.status.assets === false
                UiLabel {
                    Layout.fillWidth: true
                    text: "Wallpaper Engine is not installed in Steam"
                    color: Colors.muted
                }
                UiButton {
                    text: "Install in Steam"
                    enabled: !LiveWallpaperData.busy
                    onClicked: LiveWallpaperData.run(["install"])
                }
            }
            UiLabel {
                Layout.fillWidth: true
                visible: !LiveWallpaperData.customizing && LiveWallpaperData.status.key === false
                text: "Steam Web API key missing: run oninix-livewall key set"
                color: Colors.muted
            }
            UiLabel {
                Layout.fillWidth: true
                visible: !!text
                text: LiveWallpaperData.customizing ? LiveWallpaperData.actionError
                    : [LiveWallpaperData.actionError, root.libraryError,
                        root.workshop ? root.tagsError : "", root.workshop ? root.queryError : ""].filter(Boolean).join("\n")
                color: Colors.red
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: active
                active: LiveWallpaperData.customizing
                sourceComponent: LiveWallpaperCustomize {}
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !LiveWallpaperData.customizing
                Segmented {
                    model: [{id: "installed", title: "Installed"}, {id: "workshop", title: "Workshop"}]
                    current: root.tab
                    onChosen: id => root.tab = id
                }
                Item { Layout.fillWidth: true }
                UiButton {
                    visible: LiveWallpaperData.properties.length > 0
                    text: "Customize"
                    enabled: !LiveWallpaperData.busy
                    onClicked: LiveWallpaperData.openCustomize()
                }
                UiButton {
                    visible: !root.workshop
                    text: "Refresh"
                    enabled: !libraryRead.pending
                    onClicked: root.refresh()
                }
                UiButton {
                    visible: root.workshop && !!root.tagsError
                    text: "Retry tags"
                    enabled: !tagsRead.pending
                    onClicked: root.readTags()
                }
                UiButton {
                    visible: root.workshop
                    text: "Open Workshop in Steam"
                    subtle: true
                    enabled: !LiveWallpaperData.busy
                    onClicked: LiveWallpaperData.run(["open-workshop"])
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !LiveWallpaperData.customizing
                spacing: Shared.DesktopStyle.px(12)

                ScrollView {
                    id: filterScroll
                    visible: root.workshop
                    enabled: root.canQuery
                    Layout.fillHeight: true
                    Layout.preferredWidth: Shared.DesktopStyle.px(230)
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    LiveWallpaperFilters {
                        id: filters
                        width: filterScroll.availableWidth
                        tags: root.tags
                        onFiltersChanged: root.scheduleQuery()
                        onSubmitted: {
                            if (queryRead.pending) root.scheduleQuery()
                            else root.query(false)
                        }
                    }
                }

                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    reuseItems: true
                    readonly property int preferredCellWidth: Shared.DesktopStyle.px(240)
                    cellWidth: width / Math.max(1, Math.floor(width / preferredCellWidth))
                    cellHeight: Shared.DesktopStyle.px(264)
                    model: !root.visible ? null : root.workshop ? (root.canQuery && !root.queryNeeded ? workshopRows : null) : installedRows
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Item {
                        id: card
                        required property string wallpaperId
                        required property string wallpaperTitle
                        required property string wallpaperType
                        required property string previewUrl
                        required property bool installedInQuery
                        required property real subscriptions
                        readonly property var local: root.localItems ? root.localItems[wallpaperId] : null
                        readonly property bool installed: !!local || installedInQuery
                        readonly property bool applied: LiveWallpaperData.status.mode === "live"
                            && LiveWallpaperData.status.item?.id === wallpaperId
                        readonly property bool unsupported: local?.supported === false
                        readonly property bool broken: !root.workshop && local?.broken === true
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Shared.DesktopStyle.px(5)
                            radius: Shared.DesktopStyle.radiusCard
                            color: Colors.lightBackground
                            opacity: card.unsupported ? 0.65 : card.broken ? 0.78 : 1
                            border.width: card.applied ? Shared.DesktopStyle.focusWidth : 0
                            border.color: Colors.accent

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Shared.DesktopStyle.px(10)
                                spacing: Shared.DesktopStyle.spaceUnit

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: Shared.DesktopStyle.px(44)
                                    radius: Shared.DesktopStyle.radiusSmall
                                    color: Colors.darkBackground
                                    clip: true
                                    Image {
                                        id: preview
                                        anchors.fill: parent
                                        source: card.previewUrl
                                        asynchronous: true
                                        sourceSize: Qt.size(Shared.DesktopStyle.px(520), Shared.DesktopStyle.px(320))
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    UiLabel {
                                        anchors.centerIn: parent
                                        visible: preview.status !== Image.Ready
                                        text: preview.status === Image.Loading ? "Loading preview…" : "Preview unavailable"
                                        color: Colors.muted
                                        font.pixelSize: Shared.DesktopStyle.px(11)
                                    }
                                }
                                UiLabel {
                                    Layout.fillWidth: true
                                    text: card.wallpaperTitle
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    font.weight: Font.DemiBold
                                    ToolTip.visible: truncated && titleHover.hovered
                                    ToolTip.text: text
                                    HoverHandler { id: titleHover }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Badge { text: Live.typeLabel(card.wallpaperType) }
                                    Badge { visible: root.workshop && card.installed; text: "Installed"; textColor: Colors.accent }
                                    Badge { visible: card.broken; text: "Broken on Linux"; textColor: Colors.statusWarning }
                                }
                                UiLabel {
                                    Layout.fillWidth: true
                                    visible: root.workshop
                                    text: card.subscriptions.toLocaleString(Qt.locale(), "f", 0) + " subscriptions"
                                    font.pixelSize: Shared.DesktopStyle.px(11)
                                    color: Colors.muted
                                }
                                UiLabel {
                                    Layout.fillWidth: true
                                    visible: card.unsupported
                                    text: card.unsupported ? card.local.reason || "Unsupported wallpaper" : ""
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    color: Colors.muted
                                    font.pixelSize: Shared.DesktopStyle.px(11)
                                    ToolTip.visible: truncated && reasonHover.hovered
                                    ToolTip.text: text
                                    HoverHandler { id: reasonHover }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Shared.DesktopStyle.spaceUnit
                                    UiButton {
                                        Layout.fillWidth: true
                                        text: card.applied ? "Applied" : card.installed ? "Apply" : "Subscribe in Steam"
                                        enabled: !LiveWallpaperData.busy && !card.applied && !card.unsupported
                                            && (!card.installed || LiveWallpaperData.serviceRunning)
                                        onClicked: LiveWallpaperData.run(card.installed
                                            ? ["set", "live", card.wallpaperId] : ["open", card.wallpaperId])
                                    }
                                    UiButton {
                                        visible: !root.workshop
                                        text: card.broken ? "Mark as working" : "Mark as broken"
                                        subtle: true
                                        enabled: !LiveWallpaperData.busy && !libraryRead.pending
                                        onClicked: LiveWallpaperData.run(["mark", card.wallpaperId, card.broken ? "ok" : "broken"])
                                    }
                                }
                            }
                        }
                    }

                    UiLabel {
                        anchors.centerIn: parent
                        width: parent.width - Shared.DesktopStyle.px(24)
                        horizontalAlignment: Text.AlignHCenter
                        visible: grid.count === 0
                        color: Colors.muted
                        text: {
                            if (!root.workshop)
                                return libraryRead.pending ? "Reading installed wallpapers…"
                                    : root.libraryError ? "" : "No installed wallpapers"
                            if (!root.canQuery || root.queryError) return ""
                            if (root.queryNeeded || queryRead.pending) return "Searching Workshop…"
                            return root.total >= 0 ? "No matching wallpapers" : ""
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !LiveWallpaperData.customizing && root.workshop && root.canQuery
                UiLabel {
                    Layout.fillWidth: true
                    visible: root.total >= 0 && !root.queryNeeded
                    text: workshopRows.count + " of " + root.total + " results"
                    color: Colors.muted
                    font.pixelSize: Shared.DesktopStyle.px(12)
                }
                UiButton {
                    visible: !!root.queryError || !!root.nextCursor
                    enabled: !queryRead.pending
                    text: root.queryError ? "Retry search" : "Load more"
                    onClicked: root.query(!!root.nextCursor)
                }
            }
        }
    }
}
