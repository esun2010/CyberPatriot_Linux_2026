# CyberPatriot Safe Removal Script
# Lets you manually edit a list of dangerous packages before removing them

set -euo pipefail

# List of packages that are usually unsafe
BAD_PACKAGES=(
    nmap
    netcat
    netcat-openbsd
    netcat-traditional
    john
    hydra
    medusa
    ophcrack
    hashcat
    wireshark
    aircrack-ng
    kismet
    telnet
    rsh-server
    xinetd
    tor
    deluge
    transmission
    sqlmap
    nikto
)

echo "==============================================="
echo " CyberPatriot Package Removal Tool"
echo "==============================================="
echo
echo "The following packages are on the removal list:"
echo

for pkg in "${BAD_PACKAGES[@]}"; do
    echo " - $pkg"
done

echo
echo "👉 Edit the list as needed BEFORE removal."
echo "👉 If any package is needed per the README, remove it from the list."
echo

read -p "Do you want to edit the list now? (y/n) " edit_choice

if [[ "$edit_choice" =~ ^[Yy]$ ]]; then
    # Create a temp file
    TEMP_LIST=$(mktemp)

    # Write current list to file
    printf "%s\n" "${BAD_PACKAGES[@]}" > "$TEMP_LIST"

    echo
    echo "Opening list in nano..."
    echo "Remove any packages you DO NOT want uninstalled."
    echo "Save with CTRL+O, exit with CTRL+X."
    sleep 2
    nano "$TEMP_LIST"

    # Load edited list back into array
    mapfile -t BAD_PACKAGES < "$TEMP_LIST"

    echo
    echo "Edited list loaded."
fi

echo "==============================================="
echo " Final package removal list:"
echo "==============================================="

for pkg in "${BAD_PACKAGES[@]}"; do
    echo " - $pkg"
done

echo
read -p "Proceed with removal? (y/n) " choice
echo

if [[ "$choice" =~ ^[Yy]$ ]]; then
    echo "[+] Removing packages..."
    for pkg in "${BAD_PACKAGES[@]}"; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            echo "Removing: $pkg"
            apt purge -y "$pkg"
        else
            echo "Not installed: $pkg"
        fi
    done
    apt autoremove -y
    echo "[+] Package removal complete."
else
    echo "[-] Aborted. No packages were removed."
fi

exit 0
