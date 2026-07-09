#!/usr/bin/env bash

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SCRIPTS=(
  "misc/kernel.sh"
  "misc/login.sh"
  "password_management/pwd_policy.sh"
  "password_management/reset_admin_pwd.sh"
  "rm_stuff/bad_pkg.sh"
  "rm_stuff/pwd_cracking_search.sh"
  "rm_stuff/rm_mp3+.sh"
  "services/ufw.sh"
  "user_management/user_management.sh"
)

echo "[+] Making all scripts executable..."
for script in "${SCRIPTS[@]}"; do
  if [[ -f "$script" ]]; then
    chmod +x "$script"
  else
    echo "[!] Missing script: $script"
  fi
done

echo
for script in "${SCRIPTS[@]}"; do
  if [[ ! -f "$script" ]]; then
    echo "[!] Skipping missing script: $script"
    continue
  fi

  echo "============================================================"
  echo "[+] Running $script"
  echo "============================================================"

  "$SCRIPT_DIR/$script"
  echo
  echo "[+] Finished $script"
  echo
done

echo "[+] All available scripts have completed."