pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Sylphrena.Config
import Sylphrena.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// Sub-page asking for the password of a visible network that needs one (NetworkManager answered "secrets
// required"): opened by NetworkList through nState.pendingNetwork. The bar's popout has its own dialog.
PageBase {
    id: root

    readonly property var network: nState.pendingNetwork
    readonly property string ssid: network?.ssid ?? ""
    property bool connecting: false
    property bool failed: false
    property bool success: false
    // A profile was created with a password typed here: it is removed if the page closes without connecting
    property bool attempted: false

    function submit(): void {
        if (root.connecting || !root.network)
            return;
        if (passwordField.text.length < 8) {
            passwordField.isError = true;
            passwordField.forceActiveFocus();
            return;
        }

        root.failed = false;
        root.connecting = true;
        root.attempted = true;

        NetworkConnection.connectWithPassword(root.network, passwordField.text, result => {
            if (!root.connecting)
                return;
            root.connecting = false;
            if (result && result.success) {
                root.success = true;
                root.nState.closeSubPage();
            } else {
                root.fail();
            }
        });
    }

    function fail(): void {
        root.connecting = false;
        root.failed = true;
        passwordField.isError = true;
        passwordField.text = "";
        passwordField.forceActiveFocus();
        // The half-created profile has the wrong password: a retry starts fresh
        if (root.ssid)
            Nmcli.forgetNetwork(root.ssid);
    }

    title: Tr.tr("Connect to %1").arg(root.ssid)
    isSubPage: true

    Component.onCompleted: passwordField.forceActiveFocus()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        Connections {
            function onSubPageClosed(): void {
                if (!root.success && root.attempted && root.ssid)
                    Nmcli.forgetNetwork(root.ssid);
            }

            target: root.nState
        }

        Connections {
            function onConnectionFailed(ssid: string): void {
                if (root.connecting && ssid === root.ssid)
                    root.fail();
            }

            target: Nmcli
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.extraSmall
            text: Tr.tr("This network is protected. Enter its password to connect.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledTextField {
            id: passwordField

            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            enabled: !root.connecting
            placeholderText: Tr.tr("Password")
            leadingIcon: "key"
            echoMode: TextInput.Password
            // TRANSLATORS: WPA is a protocol name, leave it untranslated
            supportingText: Tr.tr("WPA passwords are at least 8 characters")
            errorText: root.failed ? Tr.tr("Connection failed — check the password") : Tr.tr("Password must be at least 8 characters")

            onAccepted: root.submit()
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Tokens.spacing.extraSmall - parent.spacing
            spacing: Tokens.spacing.small

            TextButton {
                Layout.fillHeight: true
                isRound: true
                horizontalPadding: Tokens.padding.extraLarge
                type: TextButton.Tonal
                text: Tr.trCtx("Cancel", "button")
                onClicked: root.nState.closeSubPage()
            }

            // Connect button: swaps to a loading spinner while connecting, like the Wi-Fi list
            ButtonBase {
                id: connectBtn

                shapeMorph: true
                isRound: true
                inactiveColour: Colours.palette.m3primary
                inactiveOnColour: Colours.palette.m3onPrimary
                stateLayer.disabled: root.connecting || passwordField.text.length === 0

                implicitWidth: connectMetrics.width + Tokens.padding.extraLarge * 2
                implicitHeight: connectMetrics.height + Tokens.padding.medium * 2

                onClicked: root.submit()

                TextMetrics {
                    id: connectMetrics

                    text: Tr.tr("Connect")
                    font: connectBtn.font
                }

                AnimLoader {
                    anchors.centerIn: parent
                    sourceComp: root.connecting ? connectLoadingComp : connectTextComp
                    outAnimType: Anim.SlowEffects
                    inAnimType: Anim.SlowEffects
                }

                Component {
                    id: connectLoadingComp

                    LoadingIndicator {
                        implicitSize: Math.round(Tokens.font.body.medium.pointSize * 1.4)
                        color: connectBtn.onColour
                    }
                }

                Component {
                    id: connectTextComp

                    StyledText {
                        text: connectMetrics.text
                        font: connectBtn.font
                        color: connectBtn.onColour
                    }
                }
            }
        }
    }
}
