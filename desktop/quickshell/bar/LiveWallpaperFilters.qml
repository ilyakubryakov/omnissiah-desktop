pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared
import "LiveWallpaper.js" as Live

ColumnLayout {
    id: root
    property var tags: ({})
    property var types: []
    property var ratings: ["everyone"]
    signal submitted()
    readonly property var filters: ({
        sort: sort.currentValue || "trend",
        days: period.currentValue || 7,
        types: types,
        ratings: ratings,
        tags: genres.selectedTags.concat(misc.selectedTags),
        resolution: resolution.currentText === "Any resolution" ? "" : resolution.currentText,
        search: search.text
    })
    spacing: Shared.DesktopStyle.spaceUnit

    function toggle(values, value) {
        return values.includes(value) ? values.filter(entry => entry !== value) : values.concat([value])
    }

    component FilterLabel: UiLabel {
        Layout.topMargin: Shared.DesktopStyle.spaceUnit
        color: Colors.muted
    }

    component TagFilter: UiButton {
        id: filter
        required property string label
        property var choices: []
        property var selectedTags: []
        Layout.fillWidth: true
        alignLeft: true
        text: selectedTags.length ? label + " (" + selectedTags.length + ")" : label
        enabled: choices.length > 0
        onClicked: menu.open()

        Popup {
            id: menu
            y: filter.height + Shared.DesktopStyle.spaceUnit
            width: filter.width
            padding: Shared.DesktopStyle.spaceUnit
            height: Math.min(list.contentHeight + 2 * padding, Shared.DesktopStyle.px(280))
            focus: true
            background: Rectangle {
                color: Colors.lightBackground
                radius: Shared.DesktopStyle.radiusControl
                border.color: Colors.selection
                border.width: Shared.DesktopStyle.focusWidth
            }
            contentItem: ListView {
                id: list
                clip: true
                model: menu.visible ? filter.choices : []
                currentIndex: 0
                focus: true
                function toggleCurrent() {
                    if (currentIndex >= 0)
                        filter.selectedTags = root.toggle(filter.selectedTags, filter.choices[currentIndex])
                }
                Keys.onSpacePressed: toggleCurrent()
                Keys.onReturnPressed: toggleCurrent()
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: UiButton {
                    required property string modelData
                    required property int index
                    width: list.width
                    alignLeft: true
                    subtle: true
                    selected: filter.selectedTags.includes(modelData)
                    glyph: selected ? "✓" : ""
                    text: modelData
                    Accessible.role: Accessible.CheckBox
                    Accessible.checked: selected
                    onClicked: {
                        list.currentIndex = index
                        filter.selectedTags = root.toggle(filter.selectedTags, modelData)
                    }
                }
            }
        }
    }

    TextField {
        id: search
        Layout.fillWidth: true
        implicitHeight: Shared.DesktopStyle.controlHeight
        leftPadding: Shared.DesktopStyle.controlPadding
        rightPadding: leftPadding
        placeholderText: "Search Workshop…"
        Accessible.name: "Search Workshop"
        font.family: Colors.textFont
        font.pixelSize: Shared.DesktopStyle.fontSize
        color: Colors.foreground
        selectionColor: Colors.accent
        background: Rectangle {
            color: Colors.lightBackground
            radius: Shared.DesktopStyle.radiusControl
            border.width: Shared.DesktopStyle.focusWidth
            border.color: search.activeFocus ? Colors.accent : Colors.selection
        }
        onAccepted: root.submitted()
    }

    FilterLabel { text: "Sort by" }
    UiComboBox {
        id: sort
        Layout.fillWidth: true
        model: Live.sorts
        textRole: "label"
        valueRole: "value"
        Accessible.name: "Sort by"
    }

    FilterLabel { text: "Trending period"; visible: period.visible }
    UiComboBox {
        id: period
        Layout.fillWidth: true
        visible: sort.currentValue === "trend"
        model: Live.periods
        textRole: "label"
        valueRole: "value"
        currentIndex: 1
        Accessible.name: "Trending period"
    }

    FilterLabel { text: "Type" }
    Flow {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        spacing: Shared.DesktopStyle.spaceUnit
        Repeater {
            model: ["video", "scene", "web"]
            UiButton {
                required property string modelData
                text: Live.typeLabel(modelData)
                selected: root.types.includes(modelData)
                Accessible.role: Accessible.CheckBox
                Accessible.checked: selected
                onClicked: root.types = root.toggle(root.types, modelData)
            }
        }
    }

    FilterLabel { text: "Age rating" }
    Flow {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        spacing: Shared.DesktopStyle.spaceUnit
        Repeater {
            model: ["Everyone", "Questionable", "Mature"]
            UiButton {
                required property string modelData
                readonly property string rating: modelData.toLowerCase()
                text: modelData
                selected: root.ratings.includes(rating)
                Accessible.role: Accessible.CheckBox
                Accessible.checked: selected
                onClicked: {
                    const ratings = root.toggle(root.ratings, rating)
                    if (ratings.length) root.ratings = ratings
                }
            }
        }
    }

    FilterLabel { text: "Tags" }
    TagFilter { id: genres; label: "Genre"; choices: root.tags.genre || [] }
    TagFilter { id: misc; label: "Miscellaneous"; choices: root.tags.misc || [] }
    UiButton {
        visible: genres.selectedTags.length + misc.selectedTags.length > 0
        text: "Clear tags"
        subtle: true
        onClicked: {
            genres.selectedTags = []
            misc.selectedTags = []
        }
    }

    FilterLabel { text: "Resolution" }
    UiComboBox {
        id: resolution
        Layout.fillWidth: true
        model: ["Any resolution"].concat(root.tags.resolution || [])
        Accessible.name: "Resolution"
    }
}
