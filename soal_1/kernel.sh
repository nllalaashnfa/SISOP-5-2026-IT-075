#!/bin/bash
set -e

KERNEL_VERSION="6.1.1"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSBOOT_DIR="$SCRIPT_DIR/osboot"

echo "[*] Membuat direktori osboot..."
mkdir -p "$OSBOOT_DIR"

cd "$OSBOOT_DIR"

echo "[*] Download kernel Linux ${KERNEL_VERSION}..."
if [ ! -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
    wget "$KERNEL_URL"
else
    echo "[*] Tarball sudah ada, skip download."
fi

echo "[*] Ekstrak kernel..."
if [ ! -d "linux-${KERNEL_VERSION}" ]; then
    tar -xf "linux-${KERNEL_VERSION}.tar.xz"
else
    echo "[*] Source sudah ada, skip ekstrak."
fi

cd "linux-${KERNEL_VERSION}"

# Copy .config dari repo kalau ada
CONFIG_FILE="$SCRIPT_DIR/.config"
if [ -f "$CONFIG_FILE" ] && [ $(wc -l < "$CONFIG_FILE") -gt 5 ]; then
    echo "[*] Pakai .config dari repo..."
    cp "$CONFIG_FILE" .config
    make olddefconfig
else
    echo "[*] Generate konfigurasi minimal..."
    make tinyconfig

    ./scripts/config --enable CONFIG_64BIT
    ./scripts/config --enable CONFIG_PRINTK
    ./scripts/config --enable CONFIG_FUTEX
    ./scripts/config --enable CONFIG_BLK_DEV_INITRD
    ./scripts/config --enable CONFIG_CGROUPS
    ./scripts/config --enable CONFIG_TTY
    ./scripts/config --enable CONFIG_DEVMEM
    ./scripts/config --enable CONFIG_DEVTMPFS
    ./scripts/config --enable CONFIG_DEVTMPFS_MOUNT
    ./scripts/config --enable CONFIG_BINFMT_ELF
    ./scripts/config --enable CONFIG_BINFMT_SCRIPT
    ./scripts/config --enable CONFIG_FUSE_FS
    ./scripts/config --enable CONFIG_EXT4_FS
    ./scripts/config --enable CONFIG_PROC_FS
    ./scripts/config --enable CONFIG_SYSCTL
    ./scripts/config --enable CONFIG_SYSFS
    ./scripts/config --enable CONFIG_UNIX
    ./scripts/config --enable CONFIG_INET
    ./scripts/config --enable CONFIG_NET
    ./scripts/config --enable CONFIG_NETDEVICES
    ./scripts/config --enable CONFIG_BLK_DEV_LOOP
    ./scripts/config --enable CONFIG_BLK_DEV_RAM
    ./scripts/config --enable CONFIG_BLOCK
    ./scripts/config --enable CONFIG_IP_PNP
    ./scripts/config --enable CONFIG_IP_PNP_DHCP
    ./scripts/config --enable CONFIG_VIRTIO
    ./scripts/config --enable CONFIG_VIRTIO_PCI
    ./scripts/config --enable CONFIG_VIRTIO_NET
    ./scripts/config --enable CONFIG_VIRTIO_BLK
    ./scripts/config --enable CONFIG_VIRTIO_CONSOLE
    ./scripts/config --enable CONFIG_VIRTIO_MMIO

    make olddefconfig
fi

echo "[*] Compile kernel (sabar ya ini lama)..."
make -j$(nproc)

echo "[*] Copy bzImage ke osboot/..."
cp arch/x86/boot/bzImage "$OSBOOT_DIR/bzImage"


echo " DONE! Output: osboot/bzImage"


