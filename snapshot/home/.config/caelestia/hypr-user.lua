hl.unbind("SUPER + SHIFT + S")

hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))

-- Keep tiled windows flush with the screen edges.
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })

hl.window_rule({
    name = "flush-tiled-windows",
    match = { float = false },
    rounding = 0,
    border_size = 0,
})

-- Keep focus visible without adding a border around tiled windows.
hl.config({ decoration = { dim_inactive = true, dim_strength = 0.12 } })

-- Switch between shells
hl.unbind("SUPER + SHIFT + 1")
hl.unbind("SUPER + SHIFT + 2")
hl.bind("SUPER + SHIFT + 1", hl.dsp.exec_cmd("switch-shell serpantinum"))
hl.bind("SUPER + SHIFT + 2", hl.dsp.exec_cmd("switch-shell caelestia"))

hl.bind(
  "SUPER + SUPER_L",
  hl.dsp.exec_cmd("pgrep -f '[s]erpantinumd' >/dev/null && serpantinum msg toggle launcher"),
  { release = true }
)

hl.bind(
  "SUPER + N",
  hl.dsp.exec_cmd("pgrep -f '[s]erpantinumd' >/dev/null && serpantinum msg toggle system")
)



-- Brightness keys under Serpantinum (skipped while Caelestia is running)
hl.bind("XF86MonBrightnessDown",
  hl.dsp.exec_cmd("pgrep -f '[s]erpantinumd' >/dev/null && serpantinum brightness lower"),
  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",
  hl.dsp.exec_cmd("pgrep -f '[s]erpantinumd' >/dev/null && serpantinum brightness raise"),
  { locked = true, repeating = true })

-- Blur the translucent Serpantinum dock and bar, without blurring the rest of the shell.
hl.layer_rule({ name = "serp-glass-bar", match = { namespace = "^qs-custom-bar$" }, blur = true, ignore_alpha = 0.05 })
hl.layer_rule({ name = "serp-glass-dock", match = { namespace = "^qs-dock$" }, blur = true, ignore_alpha = 0.05 })
hl.layer_rule({ name = "serp-glass-widgets", match = { namespace = "^qs-master$" }, blur = true, ignore_alpha = 0.05 })
hl.layer_rule({ name = "serp-glass-process-desk", match = { namespace = "^evhos-process-desk$" }, blur = true, ignore_alpha = 0.05 })
hl.layer_rule({ name = "serp-glass-tray-menu", match = { namespace = "^traymenu$" }, blur = true, ignore_alpha = 0.05 })
hl.layer_rule({ name = "serp-glass-osd", match = { namespace = "^osd$" }, blur = true, ignore_alpha = 0.05 })
hl.layer_rule({ name = "serp-glass-launcher", match = { namespace = "^qs-applauncher$" }, blur = true, ignore_alpha = 0.05 })

-- Make Flatpak application entries and icons available to the desktop shell.
hl.env("XDG_DATA_DIRS", os.getenv("HOME") .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share")

-- Give HyprMod the same floating glass treatment as the shell settings.
hl.window_rule({
    name = "hyprmod-glass",
    match = { class = "^io\\.github\\.bluemancz\\.hyprmod$" },
    float = true,
    size = "1200 750",
    center = true,
    rounding = 20,
    opacity = "1.0 override",
})

-- Replacement shortcuts for the 1 and 2 keys
hl.bind("ALT + Q", hl.dsp.send_shortcut({ mods = "", key = "1" }))
hl.bind("ALT + W", hl.dsp.send_shortcut({ mods = "", key = "2" }))
hl.bind("SHIFT + Q", hl.dsp.send_shortcut({ mods = "SHIFT", key = "1" }))
hl.bind("SHIFT + W", hl.dsp.send_shortcut({ mods = "SHIFT", key = "2" }))

-- Workspace overview keyboard shortcut
hl.unbind("SUPER + S")
hl.unbind("SUPER + W")
hl.bind("SUPER + W", hl.dsp.exec_cmd("qs -p /home/yhvhan/.local/share/serpantinum/src/quickshell/Shell.qml ipc call workspaceOverview toggle"))

-- Live backdrop for the workspace overview.
hl.layer_rule({
    name = "serp-workspace-overview-backdrop",
    match = { namespace = "^serpantinum-workspace-overview$" },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
    no_anim = true,
})

-- Serpantinum settings: Super+I
hl.unbind("SUPER + I")
hl.bind("SUPER + I", hl.dsp.exec_cmd("serpantinum settings"))

-- Wallpaper selector: Super+S
hl.unbind("SUPER + S")
hl.bind("SUPER + S", hl.dsp.exec_cmd("quickshell -p /home/yhvhan/.local/share/serpantinum/src/quickshell/Shell.qml ipc call main handleCommand toggle wallpaper \"\""))

-- Super + arrow workspace switching
hl.unbind("SUPER + Left")
hl.unbind("SUPER + Right")
hl.bind("SUPER + Left", hl.dsp.focus({ workspace = "-1" }))
hl.bind("SUPER + Right", hl.dsp.focus({ workspace = "+1" }))
