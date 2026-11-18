#!/usr/bin/env bash
# EvhOS bootstrap: package installation is separate from user-file restoration.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mode=run; enable_services=0; install_sddm=0; assume_yes=0; simulated_os=""
usage() {
  cat <<'HELP'
Usage: ./install.sh [--plan] [--yes] [--enable-services] [--sddm]
  --plan             Show the plan without installing or modifying anything.
  --yes              Skip the installer's confirmation (package manager may still prompt).
  --enable-services  Enable EvhOS user services after restoring (systemd user session needed).
  --sddm             Install the Obsidian Frame theme for SDDM using sudo.
  --os FAMILY        With --plan only: simulate arch, fedora, nixos, or unsupported.
  --help             Show this help.
Run as the desktop user, not root. Hyprland should already be installed.
HELP
}
while (($#)); do
  case "$1" in
    --plan|--dry-run) mode=plan;; --yes) assume_yes=1;; --enable-services) enable_services=1;;
    --sddm) install_sddm=1;; --os) shift; (($#)) || { echo 'Missing value for --os' >&2; exit 2; }; simulated_os=$1;;
    --help|-h) usage; exit 0;; *) echo "Unknown argument: $1" >&2; exit 2;;
  esac; shift
done
[[ -z $simulated_os || $mode == plan ]] || { echo '--os is available only with --plan.' >&2; exit 2; }
[[ $EUID -ne 0 ]] || { echo 'Run as your desktop user, not root.' >&2; exit 1; }
[[ -f "$ROOT/restore.py" && -f "$ROOT/snapshot/shell/src/quickshell/Shell.qml" ]] || { echo 'Repository snapshot is incomplete.' >&2; exit 1; }
family=unsupported
if [[ -n $simulated_os ]]; then family=$simulated_os
elif [[ -r /etc/os-release ]]; then
  # os-release is a system-owned shell-compatible file.
  . /etc/os-release
  case " ${ID:-} ${ID_LIKE:-} " in
    *' nixos '*) family=nixos;;
    *' fedora '*) family=fedora;;
    *' arch '*) family=arch;;
  esac
fi
arch_core=(python python-pillow cmake gcc make xdg-utils git quickshell qt6-base qt6-declarative qt6-svg qt6-wayland qt6-5compat qt6-multimedia qt6-websockets pipewire pipewire-pulse wireplumber jq socat inotify-tools wl-clipboard cliphist imagemagick ffmpeg fontconfig cmatrix)
arch_optional=(kitty foot cava zbar tesseract tesseract-data-eng pavucontrol alsa-utils fd ripgrep pamixer brightnessctl ddcutil acpi iw bluez bluez-utils libnotify networkmanager lm_sensors bc matugen pipewire-alsa libpulse wget file psmisc fastfetch unzip python-websockets python-jeepney python-dbus grim playerctl satty xdg-desktop-portal-gtk xdg-desktop-portal-hyprland slurp wmctrl power-profiles-daemon easyeffects calf lsp-plugins-lv2 qt5-wayland qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects qt6ct adwaita-icon-theme gpu-screen-recorder wf-recorder adw-gtk-theme wl-gammarelay-rs gammastep fish starship)
fedora_core=(python3 python3-pillow cmake gcc-c++ make qt6-qtdeclarative-devel xdg-utils git quickshell qt6-qtbase qt6-qtdeclarative qt6-qtsvg qt6-qtwayland qt6-qt5compat qt6-qtmultimedia qt6-qtwebsockets pipewire pipewire-pulseaudio wireplumber jq socat inotify-tools wl-clipboard cliphist ImageMagick ffmpeg-free fontconfig cmatrix)
fedora_optional=(kitty foot cava zbar tesseract tesseract-langpack-eng pavucontrol alsa-utils fd-find ripgrep pamixer brightnessctl ddcutil acpi iw bluez libnotify NetworkManager lm_sensors bc matugen pipewire-alsa pulseaudio-libs wget file psmisc fastfetch unzip python3-websockets python3-jeepney python3-dbus grim playerctl satty xdg-desktop-portal-gtk xdg-desktop-portal-hyprland slurp wmctrl ppd-service easyeffects calf-plugins qt6ct adwaita-icon-theme wf-recorder adw-gtk3-theme gammastep fish starship)
case "$family" in
  arch) manager=pacman; core=("${arch_core[@]}"); optional=("${arch_optional[@]}");;
  fedora) manager=dnf; core=("${fedora_core[@]}"); optional=("${fedora_optional[@]}");;
  nixos) manager=nix; core=(); optional=();;
  *) echo "Unsupported distribution: ${simulated_os:-${ID:-unknown}}. See docs/INSTALL.md." >&2; exit 2;;
esac
printf 'EvhOS installer: %s\n' "$family"
printf 'Target home: %s\n' "$HOME"
printf 'Included: customized shell, Hyprland config, icon packs, appearance state and a local rich notepad build.\n'
printf 'Existing replaced files are backed up by restore.py.\n'
printf 'Hyprland must already be installed; its Lua config is version-sensitive.\n'
if [[ $family == nixos ]]; then
  if (( install_sddm )); then echo "On NixOS configure SDDM declaratively; --sddm is unavailable." >&2; exit 2; fi
  echo 'NixOS: import nix/evhos-dependencies.nix into your system configuration, rebuild, then run ./install.sh again.'
  echo 'See docs/INSTALL.md; automatic imperative NixOS package installation is intentionally not used.'
  if [[ $mode == plan ]]; then exit 0; fi
  for cmd in python3 quickshell Hyprland; do command -v "$cmd" >/dev/null || { echo "Missing $cmd. Complete the NixOS dependency setup first." >&2; exit 1; }; done
