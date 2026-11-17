pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Sylenara.Config
import Sylenara.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// The password of a protected network, asked inside its row of the list (NetworkList) when NetworkManager answers
// "secrets required". `connected` when the network became the active one; `cancelled` when the user gives up.
ColumnLayout {
    id: root

    required property var accessPoint
    // The name is kept when the form opens: the scans renew the network objects, and the name is what we compare
    property string ssid
    property bool connecting: false
    property bool failed: false
    property bool done: false
    // A profile was created with a password typed here: it is removed if the form goes away without connecting
    property bool attempted: false

    signal connected
    signal cancelled

    function submit(): void {
        if (root.connecting || !root.accessPoint)
            return;
        if (passwordField.text.length < 8) {
            passwordField.isError = true;
            passwordField.forceActiveFocus();
            return;
        }

        root.failed = false;
        root.connecting = true;
        root.attempted = true;
        attemptTimeout.restart();

        NetworkConnection.connectWithPassword(root.accessPoint, passwordField.text, result => {
            if (root.done)
                return;
            if (result && result.success)
                root.succeed();
            // Nmcli gives up waiting after 4 s although nmcli is still activating the connection (slow handshake
            // or DHCP): its real answer comes afterwards, so this one is not a failure
            else if (result?.error !== "Connection timeout" && root.connecting)
                root.fail();
        });
    }

    // Connected: the row goes back to normal and the list shows the network as connected
    function succeed(): void {
        if (root.done)
            return;
        root.done = true;
        root.connecting = false;
        attemptTimeout.stop();
        root.connected();
    }

    function fail(): void {
        attemptTimeout.stop();
        root.connecting = false;
        root.failed = true;
        passwordField.isError = true;
        passwordField.text = "";
        passwordField.forceActiveFocus();
        // The half-created profile has the wrong password: a retry starts fresh
        if (root.ssid)
            Nmcli.forgetNetwork(root.ssid);
    }

    spacing: Tokens.spacing.small

    Component.onCompleted: {
        root.ssid = root.accessPoint?.ssid ?? "";
        passwordField.forceActiveFocus();
    }

    Component.onDestruction: {
        if (root.attempted && !root.done && root.ssid)
            Nmcli.forgetNetwork(root.ssid);
    }

    // nmcli normally answers within seconds; this only keeps the spinner from staying forever
    Timer {
        id: attemptTimeout

        interval: 60000
        onTriggered: {
            if (root.connecting)
                root.fail();
        }
    }

    // The network became the active one, whatever order the answers of nmcli arrive in
    Connections {
        function onActiveChanged(): void {
            if (root.connecting && Nmcli.active && Nmcli.active.ssid === root.ssid)
                root.succeed();
        }

        target: Nmcli
    }

    StyledTextField {
        id: passwordField

        Layout.fillWidth: true
        enabled: !root.connecting
        placeholderText: Tr.tr("Password")
        leadingIcon: "key"
        echoMode: TextInput.Password
        errorText: root.failed ? Tr.tr("Connection failed — check the password") : Tr.tr("Password must be at least 8 characters")

        onAccepted: root.submit()
        Keys.onEscapePressed: root.cancelled()
    }

    RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: Tokens.spacing.small

        TextButton {
            Layout.fillHeight: true
            isRound: true
            horizontalPadding: Tokens.padding.extraLarge
            type: TextButton.Tonal
            text: Tr.trCtx("Cancel", "button")
            onClicked: root.cancelled()
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
