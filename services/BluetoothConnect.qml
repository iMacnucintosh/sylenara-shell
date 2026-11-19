pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Sylenara
import Sylenara.I18n

// Connecting a Bluetooth device from a single button. A device that was never paired (a new mouse, headset…)
// cannot just connect: it is paired first, then trusted (so it reconnects by itself next time) and connected.
// scripts/bluetooth-pair.py does it: BlueZ only pairs with an agent that answers its questions, and the helper is
// that agent for the length of the pairing (for that device only), with the adapter pairable meanwhile.
// Devices that ask to type a code (some keyboards) still pair from Settings → Bluetooth.
Singleton {
    id: root

    // The device being paired, by its D-Bus path ("" = none)
    property string pairingPath: ""
    property string pairingName: ""

    function toggle(device: BluetoothDevice): void {
        if (!device)
            return;
        if (device.connected) {
            device.connected = false;
            return;
        }
        if (device.paired) {
            device.connected = true;
            return;
        }
        if (root.pairingPath !== "" || device.pairing)
            return;
        root.pairingPath = device.dbusPath;
        root.pairingName = device.name || device.address;
        pairProc.command = ["python3", "-I", Quickshell.shellPath("scripts/bluetooth-pair.py"), device.dbusPath];
        pairProc.running = true;
    }

    // A device being paired from here (the button shows it as busy)
    function isPairing(device: BluetoothDevice): bool {
        return !!device && (device.pairing || device.dbusPath === root.pairingPath);
    }

    Process {
        id: pairProc

        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: pairErr
        }
        onExited: code => {
            if (code !== 0)
                Toaster.toast(Tr.tr("Could not connect %1").arg(root.pairingName), Tr.tr("Put it in pairing mode and try again. Devices that ask for a code pair from Settings → Bluetooth."), "bluetooth_disabled", Toast.Warning);
            if (code !== 0 && pairErr.text.trim() !== "")
                console.warn(`BluetoothConnect: ${root.pairingName}: ${pairErr.text.trim()}`);
            root.pairingPath = "";
            root.pairingName = "";
        }
    }
}
