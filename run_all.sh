#!/usr/bin/env bash

set -uo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ------------------------------------------------------------
# Execution order
# ------------------------------------------------------------
ORDER=(
    ker
    log
    pol
    usr
    adm
    mp3
    ufw
    pkg
    cra
)

# ------------------------------------------------------------
# Keyword -> Script
# ------------------------------------------------------------
declare -A SCRIPT_MAP=(
    [ker]="misc/kernel.sh"
    [log]="misc/login.sh"
    [pol]="password_management/pwd_policy.sh"
    [usr]="user_management/user_management.sh"
    [adm]="password_management/reset_admin_pwd.sh"
    [mp3]="rm_stuff/rm_mp3+.sh"
    [ufw]="services/ufw.sh"
    [pkg]="rm_stuff/bad_pkg.sh"
    [cra]="rm_stuff/pwd_cracking_search.sh"
)

# ------------------------------------------------------------
# Keyword -> Description
# ------------------------------------------------------------
declare -A DESCRIPTION=(
    [ker]="Kernel settings"
    [log]="Login settings"
    [pol]="Password policy"
    [usr]="User management"
    [adm]="Reset admin password"
    [mp3]="Remove MP3 files"
    [ufw]="Configure UFW"
    [pkg]="Remove bad packages"
    [cra]="Password cracker search"
)

echo "Available scripts:"
echo "------------------------------------------------------------"

for key in "${ORDER[@]}"; do
    printf " %-3s  %-35s %s\n" \
        "$key" \
        "${DESCRIPTION[$key]}" \
        "(${SCRIPT_MAP[$key]})"
done

echo
read -rp "Enter keywords (space-separated) or 'all': " -a INPUT

declare -A SELECTED

if [[ ${#INPUT[@]} -eq 1 && ${INPUT[0]} == "all" ]]; then
    for key in "${ORDER[@]}"; do
        SELECTED["$key"]=1
    done
else
    for key in "${INPUT[@]}"; do
        if [[ -v SCRIPT_MAP[$key] ]]; then
            SELECTED["$key"]=1
        else
            echo "[!] Unknown keyword: $key"
        fi
    done
fi

SCRIPTS=()

# Preserve execution order
for key in "${ORDER[@]}"; do
    if [[ -v SELECTED[$key] ]]; then
        SCRIPTS+=("${SCRIPT_MAP[$key]}")
    fi
done

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
if ((FAILED > 0)); then
    echo "[-] Completed with $FAILED issue(s)."
    exit 1
else
    echo "[+] All selected scripts completed successfully."
fi