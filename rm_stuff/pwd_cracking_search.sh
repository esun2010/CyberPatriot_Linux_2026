#!/usr/bin/env bash
# Defensive scan for hardware/software commonly used for password cracking.
# Run as root (sudo) for full visibility.

set -euo pipefail
IFS=$'\n\t'

SUDO_PREFIX=""
if [ "$EUID" -ne 0 ]; then
  SUDO_PREFIX="sudo"
fi

echo
echo "=== Password-cracking device & tool detection - $(date) ==="
echo "Run by: $(whoami)"
echo

# Helper: header
hdr() { printf "\n--- %s ---\n" "$1"; }

# 1) Known cracking binaries / packages detection
hdr "Installed / available cracking tools (command in PATH)"
declare -a tools=(hashcat john johnny oclHashcatoclHashcat rarcrack ocl-devicesoclinfo)
for t in "${tools[@]}"; do
  if command -v "$t" >/dev/null 2>&1; then
    printf "FOUND: %s -> %s\n" "$t" "$(command -v "$t")"
  else
    printf "not found: %s\n" "$t"
  fi
done

hdr "Check package manager (dpkg/rpm) for common packages"
if command -v dpkg >/dev/null 2>&1; then
  $SUDO_PREFIX dpkg -l 2>/dev/null | egrep -i "hashcat|john|ocl|ocl-?hashcat|cuda|rocm|opencl" || true
elif command -v rpm >/dev/null 2>&1; then
  $SUDO_PREFIX rpm -qa | egrep -i "hashcat|john|ocl|cuda|rocm|opencl" || true
else
  echo "No dpkg/rpm found to query packages."
fi

# 2) Running processes relating to cracking tools / high CPU or GPU usage
hdr "Running processes mentioning cracking-tool names or suspicious strings"
ps aux | egrep -i "hashcat|john|oclhashcat|ocl|cuda|rocm|aircrack|hashcat64" || true

hdr "Top CPU consumers (top 10)"
ps -eo pid,ppid,cmd,%cpu --sort=-%cpu | head -n 12

# 3) GPUs and accelerators
hdr "PCI devices (VGA/3D/display) -- GPUs"
lspci -nn | egrep -i "vga|3d|display" || echo "lspci not available or returned nothing"

hdr "NVIDIA GPUs (nvidia-smi if present)"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv,noheader || true
  echo
  echo "NVIDIA processes:"
  nvidia-smi pmon -c 1 2>/dev/null || nvidia-smi 2>/dev/null || true
else
  echo "nvidia-smi not found."
fi

hdr "OpenCL / ROCm devices (clinfo / rocm-smi if present)"
if command -v clinfo >/dev/null 2>&1; then
  clinfo | egrep -i "Device Type|Device Max Compute units|Platform Name" | sed -n '1,120p'
else
  echo "clinfo not found."
fi

if command -v rocm-smi >/dev/null 2>&1; then
  rocm-smi || true
fi

# 4) Attached storage & USB devices (external drives often used to move wordlists, tools)
hdr "Block devices and transport type (lsblk)"
lsblk -o NAME,MODEL,TRAN,SIZE,MOUNTPOINT | sed -n '1,200p' || true

hdr "USB devices (lsusb)"
if command -v lsusb >/dev/null 2>&1; then
  lsusb
else
  echo "lsusb not available."
fi

hdr "Recent kernel USB messages (last 24 hours)"
$SUDO_PREFIX journalctl -k --since "24 hours ago" | egrep -i "usb|sd[a-z]|scsi" | sed -n '1,200p' || true

hdr "Mounts under /media or /run/media (typical auto-mount points)"
mount | egrep -i "/media|/run/media" || echo "No mounts under /media or /run/media detected."

