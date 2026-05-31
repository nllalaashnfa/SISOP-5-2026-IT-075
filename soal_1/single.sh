#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSBOOT_DIR="$SCRIPT_DIR/osboot"
BUILD_DIR="$OSBOOT_DIR/single_build"

echo "[*] Membersihkan build lama..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "[*] Membuat struktur direktori..."
mkdir -p "$BUILD_DIR"/{bin,dev,proc,sys,etc,tmp,root}

chmod 1777 "$BUILD_DIR/tmp"
chmod 700  "$BUILD_DIR/root"

echo "[*] Copy device files..."
sudo cp -a /dev/null    "$BUILD_DIR/dev/"
sudo cp -a /dev/tty     "$BUILD_DIR/dev/" 2>/dev/null || true
sudo cp -a /dev/tty0    "$BUILD_DIR/dev/" 2>/dev/null || true
sudo cp -a /dev/tty1    "$BUILD_DIR/dev/" 2>/dev/null || true
sudo cp -a /dev/zero    "$BUILD_DIR/dev/"
sudo cp -a /dev/console "$BUILD_DIR/dev/"
sudo cp -a /dev/random  "$BUILD_DIR/dev/" 2>/dev/null || true
sudo cp -a /dev/urandom "$BUILD_DIR/dev/" 2>/dev/null || true

echo "[*] Install BusyBox..."
sudo cp /usr/bin/busybox "$BUILD_DIR/bin/"
cd "$BUILD_DIR/bin"
sudo ./busybox --install .
cd "$SCRIPT_DIR"

echo "[*] Buat /etc/passwd untuk root..."
ROOT_PASS=$(openssl passwd -1 "root123")
cat > "$BUILD_DIR/etc/passwd" <<EOF
root:${ROOT_PASS}:0:0:root:/root:/bin/sh
EOF

echo "[*] Buat /etc/group..."
cat > "$BUILD_DIR/etc/group" <<EOF
root:x:0:
bin:x:1:root
sys:x:2:root
tty:x:5:root
EOF

echo "[*] Buat banner ASCII Farewell Party..."
cat > "$BUILD_DIR/etc/motd" <<'BANNER'
  _____                        _ _   ____            _         
 |  ___|_ _ _ __ _____      __| | | |  _ \ __ _ _ __| |_ _   _ 
 | |_ / _` | '__/ _ \ \ /\ / /| | | | |_) / _` | '__| __| | | |
 |  _| (_| | | |  __/\ V  V / | | | |  __/ (_| | |  | |_| |_| |
 |_|  \__,_|_|  \___| \_/\_/  |_|_| |_|   \__,_|_|   \__|\__, |
                                                           |___/ 
BANNER

echo "[*] Buat file init..."
cat > "$BUILD_DIR/init" <<'INITEOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true

hostname farewell-single

echo ""
cat /etc/motd
echo "Welcome, root."
echo ""

exec /bin/sh
INITEOF

chmod +x "$BUILD_DIR/init"

echo "[*] Buat etc/profile..."
cat > "$BUILD_DIR/etc/profile" <<'PROFILEEOF'
export PS1="[\u@\h \W]# "
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export HOME=/root
PROFILEEOF

echo "[*] Compress jadi single.gz..."
cd "$BUILD_DIR"
find . | cpio -oHnewc | gzip > "$OSBOOT_DIR/single.gz"
cd "$SCRIPT_DIR"

echo "[*] Bersihin file build sisa..."
rm -rf "$BUILD_DIR"




echo " DONE! Output: osboot/single.gz"
