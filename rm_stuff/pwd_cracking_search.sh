#!/usr/bin/env bash
# Defensive scan for hardware/software commonly used for password cracking.
# Run as root (sudo) for full visibility.
#
# Each section below is printed to the terminal AND saved to its own .txt
# file in the same folder as this script, so results can be reviewed later
# or handed off without re-running the scan. All filenames are reported at
# the end of the run.

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="$SCRIPT_DIR/logs"
mkdir -p "$OUT_DIR"

SUDO_PREFIX=""
if [ "$EUID" -ne 0 ]; then
  SUDO_PREFIX="sudo"
fi

declare -a SAVED_FILES=()

# Runs the given command block, tees it to both the terminal and a txt file
# in $OUT_DIR, and records the filename for the final report.
# Usage: run_section "01_tools" "Header text" 'command; command2'
run_section() {
  local slug="$1"
  local title="$2"
  local cmd="$3"
  local file="$OUT_DIR/${slug}.txt"

  printf "\n--- %s ---\n" "$title"
  {
    printf -- "--- %s ---\n" "$title"
    printf "Generated: %s\n\n" "$(date)"
    eval "$cmd"
  } | tee "$file"

  SAVED_FILES+=("$file")
}

echo
echo "=== Password-cracking device & tool detection - $(date) ==="
echo "Run by: $(whoami)"
echo "Saving section output to: $OUT_DIR"
echo

# 1) Known cracking binaries / packages detection
run_section "01_tools_in_path" "Installed / available cracking tools (command in PATH)" '
declare -a tools=(hashcat john johnny oclHashcatoclHashcat rarcrack ocl-devicesoclinfo)
for t in "${tools[@]}"; do
  if command -v "$t" >/dev/null 2>&1; then
    printf "FOUND: %s -> %s\n" "$t" "$(command -v "$t")"
  else
    printf "not found: %s\n" "$t"
  fi
done
'

run_section "02_package_manager_check" "Check package manager (dpkg/rpm) for common packages" '
if command -v dpkg >/dev/null 2>&1; then
  '"$SUDO_PREFIX"' dpkg -l 2>/dev/null | egrep -i "hashcat|john|ocl|ocl-?hashcat|cuda|rocm|opencl" || true
elif command -v rpm >/dev/null 2>&1; then
  '"$SUDO_PREFIX"' rpm -qa | egrep -i "hashcat|john|ocl|cuda|rocm|opencl" || true
else
  echo "No dpkg/rpm found to query packages."
fi
'

# 2) Running processes relating to cracking tools / high CPU or GPU usage
run_section "03_suspicious_processes" "Running processes mentioning cracking-tool names or suspicious strings" '
ps aux | egrep -i "hashcat|john|oclhashcat|ocl|cuda|rocm|aircrack|hashcat64" || true
'

run_section "04_top_cpu" "Top CPU consumers (top 10)" '
ps -eo pid,ppid,cmd,%cpu --sort=-%cpu | head -n 12
'

# 3) GPUs and accelerators
run_section "05_gpu_pci_devices" "PCI devices (VGA/3D/display) -- GPUs" '
lspci -nn | egrep -i "vga|3d|display" || echo "lspci not available or returned nothing"
'

run_section "06_nvidia_gpu" "NVIDIA GPUs (nvidia-smi if present)" '
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv,noheader || true
  echo
  echo "NVIDIA processes:"
  nvidia-smi pmon -c 1 2>/dev/null || nvidia-smi 2>/dev/null || true
else
  echo "nvidia-smi not found."
fi
'

run_section "07_opencl_rocm" "OpenCL / ROCm devices (clinfo / rocm-smi if present)" '
if command -v clinfo >/dev/null 2>&1; then
  clinfo | egrep -i "Device Type|Device Max Compute units|Platform Name" | sed -n "1,120p" || true
else
  echo "clinfo not found."
fi

if command -v rocm-smi >/dev/null 2>&1; then
  rocm-smi || true
fi
'

# 4) Attached storage & USB devices (external drives often used to move wordlists, tools)
run_section "08_block_devices" "Block devices and transport type (lsblk)" '
lsblk -o NAME,MODEL,TRAN,SIZE,MOUNTPOINT | sed -n "1,200p" || true
'

run_section "09_usb_devices" "USB devices (lsusb)" '
if command -v lsusb >/dev/null 2>&1; then
  lsusb
else
  echo "lsusb not available."
fi
'

