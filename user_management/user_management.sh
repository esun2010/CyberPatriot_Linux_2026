#!/usr/bin/env bash
#check

set -euo pipefail

# ============================================================
# Unauthorized User/Admin Audit Script
#
# Requires:
#   - auth_users.txt   : authorized local users, one username per line
#   - auth_admins.txt  : authorized admin users, one username per line
#
# Output:
#   - unauth_users.txt   : users not in auth_users.txt
#   - unauth_admins.txt  : admin users not in auth_admins.txt,
#                          excluding users already listed as unauthorized users
#
# Run with sudo/root so group membership and local users are fully visible.
# ============================================================

AUTH_USERS_FILE="auth_users.txt"
AUTH_ADMINS_FILE="auth_admins.txt"

UNAUTH_USERS_FILE="unauth_users.txt"
UNAUTH_ADMINS_FILE="unauth_admins.txt"

# -----------------------------
# Safety checks
# -----------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)." >&2
  exit 1
fi

if [[ ! -f "$AUTH_USERS_FILE" ]]; then
  echo "Missing $AUTH_USERS_FILE" >&2
  exit 1
fi

if [[ ! -f "$AUTH_ADMINS_FILE" ]]; then
  echo "Missing $AUTH_ADMINS_FILE" >&2
  exit 1
fi

# -----------------------------
# Helpers
# -----------------------------
declare -A AUTH_USERS
declare -A AUTH_ADMINS
declare -A UNAUTH_USERS

load_list() {
  local file="$1"
  local -n out_array="$2"

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim whitespace
    line="$(echo "$line" | xargs)"

    # Skip blank lines and comments
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue

    out_array["$line"]=1
  done < "$file"
}

is_normal_local_user() {
  local username="$1"

  # Must exist
  id "$username" >/dev/null 2>&1 || return 1

  local uid shell
  uid="$(id -u "$username" 2>/dev/null || echo -1)"
  shell="$(getent passwd "$username" | cut -d: -f7)"

  # Skip root
  [[ "$username" == "root" ]] && return 1

  # Keep only regular human/local accounts:
  # most distros use UID >= 1000 for normal users
  [[ "$uid" -ge 1000 ]] || return 1

  # Skip service-style accounts even if they have high UID
  case "$shell" in
    */nologin|*/false)
      return 1
      ;;
  esac

  return 0
}

user_in_group() {
  local user="$1"
  local group="$2"

  getent group "$group" >/dev/null 2>&1 || return 1
  id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx "$group"
}

# -----------------------------
# Load authorized lists
# -----------------------------
load_list "$AUTH_USERS_FILE" AUTH_USERS
load_list "$AUTH_ADMINS_FILE" AUTH_ADMINS

# Always protect root logically
AUTH_USERS["root"]=1
AUTH_ADMINS["root"]=1

# Clear output files
: > "$UNAUTH_USERS_FILE"
: > "$UNAUTH_ADMINS_FILE"

echo "Loaded ${#AUTH_USERS[@]} authorized users."
echo "Loaded ${#AUTH_ADMINS[@]} authorized admins."
echo

# -----------------------------
# Find unauthorized users
# -----------------------------
echo "Checking for unauthorized users..."

while IFS=: read -r username _ uid _ _ _ shell; do
  # Skip root
  [[ "$username" == "root" ]] && continue

  # Only normal local users
  [[ "$uid" -ge 1000 ]] || continue
  case "$shell" in
    */nologin|*/false)
      continue
      ;;
  esac

  if [[ -z "${AUTH_USERS[$username]:-}" ]]; then
    echo "$username" >> "$UNAUTH_USERS_FILE"
    UNAUTH_USERS["$username"]=1
    echo "Unauthorized user: $username"
  fi
done < /etc/passwd

# -----------------------------
# Find unauthorized admins
# Exclude users already unauthorized as users
# -----------------------------
echo
echo "Checking for unauthorized admins..."

while IFS=: read -r username _ uid _ _ _ shell; do
  [[ "$username" == "root" ]] && continue

  # Only normal local users
  [[ "$uid" -ge 1000 ]] || continue
  case "$shell" in
    */nologin|*/false)
      continue
      ;;
  esac

  # Skip if already an unauthorized user
  if [[ -n "${UNAUTH_USERS[$username]:-}" ]]; then
    continue
  fi

  # Check if user currently has admin rights
  is_admin=0
  if user_in_group "$username" "sudo"; then
    is_admin=1
  elif user_in_group "$username" "wheel"; then
    is_admin=1
  fi

  # If they are an admin but not authorized as admin, log them
  if [[ "$is_admin" -eq 1 && -z "${AUTH_ADMINS[$username]:-}" ]]; then
    echo "$username" >> "$UNAUTH_ADMINS_FILE"
    echo "Unauthorized admin: $username"
  fi
done < /etc/passwd

echo
echo "Audit complete."
echo "Unauthorized users written to: $UNAUTH_USERS_FILE"
echo "Unauthorized admins written to: $UNAUTH_ADMINS_FILE"
```
