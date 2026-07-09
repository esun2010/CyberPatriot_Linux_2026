#!/bin/bash
#check

# This script disables the guest account, disables SSH root login,
# and ensures SSHD configuration is properly updated.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

echo "Starting the process..."

# Step 1: Disable the guest account (if present)
echo "Disabling the guest account..."
usermod -L guest 2>/dev/null || true
userdel guest 2>/dev/null || true
echo "Guest account disabled (if it existed)."

LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

# Create lightdm.conf if it doesn't exist
if [[ ! -f "$LIGHTDM_CONF" ]]; then
    printf '[SeatDefaults]\n' > "$LIGHTDM_CONF"
fi

# Remove any existing allow-guest lines and add secure setting once
sed -i '/^allow-guest=/d' "$LIGHTDM_CONF"
echo "allow-guest=false" >> "$LIGHTDM_CONF"

echo "[*] Restarting LightDM to apply changes..."
systemctl restart lightdm 2>/dev/null || echo "[-] Could not restart LightDM (you may not be using it)."

# Step 2: Disable SSH root login
echo "Disabling root login via SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_BACKUP="/etc/ssh/sshd_config.bak"

if [[ -f "$SSHD_CONFIG" ]]; then
    cp "$SSHD_CONFIG" "$SSHD_BACKUP"
    echo "Backup of SSH config created at $SSHD_BACKUP."

    if grep -Eq '^[[:space:]]*PermitRootLogin\b' "$SSHD_CONFIG"; then
        sed -i 's/^[[:space:]]*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    else
        echo 'PermitRootLogin no' >> "$SSHD_CONFIG"
    fi

    echo "Restarting SSH service to apply the changes..."
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || \
        echo "[-] Could not restart ssh/sshd automatically."

    echo "Verifying changes..."
    grep -i 'PermitRootLogin' "$SSHD_CONFIG" || true
else
    echo "[-] $SSHD_CONFIG not found; skipping SSH root login hardening."
fi

# Check if the guest account is locked or deleted
if id guest &>/dev/null; then
    echo "The guest account still exists. Please manually delete it if necessary."
else
    echo "The guest account has been disabled or deleted."
fi

echo "Script complete. Root login via SSH has been disabled, and the guest account has been disabled (if it existed)."