#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSBOOT_DIR="$SCRIPT_DIR/osboot"

usage() {
    echo "Usage: $0 [--single | --multi | --all]"
    echo "  --single  Boot single-user filesystem langsung"
    echo "  --multi   Boot multi-user filesystem langsung"
    echo "  --all     Boot dari ISO (pilih di GRUB menu)"
    exit 1
}

[ $# -eq 0 ] && usage

case "$1" in
    --single)
        [ ! -f "$OSBOOT_DIR/bzImage"   ] && echo "[ERROR] bzImage tidak ada!"   && exit 1
        [ ! -f "$OSBOOT_DIR/single.gz" ] && echo "[ERROR] single.gz tidak ada!" && exit 1
        echo "[*] Booting Single User..."
        qemu-system-x86_64 \
            -smp 2 -m 256 \
            -kernel "$OSBOOT_DIR/bzImage" \
            -initrd "$OSBOOT_DIR/single.gz" \
            -append "console=ttyS0,115200 quiet" \
            -serial mon:stdio \
            -display none \
            -net nic,model=virtio \
            -net user
        ;;

    --multi)
        [ ! -f "$OSBOOT_DIR/bzImage"  ] && echo "[ERROR] bzImage tidak ada!"  && exit 1
        [ ! -f "$OSBOOT_DIR/multi.gz" ] && echo "[ERROR] multi.gz tidak ada!" && exit 1
        echo "[*] Booting Multi User..."
        qemu-system-x86_64 \
            -smp 2 -m 256 \
            -kernel "$OSBOOT_DIR/bzImage" \
            -initrd "$OSBOOT_DIR/multi.gz" \
            -append "console=ttyS0,115200 quiet" \
            -serial mon:stdio \
            -display none \
            -net nic,model=virtio \
            -net user
        ;;

    --all)
        [ ! -f "$OSBOOT_DIR/farewell.iso" ] && echo "[ERROR] farewell.iso tidak ada! Jalankan iso.sh dulu." && exit 1
        echo "[*] Booting dari ISO..."
        qemu-system-x86_64 \
            -smp 2 -m 256 \
            -cdrom "$OSBOOT_DIR/farewell.iso" \
            -boot d \
            -serial mon:stdio \
            -display curses \
            -vga std \
            -net nic,model=virtio \
            -net user
        ;;

    *)
        echo "[ERROR] Mode tidak dikenal: $1"
        usage
        ;;
esac
