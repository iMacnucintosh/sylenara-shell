pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Sylenara.Config
import Sylenara.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common
import "../../../utils/scripts/displaylayout.js" as Arrange

// Monitor settings block — lives inline on Connected devices (not a Stack subpage).
ColumnLayout {
    id: root

    required property var nState

    Layout.fillWidth: true
    spacing: Tokens.spacing.extraSmall / 2

    Component.onCompleted: Displays.refresh()

    // The display whose settings are shown below the canvas (with a single display, its settings are all there is)
    property string selected
    readonly property bool multi: Displays.monitors.length > 1
    // Numbers as they are on the desk, left to right
    readonly property var numbers: Arrange.numbering(Displays.layoutOf(Displays.monitors))
    readonly property var labels: {
        const out = {};
        for (let i = 0; i < Displays.monitors.length; i++) {
            const m = Displays.monitors[i];
            out[m.name] = {
                number: root.numbers[m.name] ? String(root.numbers[m.name]) : "",
                title: m.model || m.description || m.name,
                detail: m.disabled ? Tr.trCtx("Off", "display that is turned off") : (m.mirror ? Tr.tr("Copy of %1").arg(m.mirror) : `${Displays.formatResolutionLabel(Displays.resolutionKeyOf(m.mode))} · ${Displays.formatRateLabel(m.mode)}`)
            };
        }
        return out;
    }

    function selectedName(): string {
        return Displays.findMonitor(root.selected) ? root.selected : (Displays.monitors[0]?.name ?? "");
    }

    function isShown(name: string): bool {
        return !root.multi || root.selectedName() === name;
    }

    function rotationLabel(transform: int): string {
        switch (transform) {
        case 0:
            return Tr.trCtx("Normal", "screen rotation");
        case 1:
            return Tr.tr("90°");
        case 2:
            return Tr.tr("180°");
        case 3:
            return Tr.tr("270°");
        }
        return Tr.tr("Flipped");
    }

    DisplayIdentify {
        id: identify

        labels: root.labels
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        SectionHeader {
            text: Tr.trCtx("Display", "monitor settings")
        }

        IconTextButton {
            visible: root.multi
            Layout.topMargin: Tokens.spacing.extraSmall
            isRound: true
            type: IconTextButton.Tonal
            horizontalPadding: Tokens.padding.large
            verticalPadding: Tokens.padding.small
            icon: "badge"
            text: Tr.tr("Identify")
            onClicked: identify.show()
        }
    }

    DisplayCanvas {
        id: canvas

        visible: root.multi
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        Layout.bottomMargin: Tokens.spacing.small
        enabled: !Displays.confirming
        layout: Displays.currentLayout()
        labels: root.labels
        selected: root.selectedName()
        canvasColor: Colours.tPalette.m3surfaceContainer
        tileColor: Colours.palette.m3surfaceContainerHigh
        tileBorderColor: Colours.palette.m3outlineVariant
        selectedColor: Colours.palette.m3primaryContainer
        selectedBorderColor: Colours.palette.m3primary
        textColor: Colours.palette.m3onSurface
        detailColor: Colours.palette.m3onSurfaceVariant
        ghostColor: Colours.palette.m3primary
        numberFont: Tokens.font.headline.small
        titleFont: Tokens.font.label.large
        detailFont: Tokens.font.label.small
        tileRadius: Tokens.rounding.large
        primary: Activities.primaryName
        starColor: Colours.palette.m3tertiary
        onPicked: name => root.selected = name
        onPrimaryPicked: name => Activities.setPrimaryDisplay(name)
        onDropped: (name, x, y) => Displays.dropMonitor(name, x, y)
    }

    StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.small
        Layout.bottomMargin: Tokens.spacing.small
        visible: root.multi
        text: Tr.tr("Drag the displays to arrange them as they are on your desk. Pick one to change its settings. The star marks the main display: it shows the notifications, volume and brightness.")
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
        wrapMode: Text.Wrap
    }

    // Displays that are off or copy another one are not on the canvas: they are picked here
    Flow {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.small
        visible: root.multi
        spacing: Tokens.spacing.small

        Repeater {
            model: Displays.monitors

            TextButton {
                required property var modelData

                isRound: true
                type: root.selectedName() === modelData.name ? TextButton.Tonal : TextButton.Text
                horizontalPadding: Tokens.padding.large
                text: `${root.numbers[modelData.name] ? root.numbers[modelData.name] + " · " : ""}${modelData.model || modelData.description || modelData.name}`
                onClicked: root.selected = modelData.name
            }
        }
    }

    // A new arrangement waits to be applied
    StyledRect {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.small
        visible: Displays.hasDraftChanges
        implicitHeight: draftRow.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.large
        color: Colours.palette.m3secondaryContainer

        RowLayout {
            id: draftRow

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            anchors.leftMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("New arrangement, not applied yet")
                color: Colours.palette.m3onSecondaryContainer
                font: Tokens.font.body.small
                wrapMode: Text.Wrap
            }

            TextButton {
                isRound: true
                type: TextButton.Text
                text: Tr.trCtx("Discard", "button")
                onClicked: Displays.discardDraft()
            }

            TextButton {
                isRound: true
                type: TextButton.Filled
                text: Tr.trCtx("Apply", "button")
                onClicked: Displays.applyDraft()
            }
        }
    }

    // A change that could leave a screen unusable is undone by itself if nobody keeps it
    StyledRect {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.small
        visible: Displays.confirming
        implicitHeight: keepRow.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.large
        color: Colours.palette.m3tertiaryContainer

        RowLayout {
            id: keepRow

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            anchors.leftMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                // TRANSLATORS: %1 = seconds left
                text: Tr.tr("Keep these display settings? Going back in %1 s").arg(Displays.revertIn)
                color: Colours.palette.m3onTertiaryContainer
                font: Tokens.font.body.small
                wrapMode: Text.Wrap
            }

            TextButton {
                isRound: true
                type: TextButton.Text
                text: Tr.trCtx("Go back", "button")
                onClicked: Displays.revert(false)
            }

            TextButton {
                isRound: true
                type: TextButton.Filled
                text: Tr.trCtx("Keep", "button")
                onClicked: Displays.confirm()
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Displays.lastError.length > 0
        text: Displays.lastError
        color: Colours.palette.m3error
        font: Tokens.font.body.small
        wrapMode: Text.Wrap
    }

    StyledText {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.small
        visible: Displays.monitors.length === 0 && !Displays.loading && Displays.lastError.length === 0
        text: Tr.tr("No displays detected")
        color: Colours.palette.m3outline
        font: Tokens.font.body.small
    }

    Repeater {
        model: Displays.monitors

        ColumnLayout {
            id: monCol

            required property var modelData
            required property int index

            readonly property var mon: modelData
            readonly property real maxHz: Number(mon.maxHz) || 0
            readonly property real currentHz: {
                const p = Displays.parseMode(mon.mode);
                return p ? p.hz : (Number(mon.refreshRate) || 0);
            }
            readonly property bool connectorLimited: monCol.maxHz > 0 && monCol.maxHz < 200 && monCol.currentHz >= 100
            readonly property int vrrPolicy: Displays.normalizeVrr(Number(mon.vrr) || 0)
            // Stable lists for Variants — calling helpers inline in `model:` rebuilds
            // the array every eval and can leave the SplitButton menu empty/unusable.
            readonly property var resolutions: Displays.resolutionsFromModes(mon.availableModes)
            readonly property string resKey: Displays.resolutionKeyOf(mon.mode)
            readonly property var rates: Displays.ratesForResolution(mon.availableModes, monCol.resKey)

            Layout.fillWidth: true
            Layout.topMargin: root.multi || index === 0 ? 0 : Tokens.spacing.large - parent.spacing
            visible: root.isShown(mon.name)
            spacing: Tokens.spacing.extraSmall / 2

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.small
                Layout.bottomMargin: Tokens.spacing.extraSmall
                text: (mon.description || mon.name) + (mon.description ? ` · ${mon.name}` : "")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            ToggleRow {
                id: enabledRow

                visible: root.multi
                first: true
                last: mon.disabled
                text: Tr.trCtx("Enabled", "toggle label")
                subtext: !mon.disabled && Displays.activeCount <= 1 ? Tr.tr("It is the only display that is on") : ""
                checked: !mon.disabled
                disabled: !mon.disabled ? Displays.activeCount <= 1 : false
                onToggled: Displays.setEnabled(mon.name, checked)
            }

            SelectRow {
                id: resRow

                visible: !mon.disabled
                first: !root.multi
                label: Tr.tr("Resolution")
                subtext: Displays.formatResolutionLabel(monCol.resKey)
                active: resItems.instances.find(i => i.modelData === monCol.resKey) ?? null
                fallbackText: Displays.formatResolutionLabel(monCol.resKey)
                onSelected: item => Displays.setResolution(mon.name, item.modelData)

                menuItems: resItems.instances

                Variants {
                    id: resItems

                    model: monCol.resolutions

                    MenuItem {
                        required property string modelData

                        text: Displays.formatResolutionLabel(modelData)
                    }
                }
            }

            SelectRow {
                id: rateRow

                visible: !mon.disabled
                label: Tr.tr("Refresh rate")
                subtext: Displays.formatRateLabel(mon.mode)
                // Short list (same resolution only) so the menu stays inside Nexus.
                active: rateItems.instances.find(i => Displays.modeForHypr(i.modelData) === Displays.modeForHypr(mon.mode)) ?? null
                fallbackText: Displays.formatRateLabel(mon.mode)
                onSelected: item => Displays.setMode(mon.name, item.modelData)

                menuItems: rateItems.instances

                Variants {
                    id: rateItems

                    model: monCol.rates

                    MenuItem {
                        required property string modelData

                        text: Displays.formatRateLabel(modelData)
                    }
                }
            }

            SelectRow {
                id: scaleRow

                visible: !mon.disabled
                label: Tr.tr("Scale")
                subtext: Tr.tr("%1%").arg(Math.round((Number(mon.scale) || 1) * 100))
                active: scaleItems.instances.find(i => Math.abs(i.modelData - (Number(mon.scale) || 1)) < 0.001) ?? null
                fallbackText: Tr.tr("%1%").arg(Math.round((Number(mon.scale) || 1) * 100))
                onSelected: item => Displays.setScale(mon.name, item.modelData)

                menuItems: scaleItems.instances

                Variants {
                    id: scaleItems

                    model: Displays.scaleOptions

                    MenuItem {
                        required property real modelData

                        text: Tr.tr("%1%").arg(Math.round(modelData * 100))
                    }
                }
            }

            SelectRow {
                id: rotationRow

                visible: !mon.disabled
                label: Tr.tr("Rotation")
                subtext: root.rotationLabel(Number(mon.transform) || 0)
                active: rotationItems.instances.find(i => i.modelData === (Number(mon.transform) || 0)) ?? null
                fallbackText: root.rotationLabel(Number(mon.transform) || 0)
                onSelected: item => Displays.setTransform(mon.name, item.modelData)

                menuItems: rotationItems.instances

                Variants {
                    id: rotationItems

                    model: [0, 1, 2, 3]

                    MenuItem {
                        required property int modelData

                        text: root.rotationLabel(modelData)
                    }
                }
            }

            SelectRow {
                id: mirrorRow

                visible: root.multi && !mon.disabled
                label: Tr.tr("Copy another display")
                subtext: mon.mirror ? Tr.tr("Shows what %1 shows").arg(mon.mirror) : Tr.trCtx("No", "not copying another display")
                active: mirrorItems.instances.find(i => i.modelData === (mon.mirror || "")) ?? null
                fallbackText: mon.mirror || Tr.trCtx("No", "not copying another display")
                onSelected: item => Displays.setMirror(mon.name, item.modelData)

                menuItems: mirrorItems.instances

                Variants {
                    id: mirrorItems

                    // "" is not copying; the others are the displays that can be copied
                    model: [""].concat(Displays.monitors.filter(m => !m.disabled && !m.mirror && m.name !== mon.name).map(m => m.name))

                    MenuItem {
                        required property string modelData

                        text: modelData === "" ? Tr.trCtx("No", "not copying another display") : modelData
                    }
                }
            }

            SelectRow {
                id: vrrRow

                visible: !mon.disabled
                last: true
                label: Tr.tr("Adaptive Sync")
                subtext: Displays.vrrLabel(monCol.vrrPolicy)
                active: {
                    if (monCol.vrrPolicy === 1)
                        return vrrAlways;
                    if (monCol.vrrPolicy === 2)
                        return vrrAuto;
                    return vrrNever;
                }
                fallbackText: Displays.vrrLabel(monCol.vrrPolicy)
                onSelected: item => Displays.setVrr(mon.name, item.modelData)

                // Plasma order: Never → Automatic → Always
                menuItems: [vrrNever, vrrAuto, vrrAlways]

                MenuItem {
                    id: vrrNever

                    text: Tr.tr("Never")
                    property int modelData: 0
                }

                MenuItem {
                    id: vrrAuto

                    text: Tr.tr("Automatic")
                    property int modelData: 2
                }

                MenuItem {
                    id: vrrAlways

                    text: Tr.tr("Always")
                    property int modelData: 1
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.small
                visible: !mon.disabled
                text: Displays.vrrHint(monCol.vrrPolicy)
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                wrapMode: Text.Wrap
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.small
                visible: !mon.disabled && monCol.vrrPolicy !== 0
                text: mon.vrrActive ? Tr.tr("Currently active on this output") : Tr.tr("Currently inactive on this output")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                wrapMode: Text.Wrap
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                Layout.leftMargin: Tokens.padding.small
                visible: !mon.disabled && monCol.connectorLimited
                text: Tr.tr("This connection tops out at %1 Hz. The panel may support a higher rate over DisplayPort.").arg(Math.round(monCol.maxHz))
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                wrapMode: Text.Wrap
            }
        }
    }

    NavRow {
        Layout.topMargin: Tokens.spacing.large - parent.spacing
        first: true
        last: true
        icon: "crop_free"
        text: Tr.tr("Compact layout")
        subtext: Tr.tr("Session toggle for zero gaps/rounding lives in Panels → Utilities")
        onClicked: root.nState.currentPageIdx = PageRegistry.idxOf("panels")
    }
}