# 5) SSH & remote access (check for odd users or keys)
hdr "Check for unexpected SSH authorized_keys for users"
for HOME in /home/* /root; do
  [ -d "$HOME" ] || continue
  if [ -f "$HOME/.ssh/authorized_keys" ]; then
    echo "authorized_keys found: $HOME/.ssh/authorized_keys"
    ls -l "$HOME/.ssh/authorized_keys"
  fi
done

hdr "Check for open SSH sessions and long-lived remote shells"
w || true
ss -tnp | egrep ':22 ' || true

# 6) Scheduled jobs (crontabs) and suspicious startup
hdr "Root and user cron jobs"
echo "Root crontab:"
$SUDO_PREFIX crontab -l 2>/dev/null || echo "(no root crontab or permission denied)"
echo
echo "System cron dirs:"
ls -la /etc/cron.* /var/spool/cron/crontabs 2>/dev/null || true

hdr "Systemd units with odd names (non-standard)"
$SUDO_PREFIX systemctl list-units --type=service --state=running | egrep -v "^  (cron|ssh|systemd|dbus|rsyslog|NetworkManager|apt|snap|cups|avahi|rpcbind|ntp|ufw|apparmor|ModemManager|accounts-daemon|polkit|lightdm|gdm)" | sed -n '1,200p' || true

# 7) Recent installs / package activity (apt/dpkg)
hdr "Recent apt/dpkg logs (last 200 lines) for installs/updates"
if [ -f /var/log/apt/history.log ]; then
  tail -n 200 /var/log/apt/history.log | egrep -i "install|upgrade|remove"
elif [ -f /var/log/dpkg.log ]; then
  tail -n 200 /var/log/dpkg.log | egrep -i "install|upgrade|remove"
else
  echo "No apt/dpkg logs found or not accessible"
fi

# 8) Suspicious files / tools in writable temp folders
hdr "Executables in /tmp, /var/tmp, /dev/shm (common hideouts)"
find /tmp /var/tmp /dev/shm -maxdepth 2 -type f -executable -print 2>/dev/null | sed -n '1,200p' || true

# 9) Network listening sockets for remote control / management
hdr "Listening TCP/UDP sockets (ss -lptun)"
$SUDO_PREFIX ss -lptun state listening | sed -n '1,200p' || true

# 10) GPU-heavy processes via nvidia-smi (again)
if command -v nvidia-smi >/dev/null 2>&1; then
  hdr "nvidia-smi process list (if any)"
  nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv,noheader 2>/dev/null || true
fi

# Summary heuristics
hdr "Quick heuristic summary"
suspicious=0

# check for installed cracking binaries / processes
for h in hashcat john oclHashcat; do
  if command -v "$h" >/dev/null 2>&1 || ps aux | egrep -i "$h" >/dev/null 2>&1; then
    printf "Indicator: %s present (binary or running process)\n" "$h"
    suspicious=$((suspicious+1))
  fi
done

# GPU present?
if lspci -nn | egrep -i "NVIDIA|AMD|Radeon|Accelerator" >/dev/null 2>&1; then
  echo "Indicator: Discrete GPU(s) detected (NVIDIA/AMD/other) — may be used for cracking if other indicators present."
  suspicious=$((suspicious+1))
fi

# external USB storage mounts
if mount | egrep -i "/media|/run/media|/mnt" >/dev/null 2>&1; then
  echo "Indicator: External storage or auto-mounted devices present."
  suspicious=$((suspicious+1))
fi

echo
if [ "$suspicious" -ge 2 ]; then
  echo "POTENTIAL ISSUE: Multiple indicators detected ($suspicious). Recommend follow-up (see remediation below)."
elif [ "$suspicious" -eq 1 ]; then
  echo "NOTICE: Single indicator detected. Investigate further to confirm."
else
  echo "No clear indicators found by this scan. This is not a guarantee of safety; follow-up monitoring advised."
fi

# Remediation guidance
hdr "Recommended follow-up steps (manual)"
cat <<'EOF'
1) If you find a suspicious process (e.g., hashcat/john):
   - Inspect the process: `ps -fp <PID>` and `readlink -f /proc/<PID>/exe`
   - If confirmed malicious/unauthorized: stop process (kill PID) and investigate filesystem/owner.

2) If unauthorized GPUs or many GPUs are present:
   - Confirm whether they're expected for the host. If not, unplug or isolate, and check who provisioned the hardware.

3) If unexpected external storage is attached:
   - Unmount: `sudo umount /path` and physically remove device if unauthorized.
   - Scan device contents offline before mounting on other systems.

4) If unauthorized tools were installed:
   - Use package manager to remove (e.g., `sudo apt remove --purge hashcat john`) and verify package origin.
   - Check `/tmp`, `/var/tmp`, and user home dirs for dropped binaries or scripts.

5) Audit crontabs and systemd units for persistence:
   - `sudo crontab -l -u root`, `sudo ls /etc/cron.*`
   - `sudo systemctl list-unit-files | grep enabled` and inspect odd units.

6) Capture evidence before remediation if you need to investigate:
   - `ps aux > /root/ps-scan-$(date +%F).txt`
   - `ss -tunap > /root/ss-scan-$(date +%F).txt`
   - Copy suspicious binaries to a safe analysis host, preserving timestamps.

7) Harden:
   - Disable USB if necessary (BIOS/UEFI or kernel module blacklist).
   - Enforce least-privilege, rotate credentials, and require approved hardware.
   - Ensure up-to-date OS and endpoint protection.

EOF

echo
echo "Scan complete. Save this output for further analysis if needed."
exit 0