run_section "10_usb_kernel_log" "Recent kernel USB messages (last 24 hours)" '
'"$SUDO_PREFIX"' journalctl -k --since "24 hours ago" | egrep -i "usb|sd[a-z]|scsi" | sed -n "1,200p" || true
'

run_section "11_media_mounts" "Mounts under /media or /run/media (typical auto-mount points)" '
mount | egrep -i "/media|/run/media" || echo "No mounts under /media or /run/media detected."
'

# 5) SSH & remote access (check for odd users or keys)
run_section "12_ssh_authorized_keys" "Check for unexpected SSH authorized_keys for users" '
for home_dir in /home/* /root; do
  [ -d "$home_dir" ] || continue
  if [ -f "$home_dir/.ssh/authorized_keys" ]; then
    echo "authorized_keys found: $home_dir/.ssh/authorized_keys"
    ls -l "$home_dir/.ssh/authorized_keys"
  fi
done
'

run_section "13_ssh_sessions" "Check for open SSH sessions and long-lived remote shells" '
w || true
ss -tnp | egrep ":22 " || true
'

# 6) Scheduled jobs (crontabs) and suspicious startup
run_section "14_cron_jobs" "Root and user cron jobs" '
echo "Root crontab:"
'"$SUDO_PREFIX"' crontab -l 2>/dev/null || echo "(no root crontab or permission denied)"
echo
echo "System cron dirs:"
ls -la /etc/cron.* /var/spool/cron/crontabs 2>/dev/null || true
'

run_section "15_systemd_units" "Systemd units with odd names (non-standard)" '
'"$SUDO_PREFIX"' systemctl list-units --type=service --state=running | egrep -v "^  (cron|ssh|systemd|dbus|rsyslog|NetworkManager|apt|snap|cups|avahi|rpcbind|ntp|ufw|apparmor|ModemManager|accounts-daemon|polkit|lightdm|gdm)" | sed -n "1,200p" || true
'

# 7) Recent installs / package activity (apt/dpkg)
run_section "16_apt_dpkg_log" "Recent apt/dpkg logs (last 200 lines) for installs/updates" '
if [ -f /var/log/apt/history.log ]; then
  tail -n 200 /var/log/apt/history.log | egrep -i "install|upgrade|remove" || true
elif [ -f /var/log/dpkg.log ]; then
  tail -n 200 /var/log/dpkg.log | egrep -i "install|upgrade|remove" || true
else
  echo "No apt/dpkg logs found or not accessible"
fi
'

# 8) Suspicious files / tools in writable temp folders
run_section "17_tmp_executables" "Executables in /tmp, /var/tmp, /dev/shm (common hideouts)" '
find /tmp /var/tmp /dev/shm -maxdepth 2 -type f -executable -print 2>/dev/null | sed -n "1,200p" || true
'

# 9) Network listening sockets for remote control / management
run_section "18_listening_sockets" "Listening TCP/UDP sockets (ss -lptun)" '
'"$SUDO_PREFIX"' ss -lptun state listening | sed -n "1,200p" || true
'

# 10) GPU-heavy processes via nvidia-smi (again)
if command -v nvidia-smi >/dev/null 2>&1; then
  run_section "19_nvidia_processes" "nvidia-smi process list (if any)" '
  nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv,noheader 2>/dev/null || true
  '
fi

# Summary heuristics
SUMMARY_FILE="$OUT_DIR/20_summary.txt"
{
  printf -- "--- Quick heuristic summary ---\n"
  printf "Generated: %s\n\n" "$(date)"

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
    echo "POTENTIAL ISSUE: Multiple indicators detected ($suspicious). Recommend follow-up (see remediation file)."
  elif [ "$suspicious" -eq 1 ]; then
    echo "NOTICE: Single indicator detected. Investigate further to confirm."
  else
    echo "No clear indicators found by this scan. This is not a guarantee of safety; follow-up monitoring advised."
  fi
} | tee "$SUMMARY_FILE"
SAVED_FILES+=("$SUMMARY_FILE")

# Remediation guidance
REMEDIATION_FILE="$OUT_DIR/21_remediation_steps.txt"
{
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
} | tee "$REMEDIATION_FILE"
SAVED_FILES+=("$REMEDIATION_FILE")

echo
echo "Scan complete. Results saved in: $OUT_DIR"
echo
echo "Files written:"
for f in "${SAVED_FILES[@]}"; do
  echo " - $f"
done

exit 0