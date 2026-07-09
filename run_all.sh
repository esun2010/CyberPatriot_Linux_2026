#!/usr/bin/env bash

set -uo pipefail

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
  "rm_stuff/rm_mp3+.sh"
  "services/ufw.sh"
  "user_management/user_management.sh"
  "rm_stuff/bad_pkg.sh"
  "rm_stuff/pwd_cracking_search.sh"
)

declare -A RESULTS
FAILED=0

echo "[+] Making all scripts executable..."
for script in "${SCRIPTS[@]}"; do
  if [[ -f "$script" ]]; then
    chmod +x "$script"
  else
    echo "[!] Missing script: $script"
    RESULTS["$script"]="MISSING"
    ((FAILED++))
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

  if "$SCRIPT_DIR/$script"; then
    RESULTS["$script"]="PASS"
    echo
    echo "[+] Finished $script"
  else
    exit_code=$?
    RESULTS["$script"]="FAIL (exit $exit_code)"
    ((FAILED++))
    echo
    echo "[-] $script failed with exit code $exit_code"
  fi

  echo
done

echo "============================================================"
echo "Run summary"
echo "============================================================"
for script in "${SCRIPTS[@]}"; do
  status="${RESULTS[$script]:-NOT RUN}"
  printf '%-45s %s\n' "$script" "$status"
done

echo
if (( FAILED > 0 )); then
  echo "[-] Completed with $FAILED issue(s)."
  exit 1
else
  echo "[+] All available scripts completed successfully."
fi