# Installing EvhOS

The installer assumes you already have a working Hyprland installation and have cloned this private repo. Sign in to GitHub to clone it. Review scripts before executing them. These installers and module have not yet been tested on clean machines; first try them on a VM or spare user. The snapshot was captured on Hyprland 0.57.2 and `noctalia-qs` 0.0.12; compatibility with other versions or the stock Quickshell fork is not established.

## Arch and CachyOS

```sh
./install.sh --plan
./install.sh --enable-services
```

`--plan` changes nothing. The second command checks which core and optional packages are available in enabled repositories, displays a confirmation and uses pacman with sudo to install missing packages. It preserves an existing provider of `quickshell`, including `noctalia-qs`, rather than replacing it. It then runs the backup-aware restore and enables the included user services. It does not enable third-party repositories or AUR helpers. Unavailable optional dependencies are listed; their features may need manual installation. For missing core dependencies it stops before restoring.

## Fedora

The same commands use `dnf`, and skip/report optional packages not available in the enabled repositories. Some features such as certain screen-recording or color-temperature integrations may require additional packages, and the available Hyprland or Quickshell version may not be compatible with this snapshot. Fedora has not been tested; third-party COPRs are never added by this installer.

## NixOS

Import `nix/evhos-dependencies.nix` into your existing NixOS system configuration and rebuild using your usual `nixos-rebuild` workflow. This is a best-effort module and is not validated against all nixpkgs revisions. It intentionally doesn't enable Hyprland, the display manager, or audio services; configure those in your system as usual. Resolve any missing package attributes for your nixpkgs revision. Once the packages are installed and available in your desktop user's PATH, run:

```sh
./install.sh --plan
./install.sh --enable-services
```

On NixOS the shell script doesn't install system packages imperatively. The home-directory snapshot remains imperative, so it may conflict with files managed by Home Manager: review the preview and adapt the files into your declarative configuration when appropriate.

## Rich notepad and icon packs

The installer builds the rich notepad with CMake, a C++ compiler, and Qt 6.7 or newer with Qt Quick private headers. The headers must match the Qt build that runs Quickshell. To restore directly, run `python3 restore.py --apply --build-rich-notes` with these dependencies available. Rebuild after updating the Quickshell Qt runtime. On NixOS, build in a package or development shell with the same `qt6.qtbase` and `qt6.qtdeclarative` development outputs used by Quickshell.

The restore includes all eight icon packs and their aliases. The shell syncs the chosen pack with the destination's installed applications at startup.

## Optional Ski file manager

The file manager shortcuts use `ski`. Install Ski using its [upstream instructions](https://github.com/ilyamiro/Ski/wiki/Installation). To reproduce the source machine's Recent sorting and theme changes, build the patched version. From the EvhOS repository root, run:

```sh
evhos_root="$PWD"
git clone https://github.com/ilyamiro/Ski.git /tmp/evhos-ski-source
cd /tmp/evhos-ski-source
git checkout 035ecbc914c9542a46708264d4a524422cc23a4a
git apply "$evhos_root/integrations/ski/evhos.patch"
cargo build --release --locked
install -Dm755 target/release/ski "$HOME/.local/bin/ski"
```

Ensure `~/.local/bin` comes before the system binary in your session's `PATH`. Follow Ski's desktop integration instructions if you also use its file chooser or default file-manager registration.

## SDDM and recovery

First preview the included login theme:

```sh
sddm-greeter-qt6 --test-mode --theme "$PWD/snapshot/system/sddm-obsidian-frame"
```

On mutable Arch or Fedora systems with SDDM already installed, `./install.sh --enable-services --sddm` installs the theme under `/usr/share/sddm/themes/evhos-obsidian-frame` and selects it in `/etc/sddm.conf.d/zzzzzzz-evhos.conf`. The installer backs up existing copies of those paths. If `/etc/sddm.conf` already sets `Current` under `[Theme]`, back up that file and set `Current=evhos-obsidian-frame` there too. On NixOS, package and select the theme declaratively. The older Torii theme is still available in `snapshot/system/sddm-theme/`.

Existing user files are backed up under `~/.local/state/evhos-backups/`. Keep a separate working graphical session and a TTY recovery route. Review `~/.config/hypr/` and the included user services; the 30-second customization timer can reapply patches to shell files. The wallpaper and widget state reference `eDP-1`; adjust for other output names. Calendar, clipboard, notes and credentials are excluded from the snapshot.

## Verification before restoring

Run `python3 tools/run-checks.py` after installing Python Pillow, FFmpeg and Lua 5.4. The installer now requires Pillow (`python-pillow` on Arch, `python3-pillow` on Fedora) and `xdg-utils`; the Nix module supplies a Python environment with Pillow. Restoration checks snapshot hashes and wallpaper references before copying files. Review `snapshot/metadata.json` for the source versions and captured media. Images go in `~/Pictures/Wallpapers/Pictures/`, and live wallpapers in `~/Pictures/Wallpapers/Videos/`.

## Optional Obsidian GRUB menu

Install this theme on a machine already using GRUB. On Arch or CachyOS, copy `snapshot/system/grub-obsidian/` to `/boot/grub/themes/evhos-obsidian/` and back up `/etc/default/grub` before setting `GRUB_THEME="/boot/grub/themes/evhos-obsidian/theme.txt"` there. Keep the destination's working graphics mode initially. Use `1920x1080,auto` only if the destination firmware supports that mode and it fits the display. Regenerate the existing GRUB configuration with `sudo grub-mkconfig -o /boot/grub/grub.cfg` and validate it with `sudo grub-script-check /boot/grub/grub.cfg` before rebooting. Use the distro's documented configuration path on other systems, or the declarative bootloader settings on NixOS. To revert, restore the backed-up defaults and regenerate the configuration.

## Optional EvhOs boot animation

The complete live Plymouth theme (script, dotted background and 112 intro frames) is in `snapshot/system/plymouth-theme/`. Home restoration and the default installer do not change the boot process. On a mutable Arch/CachyOS or Fedora machine that already boots correctly with Plymouth, install the theme separately:

```sh
# From the repository root; keep any existing EvhOs theme as a backup.
if sudo test -e /usr/share/plymouth/themes/evhos; then
  sudo cp -a /usr/share/plymouth/themes/evhos "/usr/share/plymouth/themes/evhos.backup-$(date +%Y%m%d-%H%M%S)"
fi
sudo install -d -m 755 /usr/share/plymouth/themes/evhos
sudo cp -a snapshot/system/plymouth-theme/. /usr/share/plymouth/themes/evhos/
sudo chmod -R a+rX /usr/share/plymouth/themes/evhos
plymouth-set-default-theme   # record your current theme for recovery
sudo plymouth-set-default-theme evhos
```

Rebuild the initramfs using the tool already configured on that machine: `sudo mkinitcpio -P` for mkinitcpio-based Arch/CachyOS, or `sudo dracut --regenerate-all --force` for dracut-based installations. Check that the rebuild succeeds before rebooting. A machine without Plymouth also needs distro-specific Plymouth installation, initramfs integration and boot parameters; this snapshot does not overwrite those hardware-specific settings. To revert, select the recorded previous theme and rebuild the initramfs again. On NixOS package the included theme and configure `boot.plymouth` declaratively.

The theme is captured from the source machine; a fresh boot installation has not been tested. The font shapes are baked into the included PNG frames, so the animation needs no separately installed Orbitron font.
