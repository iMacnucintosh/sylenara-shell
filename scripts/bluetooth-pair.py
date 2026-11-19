#!/usr/bin/env python3
"""Pair a Bluetooth device, trust it and connect it, answering BlueZ's questions for that device only.

    bluetooth-pair.py /org/bluez/hci0/dev_XX_XX_XX_XX_XX_XX

BlueZ asks an agent to confirm a pairing; without one it refuses ("No agent available"). For the length of the
pairing this registers a "no input, no output" agent (what mice, headsets and speakers use: nothing to type) that
accepts the requests of the device being paired and rejects any other. The adapter must be pairable meanwhile:
it is turned on and put back as it was. Exit 0 when paired and connected; 1 with the reason on stderr; 2 usage.
"""
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

BLUEZ = "org.bluez"
AGENT_PATH = "/org/sylenara/bluetooth/agent"
TIMEOUT_MS = 45_000
AGENT_XML = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
    <method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
    <method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
    <method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
    <method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
    <method name="RequestAuthorization"><arg type="o" direction="in"/></method>
    <method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
    <method name="Cancel"/>
  </interface>
</node>
"""


def main() -> int:
    if len(sys.argv) != 2 or not sys.argv[1].startswith("/org/bluez/"):
        print("usage: bluetooth-pair.py <device object path>", file=sys.stderr)
        return 2
    device = sys.argv[1]
    adapter = device.rsplit("/", 1)[0]
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
    loop = GLib.MainLoop()
    result = {"code": 1, "error": "timed out"}

    def call(path, iface, method, args=None, reply=None):
        return bus.call_sync(BLUEZ, path, iface, method, args, reply, Gio.DBusCallFlags.NONE, -1, None)

    def get(path, iface, prop):
        return call(path, "org.freedesktop.DBus.Properties", "Get", GLib.Variant("(ss)", (iface, prop)),
                    GLib.VariantType("(v)")).unpack()[0]

    def set_(path, iface, prop, value):
        call(path, "org.freedesktop.DBus.Properties", "Set", GLib.Variant("(ssv)", (iface, prop, value)))

    def on_agent_call(_conn, _sender, _path, _iface, method, params, invocation):
        target = params.unpack()[0] if params.n_children() else None
        if method in ("Release", "Cancel", "DisplayPinCode", "DisplayPasskey"):
            invocation.return_value(None)
        elif method in ("RequestConfirmation", "RequestAuthorization", "AuthorizeService") and target == device:
            invocation.return_value(None)  # the device the user asked to pair: accept
        else:
            invocation.return_dbus_error("org.bluez.Error.Rejected", "Only the device being paired is accepted")

    node = Gio.DBusNodeInfo.new_for_xml(AGENT_XML)
    reg_id = bus.register_object(AGENT_PATH, node.interfaces[0], on_agent_call, None, None)
    restore_pairable = False
    try:
        call("/org/bluez", "org.bluez.AgentManager1", "RegisterAgent", GLib.Variant("(os)", (AGENT_PATH, "NoInputNoOutput")))
        call("/org/bluez", "org.bluez.AgentManager1", "RequestDefaultAgent", GLib.Variant("(o)", (AGENT_PATH,)))
        if not get(adapter, "org.bluez.Adapter1", "Pairable"):
            set_(adapter, "org.bluez.Adapter1", "Pairable", GLib.Variant("b", True))
            restore_pairable = True

        def finish(code, error=None):
            result["code"], result["error"] = code, error
            loop.quit()

        def connected(_bus, res):
            try:
                bus.call_finish(res)
                finish(0)
            except GLib.Error as e:
                finish(1, f"paired, but did not connect: {e.message}")

        def trust_and_connect():
            set_(device, "org.bluez.Device1", "Trusted", GLib.Variant("b", True))
            bus.call(BLUEZ, device, "org.bluez.Device1", "Connect", None, None, Gio.DBusCallFlags.NONE, 20_000,
                     None, connected)

        def paired(_bus, res):
            try:
                bus.call_finish(res)
            except GLib.Error as e:
                return finish(1, e.message)
            trust_and_connect()

        if get(device, "org.bluez.Device1", "Paired"):
            trust_and_connect()
        else:
            bus.call(BLUEZ, device, "org.bluez.Device1", "Pair", None, None, Gio.DBusCallFlags.NONE, TIMEOUT_MS,
                     None, paired)
        GLib.timeout_add(TIMEOUT_MS + 25_000, loop.quit)
        loop.run()
    except GLib.Error as e:
        result["code"], result["error"] = 1, e.message
    finally:
        try:
            call("/org/bluez", "org.bluez.AgentManager1", "UnregisterAgent", GLib.Variant("(o)", (AGENT_PATH,)))
        except GLib.Error:
            pass
        if restore_pairable:
            try:
                set_(adapter, "org.bluez.Adapter1", "Pairable", GLib.Variant("b", False))
            except GLib.Error:
                pass
        bus.unregister_object(reg_id)
    if result["code"]:
        print(result["error"], file=sys.stderr)
    return result["code"]


if __name__ == "__main__":
    sys.exit(main())
