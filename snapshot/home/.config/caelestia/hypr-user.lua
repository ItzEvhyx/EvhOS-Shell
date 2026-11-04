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
hl.layer_rule({ name = "serp-glass-tray-menu", match = { namespace = "^traymenu$" }, blur = true, ignore_alpha = 0.05 })
hl.layer_rule({ name = "serp-glass-osd", match = { namespace = "^osd$" }, blur = true, ignore_alpha = 0.05 })
hl.layer_rule({ name = "serp-glass-launcher", match = { namespace = "^qs-applauncher$" }, blur = true, ignore_alpha = 0.05 })

-- Make Flatpak application entries and icons available to the desktop shell.
hl.env("XDG_DATA_DIRS", os.getenv("HOME") .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share")
