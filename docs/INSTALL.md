# Installing EvhOS

The installer assumes you already have a working Hyprland installation and have cloned this private repo. Sign in to GitHub to clone it. Review scripts before executing them. These installers and module have not yet been tested on clean machines; first try them on a VM or spare user. The snapshot was captured on Hyprland 0.57.0 and `noctalia-qs` 0.0.12; compatibility with other versions or the stock Quickshell fork is not established.

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

## SDDM and recovery

First preview the included login theme:

```sh
sddm-greeter-qt6 --test-mode --theme "$PWD/snapshot/system/sddm-theme"
```

On mutable Arch or Fedora systems with SDDM already installed, `./install.sh --enable-services --sddm` also installs the theme under `/usr/share/sddm/themes/evhos-torii` and creates `/etc/sddm.conf.d/zzzzzzz-evhos.conf`; an existing file with that exact name and any existing `evhos-torii` theme are backed up. This does not enable or restart SDDM and does not validate real authentication. Other SDDM settings, including `/etc/sddm.conf`, may take precedence. On NixOS install and select the theme declaratively instead; do not use `--sddm` against its read-only system paths.

Existing user files are backed up under `~/.local/state/evhos-backups/`. Keep a separate working graphical session and a TTY recovery route. Review `~/.config/hypr/` and the included user services; the 30-second customization timer can reapply patches to shell files. The wallpaper and widget state reference `eDP-1`; adjust for other output names. Calendar, clipboard, notes and credentials are excluded from the snapshot.
