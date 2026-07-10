#!/usr/bin/env bash

set -uo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# key -> script path
declare -A SCRIPT_MAP=(
    [k]="misc/kernel.sh"
    [l]="misc/login.sh"
    [p]="password_management/pwd_policy.sh"
    [u]="user_management/user_management.sh"
    [a]="password_management/reset_admin_pwd.sh"
    [m]="rm_stuff/rm_mp3+.sh"
    [f]="services/ufw.sh"
    [b]="rm_stuff/bad_pkg.sh"
    [c]="rm_stuff/pwd_cracking_search.sh"
)

# Optional descriptions
declare -A DESCRIPTIONS=(
    [k]="Kernel settings"
    [l]="Login settings"
    [p]="Password policy"
    [u]="User management"
    [a]="Reset admin password"
    [m]="Remove MP3 files"
    [f]="Configure UFW"
    [b]="Remove bad packages"
    [c]="Password cracker search"
)

echo "Available scripts:"
echo "----------------------------"
for key in "${!SCRIPT_MAP[@]}"; do
    printf " %-2s -> %-40s (%s)\n" \
        "$key" "${SCRIPT_MAP[$key]}" "${DESCRIPTIONS[$key]}"
done | sort

echo
read -rp "Enter keys to run (space-separated) or 'all': " -a CHOICES

SCRIPTS=()

if [[ ${#CHOICES[@]} -eq 1 && ${CHOICES[0]} == "all" ]]; then
    for key in "${!SCRIPT_MAP[@]}"; do
        SCRIPTS+=("${SCRIPT_MAP[$key]}")
    done
else
    for key in "${CHOICES[@]}"; do
        if [[ -v SCRIPT_MAP[$key] ]]; then
            SCRIPTS+=("${SCRIPT_MAP[$key]}")
        else
            echo "[!] Unknown key: $key"
        fi
    done
fi

declare -A RESULTS
FAILED=0

echo
echo "[+] Making selected scripts executable..."
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
    [[ -f "$script" ]] || continue

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
    printf '%-45s %s\n' "$script" "${RESULTS[$script]:-NOT RUN}"
done

echo
if (( FAILED > 0 )); then
    echo "[-] Completed with $FAILED issue(s)."
    exit 1
else
    echo "[+] All selected scripts completed successfully."
fi