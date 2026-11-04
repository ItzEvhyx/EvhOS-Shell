# Optional NixOS module. Import into your existing NixOS configuration.
# The current snapshot targets a specific Hyprland Lua config and has not
# been verified against every nixpkgs release.
{ config, lib, pkgs, ... }:
let
  required = [ "quickshell" "python3" "git" "jq" "socat" "inotify-tools" "wl-clipboard" "cliphist" "imagemagick" "ffmpeg" "fontconfig" "cmatrix" "pipewire" "wireplumber" ];
  optional = [ "kitty" "cava" "zbar" "tesseract" "pavucontrol" "alsa-utils" "fd" "ripgrep" "pamixer" "brightnessctl" "ddcutil" "acpi" "iw" "bluez" "libnotify" "networkmanager" "lm_sensors" "bc" "matugen" "fastfetch" "unzip" "grim" "playerctl" "satty" "xdg-desktop-portal-gtk" "xdg-desktop-portal-hyprland" "slurp" "wmctrl" "power-profiles-daemon" "easyeffects" "wf-recorder" "gammastep" "fish" "starship" ];
  missing = builtins.filter (name: !(builtins.hasAttr name pkgs)) required;
  available = builtins.filter (name: builtins.hasAttr name pkgs) (required ++ optional);
in {
  assertions = [{ assertion = missing == []; message = "EvhOS: missing nixpkgs attributes: ${lib.concatStringsSep ", " missing}"; }];
  environment.systemPackages = map (name: builtins.getAttr name pkgs) available ++ (with pkgs.qt6; [ qtbase qtdeclarative qtsvg qtwayland qt5compat qtmultimedia qtwebsockets ]);
}