else
  printf 'Core packages: %s\n' "${core[*]}"
  printf 'Optional integrations (unavailable packages will be reported): %s\n' "${optional[*]}"
  echo 'No external repositories or AUR helpers are enabled automatically.'
fi
printf 'Enable user services: %s; install SDDM theme: %s\n' "$enable_services" "$install_sddm"
[[ $mode != plan ]] || exit 0
command -v Hyprland >/dev/null || { echo 'Install Hyprland before running EvhOS.' >&2; exit 1; }
if (( install_sddm )) && ! command -v sddm >/dev/null; then echo "SDDM is not installed; install it before using --sddm." >&2; exit 1; fi
if (( ! assume_yes )); then read -r -p 'Install packages and restore the snapshot? [y/N] ' answer; [[ $answer == [yY] || $answer == [yY][eE][sS] ]] || { echo 'Cancelled.'; exit 1; }; fi
if [[ $family != nixos ]]; then
  command -v "$manager" >/dev/null || { echo "Missing package manager: $manager" >&2; exit 1; }
  available=(); missing_core=(); missing_optional=()
  for pkg in "${core[@]}" "${optional[@]}"; do
    # Do not replace an installed provider such as noctalia-qs with stock quickshell.
    if [[ $family == arch ]] && pacman -T "$pkg" >/dev/null 2>&1; then continue; fi
    if [[ $family == fedora ]] && rpm -q --whatprovides "$pkg" >/dev/null 2>&1; then continue; fi
    found=0
    if [[ $family == arch ]]; then pacman -Si "$pkg" >/dev/null 2>&1 && found=1; pacman -Q "$pkg" >/dev/null 2>&1 && found=1
    else dnf -q repoquery --available "$pkg" 2>/dev/null | grep -q . && found=1; rpm -q "$pkg" >/dev/null 2>&1 && found=1; fi
    if (( found )); then available+=("$pkg"); elif [[ " ${core[*]} " == *" $pkg "* ]]; then missing_core+=("$pkg"); else missing_optional+=("$pkg"); fi
  done
  if ((${#missing_core[@]})); then printf 'Required packages not found in enabled repositories: %s\n' "${missing_core[*]}" >&2; echo 'Install or enable their trusted package sources, then rerun. No files restored.' >&2; exit 1; fi
  if ((${#missing_optional[@]})); then printf 'Optional packages unavailable: %s\n' "${missing_optional[*]}"; echo 'Related features may require manual setup.'; fi
  if ((${#available[@]})); then
    if [[ $family == arch ]]; then sudo pacman -S --needed "${available[@]}"; else sudo dnf install "${available[@]}"; fi
  else echo "All requested repository packages are already present."; fi
fi
for cmd in python3 quickshell; do command -v "$cmd" >/dev/null || { echo "Required executable missing after install: $cmd" >&2; exit 1; }; done
python3 "$ROOT/restore.py" --apply --build-rich-notes
if command -v fc-cache >/dev/null; then fc-cache -f "$HOME/.local/share/fonts" 2>/dev/null || true; fi
if (( enable_services )); then
  if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user daemon-reload
    systemctl --user enable --now serp-bar-auto.service serp-customizations.timer charger-notifications.service low-battery-alarm.service full-charge-alarm.service serpantinum-calendar-reminder.timer
  else echo 'User systemd is unavailable: enable the included services manually after login.' >&2; fi
fi
if (( install_sddm )); then
  command -v sddm >/dev/null || { echo 'SDDM is not installed; install it before using --sddm.' >&2; exit 1; }
  theme=evhos-obsidian-frame
  destination="/usr/share/sddm/themes/$theme"
  sudo install -d -m 755 /usr/share/sddm/themes /etc/sddm.conf.d
  if sudo test -e "$destination"; then
    suffix=$(date +%Y%m%d%H%M%S)
    sudo cp -a "$destination" "$destination-backup-$suffix"
  fi
  sudo install -d -m 755 "$destination"
  sudo cp -a "$ROOT/snapshot/system/sddm-obsidian-frame/." "$destination/"
  sudo chmod -R a+rX "$destination"
  if sudo test -e /etc/sddm.conf.d/zzzzzzz-evhos.conf; then
    suffix=$(date +%Y%m%d%H%M%S); sudo cp -p /etc/sddm.conf.d/zzzzzzz-evhos.conf "/etc/sddm.conf.d/zzzzzzz-evhos.conf.backup-$suffix"
  fi
  printf '[Theme]\nCurrent=%s\n' "$theme" | sudo tee /etc/sddm.conf.d/zzzzzzz-evhos.conf >/dev/null
  if [[ -r /etc/sddm.conf ]] && grep -Eq '^[[:space:]]*Current[[:space:]]*=' /etc/sddm.conf; then
    echo 'Review Current in /etc/sddm.conf, which can override the new SDDM theme drop-in.'
  fi
  echo 'SDDM theme installed. Review docs/INSTALL.md before logging out.'
fi
echo 'EvhOS files restored. Review docs/INSTALL.md, monitor names, session compatibility, and missing integrations before logging out.'
