#!/bin/bash
#check

###############################################################################
# CyberPatriot-safe Linux hardening script (refined, conservative)
###############################################################################

LOG_FILE="/var/log/cyberpatriot-hardening.log"
SYSCTL_FILE="/etc/sysctl.d/99-hardening.conf"

log() {
    local msg="$1"
    # Try logging to file, but don't break if it fails
    echo "[+] $msg"
    if [ -w "$(dirname "$LOG_FILE")" ] || [ ! -e "$LOG_FILE" ]; then
        echo "$(date '+%F %T') [HARDEN] $msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Ensure root
if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root."
    exit 1
fi

touch "$LOG_FILE" 2>/dev/null || true

###############################################################################
# Helpers
###############################################################################

ensure_sysctl_file() {
    mkdir -p /etc/sysctl.d
    if [[ ! -f "$SYSCTL_FILE" ]]; then
        touch "$SYSCTL_FILE"
        log "Created $SYSCTL_FILE"
    fi
}

backup_once() {
    local file="$1"
    local marker="$file.cp_hardened_backup_done"
    if [[ -f "$file" && ! -f "$marker" ]]; then
        local backup="${file}.bak.$(date +%s)"
        cp "$file" "$backup"
        touch "$marker"
        log "Backup created: $backup"
    fi
}

add_sysctl_setting() {
    local key="$1"
    local value="$2"

    ensure_sysctl_file
    backup_once "$SYSCTL_FILE"

    # Remove existing lines for this key
    sed -i "/^${key//./\\.}\s*=/d" "$SYSCTL_FILE"

    echo "$key = $value" >> "$SYSCTL_FILE"
    log "Set sysctl: $key = $value (persisted in $SYSCTL_FILE)"

    # Apply immediately, but don't abort on failure
    if sysctl -w "$key=$value" >/dev/null 2>&1; then
        log "Applied sysctl at runtime: $key=$value"
    else
        log "WARNING: Failed to apply sysctl at runtime: $key"
    fi
}

###############################################################################
# Sysctl hardening (conservative)
###############################################################################

log "Applying sysctl hardening..."

# IPv4 network hardening
add_sysctl_setting net.ipv4.tcp_syncookies 1
add_sysctl_setting net.ipv4.conf.all.rp_filter 1
add_sysctl_setting net.ipv4.conf.default.rp_filter 1
add_sysctl_setting net.ipv4.conf.all.accept_redirects 0
add_sysctl_setting net.ipv4.conf.default.accept_redirects 0
add_sysctl_setting net.ipv4.conf.all.accept_source_route 0
add_sysctl_setting net.ipv4.conf.default.accept_source_route 0
add_sysctl_setting net.ipv4.conf.all.log_martians 1
add_sysctl_setting net.ipv4.conf.default.log_martians 1
add_sysctl_setting net.ipv4.icmp_echo_ignore_broadcasts 1
add_sysctl_setting net.ipv4.icmp_ignore_bogus_error_responses 1
add_sysctl_setting net.ipv4.tcp_rfc1337 1
add_sysctl_setting net.ipv4.conf.all.send_redirects 0
add_sysctl_setting net.ipv4.conf.default.send_redirects 0

# NOTE: ip_forward can be scenario-dependent (routing/VPN/NAT).
# For CyberPatriot, it's safer to NOT force it unless you know it's not needed.
# Uncomment only if the scenario clearly does NOT require routing:
# add_sysctl_setting net.ipv4.ip_forward 0

# IPv6 – light hardening, do NOT disable IPv6
add_sysctl_setting net.ipv6.conf.all.accept_redirects 0
add_sysctl_setting net.ipv6.conf.default.accept_redirects 0

# Kernel info leak / memory protections
add_sysctl_setting kernel.kptr_restrict 1
add_sysctl_setting kernel.randomize_va_space 2
add_sysctl_setting kernel.dmesg_restrict 1
add_sysctl_setting kernel.yama.ptrace_scope 1
add_sysctl_setting fs.suid_dumpable 0

log "Sysctl hardening complete."

###############################################################################
# /tmp and /dev/shm hardening
###############################################################################

harden_mountpoint() {
    local path="$1"
    local label="$2"

    log "Hardening $path..."

    if [[ -d "$path" ]]; then
        chmod 1777 "$path" 2>/dev/null || log "WARNING: Failed to chmod 1777 $path"
    fi

    if mountpoint -q "$path"; then
        if mount -o remount,noexec,nosuid,nodev "$path" 2>/dev/null; then
            log "$path remounted with noexec,nosuid,nodev"
        else
            log "WARNING: Failed to remount $path with noexec,nosuid,nodev"
        fi
    else
        log "NOTE: $path is not a mountpoint; skipping remount."
    fi
}

harden_fstab_entry() {
    local path="$1"
    local fstab="/etc/fstab"

    backup_once "$fstab"

    if grep -qE "^[^#].*\s${path//\//\\/}\s" "$fstab"; then
        # De-duplicate and ensure options
        awk -v tgt="$path" '
        $2 == tgt && $1 !~ /^#/ {
            n=split($4, a, ",")
            delete seen
            for (i=1; i<=n; i++) seen[a[i]]=1
            seen["noexec"]=1
            seen["nosuid"]=1
            seen["nodev"]=1
            opts=""
            for (k in seen) {
                if (opts == "") opts=k; else opts=opts","k
            }
            $4=opts
        }
        {print}
        ' "$fstab" > "${fstab}.tmp" && mv "${fstab}.tmp" "$fstab"
        log "Updated $path options in /etc/fstab to include noexec,nosuid,nodev (deduplicated)"
    else
        log "No explicit $path entry in /etc/fstab; leaving as-is."
    fi
}

harden_mountpoint /tmp "/tmp"
harden_fstab_entry /tmp

harden_mountpoint /dev/shm "/dev/shm"
harden_fstab_entry /dev/shm

###############################################################################
# Final log
###############################################################################

log "Hardening script finished. Review $LOG_FILE and test services (SSH, web, DB, etc.)."
echo "[+] Hardening complete. Reboot recommended after verifying services."
