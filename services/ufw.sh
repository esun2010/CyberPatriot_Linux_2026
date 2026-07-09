#!/bin/bash
#check

# This script installs, configures, and enables UFW (Uncomplicated Firewall) on Linux.

# Update package list and upgrade packages
echo "Updating package list..."
sudo apt update -y && sudo apt upgrade -y

# Install UFW if it's not already installed
echo "Installing UFW..."
sudo apt install ufw -y

# Check if UFW is installed successfully
if ! command -v ufw &> /dev/null
then
    echo "UFW installation failed. Exiting script."
    exit 1
fi

# Enable UFW to start on boot
echo "Enabling UFW to start on boot..."
sudo systemctl enable ufw

# Basic firewall rules configuration
echo "Configuring UFW rules..."

# Allow SSH (important to avoid locking yourself out of the system)
echo "Allowing SSH connections..."
sudo ufw allow ssh

# Allow HTTP and HTTPS (if needed for web servers) can delete if not
echo "Allowing HTTP and HTTPS traffic..."
sudo ufw allow http
sudo ufw allow https

# Set default policies (deny incoming, allow outgoing)
echo "Setting default policies..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Enable UFW
echo "Enabling UFW..."
sudo ufw enable

# Check the UFW status
echo "UFW status:"
sudo ufw status verbose

echo "UFW has been installed, configured, and enabled successfully."
