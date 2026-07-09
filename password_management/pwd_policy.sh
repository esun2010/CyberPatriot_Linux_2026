#!/bin/bash
#check

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

echo "Enforcing strong password policy..."

set_or_append() {
    local file="$1"
    local key="$2"
    local value="$3"

    touch "$file"
    if grep -Eq "^[[:space:]]*${key}\b" "$file"; then
        sed -i "s|^[[:space:]]*${key}.*|${key} ${value}|" "$file"
    else
        echo "${key} ${value}" >> "$file"
    fi
}

set_or_append /etc/login.defs PASS_MAX_DAYS 90
set_or_append /etc/login.defs PASS_MIN_DAYS 1
set_or_append /etc/login.defs PASS_WARN_AGE 7

PWQUALITY_FILE="/etc/security/pwquality.conf"
touch "$PWQUALITY_FILE"
if grep -Eq '^[[:space:]]*minlen\b' "$PWQUALITY_FILE"; then
    sed -i 's/^[[:space:]]*minlen.*/minlen = 12/' "$PWQUALITY_FILE"
else
    echo 'minlen = 12' >> "$PWQUALITY_FILE"
fi

echo "Password policy updated."