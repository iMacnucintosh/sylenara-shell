-- Compositor del greeter: alberga el greeter Quickshell Material You.
-- El boot del día va por [initial_session] (autologin), así que esto solo
-- corre tras un logout. Al cerrar qs, el compositor sale para que greetd
-- lance la sesión de usuario.
--
-- HOME/XDG: el usuario greeter tiene HOME=/ en passwd; su carpeta es /var/lib/sylenara-greeter (la crea
-- /etc/tmpfiles.d/sylenara-greeter.conf, que instala scripts/system/10-greeter.sh).

hl.env("SYLENARA_GREETER_DIR", "/etc/greetd/sylenara")
hl.env("HOME", "/var/lib/sylenara-greeter")
hl.env("XDG_CACHE_HOME", "/var/lib/sylenara-greeter/cache")
hl.env("XDG_CONFIG_HOME", "/var/lib/sylenara-greeter/config")
hl.env("XDG_STATE_HOME", "/var/lib/sylenara-greeter/state")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "")
hl.env("GDK_DEBUG", "no-portals")
-- Match the system keyboard (the greeter user has no ~/.config/hypr): start-greeter-compositor.sh reads it from
-- the system (localectl / vconsole.conf) into XKB_DEFAULT_LAYOUT; "us" if it could not.
local layout = os.getenv("XKB_DEFAULT_LAYOUT")
if layout == nil or layout == "" then
  layout = "us"
end
hl.env("XKB_DEFAULT_LAYOUT", layout)
hl.env("XKB_DEFAULT_VARIANT", "")

hl.on("hyprland.start", function()
  hl.exec_cmd("/etc/greetd/sylenara/launch-qs.sh; exec /etc/greetd/sylenara/exit-compositor.sh")
end)

hl.config({
  input = {
    kb_layout = layout,
    kb_variant = "",
    kb_options = "",
  },
  debug = {
    enable_stdout_logs = false,
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_hyprland_guiutils_check = true,
    -- Solid black after qs exits — shortens the VT flash before the user session.
    background_color = 0xff000000,
    force_default_wallpaper = 0,
  },
})
