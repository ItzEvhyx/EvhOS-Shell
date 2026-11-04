# EvhOS Shell

A private, point-in-time snapshot of the EvhOS desktop as used on CachyOS: a customized Serpantinum 2.3.1 Quickshell shell, Hyprland configuration, local helpers and services, appearance state, wallpapers, and the Torii SDDM theme. It is based on [Serpantinum](https://github.com/ilyamiro/serpantinum), by ilyamiro, distributed under AGPL-3.0; see `LICENSE`. This is a personal fork/snapshot, not a new Linux distribution.

## Before restoring

- Install a compatible Hyprland, Quickshell with Qt 6, Python 3, and a working Wayland session first. The Hyprland configuration here uses its Lua configuration API, which is version-sensitive. Match the original versions where possible; see `docs/COMPATIBILITY.md`.
- This snapshot was made on one laptop. Monitor names (`eDP-1`), keyboard bindings, hardware, application paths, fonts, and system service locations must be reviewed for the target machine.
- The restore does **not** install packages, activate services, modify SDDM, remove existing files that aren't in the snapshot, or restart your session. It backs up each file it replaces.
- Private runtime data is intentionally excluded: clipboard history, calendars, notes, usage databases, browser/app data and credentials. Sign-ins and integrations need to be configured again.
- Apple SF and TT Commons font files were excluded pending redistribution rights. Install fonts you are licensed to use. The shell's `mtx` font came from CachyOS's `cmatrix` package; install that font on the new system. Third-party assets and fonts in this private snapshot may have separate terms; audit their rights before publishing it.

## Restore to your account

```sh
git clone https://github.com/ItzEvhyx/EvhOS-Shell.git
cd EvhOS-Shell
python3 restore.py              # preview only
python3 restore.py --apply      # backs up and restores to your home
```

The script rewrites the original `/home/yhvhan` prefix in UTF-8 files to the destination home. Existing files are saved in `~/.local/state/evhos-backups/`. Use `python3 restore.py --home /tmp/evhos-test --apply` to test in an empty disposable home. The `serpantinum` and `serpantinumd` commands are linked into `~/.local/bin`, which must be on `PATH`.

After reviewing the restored configuration, optionally enable the user services you want:

```sh
systemctl --user daemon-reload
systemctl --user enable --now serp-bar-auto.service
systemctl --user enable --now serp-customizations.timer
systemctl --user enable --now charger-notifications.service
systemctl --user enable --now low-battery-alarm.service full-charge-alarm.service
```

The customization timer runs restoration scripts and may overwrite later manual changes to their target files. Review those scripts before enabling. Log out and select Hyprland only after confirming that your distribution supports this config. Keep an alternative session and a backup available.

## Login theme

`snapshot/system/sddm-theme/` contains the tested Torii theme, including its wallpaper and portrait. SDDM is system-wide and requires administrator access. This repository does not automatically install or activate it: first test with `sddm-greeter-qt6 --test-mode --theme "$PWD/snapshot/system/sddm-theme"`; then follow your distribution's SDDM theme instructions and preserve the previous theme/configuration. Preview mode doesn't prove real authentication. NixOS users should package and configure the theme declaratively rather than writing into `/usr/share`.

## What may need adjustment

- User-specific widget layouts are saved under the original monitor name `eDP-1`; choose an appropriate output on a new system. The wallpaper snapshot and selection for `eDP-1` are included; select `~/Pictures/Wallpapers/EvhOS-current.png` in the wallpaper picker if your output has a different name.
- The main configuration uses legacy paths named `serpantinum`; those are intentionally retained because the shell and its services depend on them.
- Optional integrations such as Codex usage, media controls, notifications, clipboard shelf, screenshots, location/weather and power controls need their own dependencies and permissions. No access tokens or calendars are included.
- The snapshot hasn't been verified on Fedora, NixOS, or a fresh Arch installation. It is a portable starting point, not a guarantee of identical behavior across distributions. See `docs/COMPATIBILITY.md`.
