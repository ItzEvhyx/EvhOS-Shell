#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
bash -n "$root/install.sh"
for os in arch fedora nixos; do
  result=$("$root/install.sh" --plan --os "$os")
  [[ $result == *"EvhOS installer: $os"* ]]
done
if "$root/install.sh" --plan --os unsupported >/dev/null 2>&1; then echo 'Unsupported distro must fail' >&2; exit 1; fi
if "$root/install.sh" --plan --os nixos --sddm >/dev/null 2>&1; then echo 'NixOS SDDM path must fail safely' >&2; exit 1; fi
if "$root/install.sh" --os arch --yes >/dev/null 2>&1; then echo 'Forcing the distro outside plan mode must fail' >&2; exit 1; fi
if "$root/install.sh" --bad-option >/dev/null 2>&1; then echo 'Unknown flag must fail' >&2; exit 1; fi
"$root/install.sh" --help >/dev/null
printf 'Installer plan and argument checks passed.\n'
