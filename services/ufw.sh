#!/bin/bash
#check

set -euo pipefail

# This script installs, configures, and enables UFW (Uncomplicated Firewall) on Linux.

if [[ "$(id -u)" -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

echo "Updating package list..."
apt update -y

echo "Installing UFW..."
apt install -y ufw

if ! command -v ufw &> /dev/null; then
    echo "UFW installation failed. Exiting script."
    exit 1
fi

echo "Enabling UFW to start on boot..."
systemctl enable ufw

echo "Configuring UFW rules..."

# Allow SSH first to avoid lockouts.
echo "Allowing SSH connections..."
ufw allow ssh

# Allow HTTP and HTTPS only if needed for a web server.
echo "Allowing HTTP and HTTPS traffic..."
ufw allow http
ufw allow https

echo "Setting default policies..."
ufw default deny incoming
ufw default allow outgoing

echo "Enabling UFW..."
ufw --force enable

echo "UFW status:"
ufw status verbose

echo "UFW has been installed, configured, and enabled successfully."