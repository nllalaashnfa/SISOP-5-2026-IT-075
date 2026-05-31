#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSBOOT_DIR="$SCRIPT_DIR/osboot"
ISO_BUILD_DIR="$OSBOOT_DIR/isobuild"

echo "[*] Cek file yang dibutuhkan..."
[ ! -f "$OSBOOT_DIR/bzImage"   ] && echo "[ERROR] bzImage tidak ada! Jalankan kernel.sh dulu."   && exit 1
[ ! -f "$OSBOOT_DIR/single.gz" ] && echo "[ERROR] single.gz tidak ada! Jalankan single.sh dulu." && exit 1
[ ! -f "$OSBOOT_DIR/multi.gz"  ] && echo "[ERROR] multi.gz tidak ada! Jalankan multi.sh dulu."   && exit 1

rm -rf "$ISO_BUILD_DIR"

echo "[*] Buat struktur direktori ISO..."
mkdir -p "$ISO_BUILD_DIR/boot/grub"

echo "[*] Copy kernel dan filesystem..."
cp "$OSBOOT_DIR/bzImage"   "$ISO_BUILD_DIR/boot/"
cp "$OSBOOT_DIR/single.gz" "$ISO_BUILD_DIR/boot/"
cp "$OSBOOT_DIR/multi.gz"  "$ISO_BUILD_DIR/boot/"

echo "[*] Buat grub.cfg..."
cat > "$ISO_BUILD_DIR/boot/grub/grub.cfg" <<'GRUBEOF'
set timeout=10
set default=0

menuentry "Farewell Party OS - Single User" {
    linux /boot/bzImage quiet console=ttyS0,115200
    initrd /boot/single.gz
}

menuentry "Farewell Party OS - Multi User" {
    linux /boot/bzImage quiet console=ttyS0,115200
    initrd /boot/multi.gz
}
GRUBEOF

echo "[*] Build ISO dengan grub-mkrescue..."
grub-mkrescue -o "$OSBOOT_DIR/farewell.iso" "$ISO_BUILD_DIR"

echo "[*] Bersihin ISO build files..."
rm -rf "$ISO_BUILD_DIR"


echo " DONE! Output: osboot/farewell.iso"

