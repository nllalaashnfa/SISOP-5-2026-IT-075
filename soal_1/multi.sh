#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSBOOT_DIR="$SCRIPT_DIR/osboot"
BUILD_DIR="$OSBOOT_DIR/multi_build"

echo "[*] Membersihkan build lama..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "[*] Membuat struktur direktori..."
mkdir -p "$BUILD_DIR"/{bin,dev,proc,sys,etc,tmp,root}
mkdir -p "$BUILD_DIR/home"/{henn,hann,viii,kids}

chmod 1777 "$BUILD_DIR/tmp"
chmod 700  "$BUILD_DIR/root"
chmod 700  "$BUILD_DIR/home/henn"
chmod 700  "$BUILD_DIR/home/hann"
chmod 700  "$BUILD_DIR/home/viii"
chmod 700  "$BUILD_DIR/home/kids"

echo "[*] Copy device files..."
sudo cp -a /dev/null    "$BUILD_DIR/dev/" 2>/dev/null || true
sudo cp -a /dev/tty     "$BUILD_DIR/dev/" 2>/dev/null || true
sudo cp -a /dev/tty0    "$BUILD_DIR/dev/" 2>/dev/null || true
sudo cp -a /dev/tty1    "$BUILD_DIR/dev/" 2>/dev/null || true
sudo cp -a /dev/zero    "$BUILD_DIR/dev/" 2>/dev/null || true
sudo cp -a /dev/console "$BUILD_DIR/dev/" 2>/dev/null || true
sudo cp -a /dev/random  "$BUILD_DIR/dev/" 2>/dev/null || true
sudo cp -a /dev/urandom "$BUILD_DIR/dev/" 2>/dev/null || true

echo "[*] Install BusyBox..."
sudo cp /usr/bin/busybox "$BUILD_DIR/bin/"
cd "$BUILD_DIR/bin"
sudo ./busybox --install .
cd "$SCRIPT_DIR"

echo "[*] Generate password hash..."
PASS_ROOT=$(openssl passwd -1 "root123")
PASS_HENN=$(openssl passwd -1 "henn123")
PASS_HANN=$(openssl passwd -1 "hann123")
PASS_VIII=$(openssl passwd -1 "viii123")
PASS_KIDS=$(openssl passwd -1 "kids123")

echo "[*] Buat /etc/passwd..."
cat > "$BUILD_DIR/etc/passwd" <<EOF
root:x:0:0:root:/root:/bin/sh
henn:x:1001:1001:henn:/home/henn:/bin/sh
hann:x:1002:1002:hann:/home/hann:/bin/sh
viii:x:1003:1003:viii:/home/viii:/bin/sh
kids:x:1004:1004:kids:/home/kids:/bin/sh
EOF

echo "[*] Buat /etc/shadow..."
cat > "$BUILD_DIR/etc/shadow" <<EOF
root:${PASS_ROOT}:19000:0:99999:7:::
henn:${PASS_HENN}:19000:0:99999:7:::
hann:${PASS_HANN}:19000:0:99999:7:::
viii:${PASS_VIII}:19000:0:99999:7:::
kids:${PASS_KIDS}:19000:0:99999:7:::
EOF
chmod 640 "$BUILD_DIR/etc/shadow"

echo "[*] Buat /etc/group..."
cat > "$BUILD_DIR/etc/group" <<EOF
root:x:0:
bin:x:1:root
sys:x:2:root
tty:x:5:root,henn,hann,viii,kids
wheel:x:10:root
users:x:100:henn,hann,viii,kids
henn:x:1001:
hann:x:1002:
viii:x:1003:
kids:x:1004:
EOF

echo "[*] Buat banner ASCII Farewell Party..."
cat > "$BUILD_DIR/etc/farewell_banner.txt" <<'BANNER'
  _____                        _ _   ____            _         
 |  ___|_ _ _ __ _____      __| | | |  _ \ __ _ _ __| |_ _   _ 
 | |_ / _` | '__/ _ \ \ /\ / /| | | | |_) / _` | '__| __| | | |
 |  _| (_| | | |  __/\ V  V / | | | |  __/ (_| | |  | |_| |_| |
 |_|  \__,_|_|  \___| \_/\_/  |_|_| |_|   \__,_|_|   \__|\__, |
                                                           |___/ 
BANNER

echo "[*] Buat /etc/profile (banner + welcome)..."
cat > "$BUILD_DIR/etc/profile" <<'PROFILEEOF'
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export HOME=$(grep "^$(whoami):" /etc/passwd | cut -d: -f6)
export PS1="[\u@\h \W]\$ "

cat /etc/farewell_banner.txt 2>/dev/null
echo "Welcome, $(whoami)."
PROFILEEOF

echo "[*] Buat init script (pakai getty untuk login)..."
cat > "$BUILD_DIR/init" <<'INITEOF'
#!/bin/sh
mount -t proc none /proc 2>/dev/null || true
mount -t sysfs none /sys 2>/dev/null || true
mount -t devtmpfs none /dev 2>/dev/null || true
mount -t tmpfs tmpfs /tmp 2>/dev/null || true

hostname farewell-multi

# Set ownership home directories
chown -R 0:0    /root          2>/dev/null || true
chown -R 1001:1001 /home/henn  2>/dev/null || true
chown -R 1002:1002 /home/hann  2>/dev/null || true
chown -R 1003:1003 /home/viii  2>/dev/null || true
chown -R 1004:1004 /home/kids  2>/dev/null || true

# Set permissions sesuai spesifikasi access control:
# root: full semua (700)
chmod 700 /root

# henn: full /home/*, gabisa /root -> /home/henn hanya milik henn
chmod 700 /home/henn

# hann: full /home/{hann,viii,kids}, gabisa /root & /home/henn
# -> /home/hann milik hann, tapi viii & kids bisa masuk
chmod 750 /home/hann

# viii: full /home/{viii,kids}, gabisa /root & /home/{henn,hann}
# -> /home/viii milik viii, kids bisa masuk
chmod 750 /home/viii

# kids: full /home/kids saja
chmod 700 /home/kids

# tmp: full akses semua user
chmod 1777 /tmp

echo ""
echo "Farewell Party OS - Multi User"
echo "================================"
echo ""

while true; do
    /bin/getty -L tty1 115200 vt100
    sleep 1
done
INITEOF

chmod +x "$BUILD_DIR/init"

echo "[*] Compress jadi multi.gz..."
cd "$BUILD_DIR"
find . | cpio -oHnewc | gzip > "$OSBOOT_DIR/multi.gz"
cd "$SCRIPT_DIR"

echo "[*] Bersihin file build sisa..."
rm -rf "$BUILD_DIR"


echo " DONE! Output: osboot/multi.gz"
echo " Users: root/root123, henn/henn123,"
echo "        hann/hann123, viii/viii123, kids/kids123"
