#!/bin/bash
#check

set -euo pipefail

# This script removes all .mp3, .mov, and .mp4 files from the target directory.
# By default it scans from /, while pruning pseudo-filesystems that should not be traversed.

TARGET_DIR="/"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Directory does not exist: $TARGET_DIR"
    exit 1
fi

echo "Removing .mp3, .mov, and .mp4 files from $TARGET_DIR ..."

find "$TARGET_DIR" \
    \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \
    -type f \( -iname "*.mp3" -o -iname "*.mov" -o -iname "*.mp4" \) -print -delete

echo "All .mp3, .mov, and .mp4 files have been removed from $TARGET_DIR and its subdirectories."