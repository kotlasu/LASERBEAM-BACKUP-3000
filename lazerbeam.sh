#!/bin/bash

# 👽☄️ LAZERBEAM BACKUP 3000
# "ALL YOUR FILES ARE BELONG TO US"
# iPhone photo backup script via GVFS & rsync with checksum verification

set -euo pipefail

# 🧱 Optional ASCII logo if "--ascii" is passed
if [[ "${1:-}" == "--ascii" ]]; then
    shift
    if command -v figlet &>/dev/null; then
        figlet -c "LAZERBEAM 3000"
    elif command -v toilet &>/dev/null; then
        toilet -f pagga --filter border "LAZERBEAM 3000"
    else
        echo "💡 ASCII mode requested, but figlet/toilet not found. Skipping banner."
    fi
fi

# 🎯 SETUP
USERNAME=$(whoami)
DEFAULT_BACKUP_DIR="/var/home/$USERNAME/Pictures/iphone-lazerbackup"
BACKUP_DIR="${1:-$DEFAULT_BACKUP_DIR}"
LOG_FILE="$BACKUP_DIR/lazerbeam.log"

mkdir -p "$BACKUP_DIR"

# 🎮 UI
echo -e "\n🛸 INITIATING LAZERBEAM BACKUP SEQUENCE..."
echo "📂 Target directory: $BACKUP_DIR"
echo "📆 $(date)" >> "$LOG_FILE"

# 📡 FIND IPHONE MOUNT
IPHONE_MOUNT=$(find /run/user/1000/gvfs/ -mindepth 1 -maxdepth 2 -type d -name 'gphoto2:*' | head -n 1)

if [ -z "$IPHONE_MOUNT" ]; then
    echo "❌ CRITICAL ERROR: iPhone not mounted. Plug it in, unlock it, trust the computer, and try again."
    echo "❌ Backup aborted at $(date)" >> "$LOG_FILE"
    exit 1
fi

echo "✅ iPhone detected at: $IPHONE_MOUNT"

# 🔬 SCAN FOLDERS
FOLDER_LIST=$(find "$IPHONE_MOUNT" -mindepth 1 -maxdepth 3 -type d)
FOLDER_COUNT=$(echo "$FOLDER_LIST" | wc -l)

echo "📁 Found $FOLDER_COUNT folder(s) to examine. Deploying lazers..."

# 🔄 COPY FILES WITH CHECKSUM + PRELOAD
INDEX=1
while IFS= read -r FOLDER; do
    RELATIVE_PATH="${FOLDER#$IPHONE_MOUNT/}"
    TARGET_FOLDER="$BACKUP_DIR/$RELATIVE_PATH"
    mkdir -p "$TARGET_FOLDER"

    echo -e "\n[$INDEX/$FOLDER_COUNT] 🔫 Checking $RELATIVE_PATH"
    gio list "$FOLDER" >/dev/null 2>&1 || ls "$FOLDER" >/dev/null 2>&1

    FILE_COUNT=$(find "$FOLDER" -maxdepth 1 -type f | wc -l)
    if [ "$FILE_COUNT" -eq 0 ]; then
        echo "⚠️ Skipping $RELATIVE_PATH – appears empty or locked."
        ((INDEX++))
        continue
    fi

    echo "📥 Copying $FILE_COUNT file(s) from $RELATIVE_PATH to $TARGET_FOLDER"
    rsync -ah --checksum --info=progress2 "$FOLDER/" "$TARGET_FOLDER/" | tee -a "$LOG_FILE"

    sleep 1
    ((INDEX++))
done <<< "$FOLDER_LIST"

# 🧪 POST-RUN: CHECK FOR ACTUAL DUPLICATES
DUPLICATE_LOG="$BACKUP_DIR/lazerbeam-duplicates.txt"
echo -e "\n🧠 ANALYZING for true duplicates..."
find "$BACKUP_DIR" -type f -exec sha256sum {} + | sort | uniq -d --check-chars=64 > "$DUPLICATE_LOG"

if [[ -s "$DUPLICATE_LOG" ]]; then
    echo "⚠️ DUPLICATES FOUND. See: $DUPLICATE_LOG"
else
    echo "✅ No duplicates detected. Hash clean."
    rm "$DUPLICATE_LOG"
fi

# 🏁 DONE
echo -e "\n🚀 BACKUP COMPLETE. All your JPEG are belong to us."
echo "✅ $(date) — SUCCESS" >> "$LOG_FILE"
