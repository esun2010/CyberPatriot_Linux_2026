#!/bin/bash
#check

# This script removes all .mp3, .mov, and .mp4 files from the specified directory.

# Set the target directory (change this to the desired directory)
TARGET_DIR="/"

# Check if the directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Directory does not exist: $TARGET_DIR"
    exit 1
fi

# Find and remove all .mp3, .mov, and .mp4 files in the target directory and subdirectories
find "$TARGET_DIR" -type f \( -iname "*.mp3" -o -iname "*.mov" -o -iname "*.mp4" \) -exec rm -f {} \;

# confirm the operation
echo "All .mp3, .mov, and .mp4 files have been removed from $TARGET_DIR and its subdirectories."
