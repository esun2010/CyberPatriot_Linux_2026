#!/bin/bash
#check

# This script will disable the guest account, disable SSH root login,
# and ensure that the root account cannot log in via SSH.
# It will also ensure SSHD configuration is properly updated.

# Ensure script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

echo "Starting the process..."

# Step 1: Disable the guest account (assuming the account is called 'guest')
echo "Disabling the guest account..."
sudo usermod -L guest 2>/dev/null
sudo userdel guest 2>/dev/null || true
echo "Guest account disabled (if it existed)."
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

# Create lightdm.conf if it doesn't exist
if [ ! -f "$LIGHTDM_CONF" ]; then
    echo "[SeatDefaults]" | sudo tee "$LIGHTDM_CONF" > /dev/null
fi

# Remove any existing allow-guest lines
sudo sed -i '/allow-guest/d' "$LIGHTDM_CONF"

# Add the secure setting
echo "allow-guest=false" | sudo tee -a "$LIGHTDM_CONF" > /dev/null

echo "[*] Restarting LightDM to apply changes..."
sudo systemctl restart lightdm 2>/dev/null || echo "[-] Could not restart LightDM (you may not be using it)."



# Step 2: Disable SSH root login (recommended for security)
echo "Disabling root login via SSH..."

# Backup the SSH configuration file before making changes
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
echo "Backup of SSH config created at /etc/ssh/sshd_config.bak."

# Update sshd_config to disable root login
sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

# Step 3: Restart the SSH service to apply the changes
echo "Restarting SSH service to apply changes..."
systemctl restart sshd

# Step 4: Verify the changes
echo "Verifying changes..."

# Check if root login is disabled in SSH config
grep -i 'PermitRootLogin' /etc/ssh/sshd_config

# Check if the guest account is locked or deleted
if id "guest" &>/dev/null; then
    echo "The guest account still exists. Please manually delete it if necessary."
else
    echo "The guest account has been disabled or deleted."
fi

echo "Script complete. Root login via SSH has been disabled, and the guest account has been disabled (if it existed)."
