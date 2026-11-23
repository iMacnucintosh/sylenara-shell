pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import M3Shapes
import Sylenara.Components
import Sylenara.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property int modelData
    required property int index
    required property int activeWsId
    required property int ws
    required property HyprlandMonitor monitor

    required property int displayType
    required property bool showWindows
    required property var iconRules
    // true: real desktop IconImages, hide ws marker when occupied
    // false: category MaterialIcons under the marker (upstream look)
    property bool desktopAppIcons: false
    property string activeLabel
    property string occupiedLabel
    property string label

    // The workspace this desktop has on the monitor of the bar
    readonly property int realWs: Activities.wsFor(ws, monitor?.name ?? "")
    // The windows of the desktop on every monitor, the same in every bar: the main display's first, then the others
    readonly property var groups: Activities.displayOrder.map(n => Hypr.toplevelsForWs(Activities.wsFor(ws, n), GlobalConfig.bar.workspaces.ignoredTags))
    readonly property var toplevels: groups.reduce((all, g) => all.concat(g), [])
    // A line between the icons of two monitors (stable objects, so the list does not rebuild them)
    readonly property var dividers: [({divider: true}), ({divider: true}), ({divider: true}), ({divider: true}), ({divider: true}), ({divider: true}), ({divider: true})]
    readonly property bool isOccupied: toplevels.length > 0
    readonly property bool hasWindows: isOccupied && showWindows && Config.bar.workspaces.maxWindowIcons > 0
    readonly property bool hasDesktopAppIcons: hasWindows && desktopAppIcons
    readonly property bool focused: activeWsId === ws
    readonly property list<int> focusedShapeList: [MaterialShape.Slanted, MaterialShape.Oval, MaterialShape.Pill, MaterialShape.Triangle, MaterialShape.Arrow, MaterialShape.Diamond, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.VerySunny, MaterialShape.Sunny, MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie7Sided, MaterialShape.Cookie9Sided, MaterialShape.Cookie12Sided, MaterialShape.Clover4Leaf, MaterialShape.SoftBurst, MaterialShape.Ghostish]

    property color offMonitorColour: Colours.palette.m3outlineVariant
    readonly property bool onOtherMonitor: {
        if (Config.bar.workspaces.perMonitor)
            return false;
        const mon = Hypr.workspaces.values.find(w => w.id === realWs)?.monitor;
        return !!(mon && mon !== monitor);
    }
    readonly property color fgColour: {
        if (onOtherMonitor)
            return offMonitorColour;
        if (focused || isOccupied || Config.bar.workspaces.occupiedBg)
            return Colours.palette.m3onSurface;
        return Colours.layer(Colours.palette.m3outlineVariant, 2);
    }

    function updateShape(): void {
        const shape = indicator.item as MaterialShape;
        if (!shape)
            return;

        if (focused)
            shape.shape = focusedShapeList[Math.floor(Math.random() * focusedShapeList.length)];
        else
            shape.shape = Qt.binding(() => isOccupied ? MaterialShape.Square : MaterialShape.Circle);
    }

    anchors.horizontalCenter: parent?.horizontalCenter
    // Padding is part of layout.implicitHeight so ActiveIndicator stays in sync
    readonly property real contentPad: hasWindows ? Tokens.padding.small : 0
    LazyListView.preferredHeight: LazyListView.removing ? 0 : layout.implicitHeight
    LazyListView.visibleHeight: LazyListView.preferredHeight

    opacity: LazyListView.removing || LazyListView.adding ? 0 : 1

    onFocusedChanged: updateShape()
    Component.onCompleted: updateShape()

    Behavior on LazyListView.visibleHeight {
        Anim {}
    }

    Behavior on y {
        enabled: root.LazyListView.ready

        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Component {
        id: shapeComponent

        MaterialShape {
            implicitSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small

            color: root.fgColour
            scale: root.focused ? 2 / 3 : root.isOccupied ? 1 / 3 : 1 / 4

            animationEasing: Tokens.anim.expressiveDefaultSpatial
            animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

            Behavior on color {
                CAnim {}
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Component {
        id: textComponent

        StyledText {
            animate: true
            text: {
                if (root.focused) {
                    const label = root.activeLabel;
                    if (label)
                        return label;
                }

                if (root.focused || root.isOccupied) {
                    const label = root.occupiedLabel;
                    if (label)
                        return label;
                }

                const label = root.label;
                if (label)
                    return label;

                const ws = Hypr.workspaces.values.find(w => w.id === root.realWs);
                const wsName = !ws || ws.name == root.ws ? root.ws : Hypr.trimWsName(ws.name)[0];

                const capitalisation = Config.bar.workspaces.capitalisation;
                if (capitalisation === BarWorkspaceCapitalisation.Upper)
                    return String(wsName).toUpperCase();
                else if (capitalisation === BarWorkspaceCapitalisation.Lower)
                    return String(wsName).toLowerCase();
                return wsName;
            }
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter
            font.family: Tokens.font.workspaces
        }
    }

    Component {
        id: iconComponent

        MaterialIcon {
            fill: 1
            grade: 25
            text: iconCacher.icon
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter

            WsIconCacher {
                id: iconCacher
            }
        }
    }

    Component {
        id: iconLoaderComponent

        Loader {
            sourceComponent: loaderIconCacher.icon ? iconComponent : textComponent

            WsIconCacher {
                id: loaderIconCacher
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: parent.width
        spacing: 0

        // Top inset so icons clear the active-indicator rounded edge
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.contentPad
            visible: root.contentPad > 0
        }

        Loader {
            id: indicator

            // Hide marker whenever window icons occupy the slot (desktop or category)
            readonly property bool showMarker: !root.hasWindows

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredHeight: showMarker ? Tokens.sizes.bar.innerWidth - Tokens.padding.small : 0
            opacity: showMarker ? 1 : 0
            active: showMarker || status === Loader.Ready
            visible: Layout.preferredHeight > 0

            sourceComponent: {
                if (root.displayType === BarWorkspaceDisplay.Icons)
                    return iconLoaderComponent;
                if (root.displayType === BarWorkspaceDisplay.Text)
                    return textComponent;
                return shapeComponent;
            }

            onItemChanged: root.updateShape()

            Behavior on Layout.preferredHeight {
                Anim {}
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Loader {
            id: windows

            asynchronous: true

            Layout.fillWidth: true
            Layout.topMargin: root.hasWindows ? 0 : -Tokens.spacing.extraSmall / 2
            Layout.preferredHeight: root.hasWindows && item ? (item as LazyListView).layoutHeight : 0

            visible: active
            active: root.showWindows && Config.bar.workspaces.maxWindowIcons > 0

            sourceComponent: LazyListView {
                spacing: 0
                implicitHeight: contentHeight
                cullDelegates: false
                removeDuration: Tokens.anim.durations.expressiveDefaultEffects

                model: ScriptModel {
                    values: {
                        let budget = root.Config.bar.workspaces.maxWindowIcons;
                        const out = [];
                        for (const g of root.groups) {
                            if (g.length === 0)
                                continue;
                            if (budget <= 0)
                                break;
                            if (out.length > 0)
                                out.push(root.dividers[Math.min(out.length, root.dividers.length - 1)]);
                            // One icon per app: its other windows on that monitor go in the same icon (with a count)
                            const seen = new Set();
                            const firsts = g.filter(t => {
                                const cls = t.lastIpcObject?.class ?? "";
                                if (seen.has(cls))
                                    return false;
                                seen.add(cls);
                                return true;
                            });
                            const take = firsts.slice(0, budget);
                            out.push(...take);
                            budget -= take.length;
                        }
                        return out;
                    }
                }

                delegate: Item {
                    id: win

                    required property var modelData
                    required property int index // Needed, LazyListView will fail to set it if it doesn't exist

                    readonly property bool isDivider: modelData?.divider === true
                    readonly property int iconSize: Math.round((Tokens.sizes.bar.innerWidth - Tokens.padding.small) * 0.55)
                    readonly property string appClass: isDivider ? "" : (modelData.lastIpcObject?.class ?? "")
                    // For the preview popout: which window this icon is, and every window of its app it stands for
                    readonly property var toplevel: isDivider ? null : modelData
                    readonly property var toplevels: isDivider ? [] : (root.groups.find(g => g.includes(modelData)) ?? [modelData]).filter(t => (t.lastIpcObject?.class ?? "") === appClass)

                    Component.onCompleted: {
                        if (!win.isDivider)
                            BarWindowIcons.add(win);
                    }
                    Component.onDestruction: {
                        if (!win.isDivider)
                            BarWindowIcons.remove(win);
                    }

                    width: parent?.width ?? Tokens.sizes.bar.innerWidth
                    implicitHeight: isDivider ? Tokens.spacing.small : (root.desktopAppIcons ? iconSize + Tokens.padding.extraSmall : (winIcon.implicitHeight || iconSize))

                    // The line between the windows of two monitors
                    Rectangle {
                        visible: win.isDivider
                        anchors.centerIn: parent
                        width: win.iconSize * 0.6
                        height: 1
                        radius: 1
                        // On the active desktop (the primary pill) a soft line, not the full outline
                        color: root.focused ? Qt.alpha(Colours.palette.m3onPrimary, 0.3) : Colours.palette.m3outlineVariant
                    }

                    opacity: LazyListView.adding || LazyListView.removing ? 0 : (root.onOtherMonitor ? 0.55 : 1)

                    // Real desktop/theme icons when the activities setting is on
                    AppIcon {
                        anchors.centerIn: parent
                        visible: root.desktopAppIcons && !win.isDivider
                        appClass: win.appClass
                        size: win.iconSize
                        // On the active desktop the pill is the accent colour
                        tint: root.focused ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                    }

                    // How many windows of the app the icon stands for, when more than one
                    StyledRect {
                        visible: root.desktopAppIcons && !win.isDivider && win.toplevels.length > 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: win.iconSize / 2
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: win.iconSize / 2 - height / 4
                        implicitWidth: Math.max(implicitHeight, count.implicitWidth + Tokens.padding.extraSmall * 2)
                        implicitHeight: count.implicitHeight
                        radius: Tokens.rounding.full
                        color: root.focused ? Colours.palette.m3onPrimary : Colours.palette.m3primary

                        StyledText {
                            id: count

                            anchors.centerIn: parent
                            text: win.toplevels.length
                            font: Tokens.font.label.builders.small.weight(Font.Bold).scale(0.7).build()
                            color: root.focused ? Colours.palette.m3primary : Colours.palette.m3onPrimary
                        }
                    }

                    // Upstream category glyphs when the setting is off
                    MaterialIcon {
                        id: winIcon

                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !root.desktopAppIcons && !win.isDivider
                        grade: 0
                        horizontalAlignment: Text.AlignHCenter
                        text: Icons.getAppCategoryIcon(win.appClass, "terminal")
                        color: root.onOtherMonitor ? root.offMonitorColour : Colours.palette.m3onSurfaceVariant
                    }

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Behavior on y {
                        Anim {}
                    }
                }
            }
        }

        // Bottom inset matching the top so the active pill wraps icons cleanly
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.contentPad
            visible: root.contentPad > 0
        }
    }

    component WsIconCacher: QtObject {
        id: cacher

        property string name
        readonly property string icon: Icons.matchIconRuleList(Hypr.trimWsName(name), root.iconRules)
        readonly property HyprlandWorkspace wsObj: Hypr.workspaces.values.find(w => w.id === root.realWs) ?? null

        readonly property Connections conn: Connections {
            function onNameChanged(): void {
                cacher.updateName();
            }

            target: cacher.wsObj
        }

        function updateName(): void {
            if (wsObj)
                name = wsObj.name;
        }

        onWsObjChanged: updateName()
        Component.onCompleted: updateName()
    }
}
