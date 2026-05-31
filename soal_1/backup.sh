#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSBOOT_DIR="$SCRIPT_DIR/osboot"

TIMESTAMP=$(date +"%d%m%Y-%H%M%S")
BACKUP_NAME="farewell_backup_${TIMESTAMP}.zip"

echo "[*] Mengecek file untuk di-backup..."
FILES=()
for F in "bzImage" "single.gz" "multi.gz" "farewell.iso"; do
    if [ -f "$OSBOOT_DIR/$F" ]; then
        FILES+=("$F")
        echo "    [+] $F"
    else
        echo "    [-] $F (tidak ada, skip)"
    fi
done

[ ${#FILES[@]} -eq 0 ] && echo "[ERROR] Tidak ada file untuk di-backup!" && exit 1

echo "[*] Membuat $BACKUP_NAME ..."
cd "$OSBOOT_DIR"
zip -9 "$BACKUP_NAME" "${FILES[@]}"

echo "[*] Menghapus file yang sudah di-backup..."
for F in "${FILES[@]}"; do
    rm -f "$F"
    echo "    [-] Dihapus: $F"
done

echo " DONE! Backup: osboot/${BACKUP_NAME}"
