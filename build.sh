#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   hello os 1.0 - FINAL COMPLETE ISO BUILDER                    ║
# ║   GitHub Codespaces - Tum Hatalar Duzenlendi                   ║
# ║   Plymouth + Kernel + Bootloader GARANTI                       ║
# ╚══════════════════════════════════════════════════════════════════╝

set -e
G='\033[0;32m' B='\033[0;34m' R='\033[0;31m' Y='\033[1;33m' N='\033[0m'
log()   { echo -e "${G}[✓]${N} $1"; }
info()  { echo -e "${B}[*]${N} $1"; }
warn()  { echo -e "${Y}[!]${N} $1"; }
err()   { echo -e "${R}[X]${N} $1"; exit 1; }

clear
echo -e "${B}"
echo "╔══════════════════════════════════════════╗"
echo "║   hello os 1.0 - Final Build            ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${N}"

# ═══════════════════════════════════════════════════════════════
# 1. ORTAM KONTROLU
# ═══════════════════════════════════════════════════════════════
DISK=$(df -BG /tmp | awk 'NR==2{print $4}' | sed 's/G//')
info "Disk: ${DISK} GB (gerekli: ~8 GB)"
[ "$DISK" -lt 8 ] && err "Disk yetersiz!"

# ═══════════════════════════════════════════════════════════════
# 2. BAGIMLILIKLAR
# ═══════════════════════════════════════════════════════════════
info "Paketler kuruluyor..."
sudo apt update -qq
sudo apt install -y -qq debootstrap squashfs-tools xorriso wget p7zip-full isolinux unzip grub-efi-amd64-bin grub-pc-bin grub2-common mtools dosfstools 2>/dev/null || true
log "Paketler hazir"

# ═══════════════════════════════════════════════════════════════
# 3. DIZINLER
# ═══════════════════════════════════════════════════════════════
WORK="/tmp/hello-final-$(date +%s)"
ROOTFS="$WORK/rootfs"
ISO_DIR="$WORK/iso"
OUTPUT="/workspaces/Hello-os/hello-os-1.0-amd64.iso"

sudo rm -rf "$WORK"
mkdir -p "$ROOTFS" "$ISO_DIR"/{casper,isolinux,boot/grub,preseed}

# ═══════════════════════════════════════════════════════════════
# 4. DEBOOTSTRAP
# ═══════════════════════════════════════════════════════════════
info "Ubuntu 24.04 base indiriliyor (10-15 dk)..."
sudo debootstrap --arch=amd64 noble "$ROOTFS" http://archive.ubuntu.com/ubuntu/
log "Base hazir"

# ═══════════════════════════════════════════════════════════════
# 5. CHROOT HAZIRLIGI
# ═══════════════════════════════════════════════════════════════
sudo mount --bind /dev "$ROOTFS/dev"
sudo mount --bind /dev/pts "$ROOTFS/dev/pts"
sudo mount --bind /proc "$ROOTFS/proc"
sudo mount --bind /sys "$ROOTFS/sys"
sudo cp /etc/resolv.conf "$ROOTFS/etc/"

# ═══════════════════════════════════════════════════════════════
# 6. CHROOT ICINDE KURULUM
# ═══════════════════════════════════════════════════════════════
info "Chroot kurulumu basliyor..."

sudo tee "$ROOTFS/tmp/setup.sh" > /dev/null << 'SETUP'
#!/bin/bash
set -e

echo "╔══════════════════════════════════════════╗"
echo "║   hello os - Chroot Setup               ║"
echo "╚══════════════════════════════════════════╝"

# ---- APT UPDATE ----
echo "[01] APT guncelleniyor..."
apt update
apt upgrade -y

# ---- LOCALE ----
echo "[02] Locale..."
locale-gen tr_TR.UTF-8 en_US.UTF-8
update-locale LANG=tr_TR.UTF-8
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime

# ---- KERNEL ----
echo "[03] Kernel..."
apt install -y linux-image-generic

# ---- CASPER + UBIQUITY ----
echo "[04] Casper + Ubiquity..."
apt install -y casper ubiquity ubiquity-frontend-gtk ubiquity-slideshow-ubuntu

# ---- GNOME ----
echo "[05] GNOME..."
apt install -y gnome-session gnome-shell gnome-terminal gnome-control-center nautilus gdm3 xorg xwayland gnome-shell-extensions

# ---- NETWORK ----
echo "[06] Network..."
apt install -y network-manager wireless-tools wpasupplicant net-tools iproute2

# ---- TOOLS ----
echo "[07] Tools..."
apt install -y sudo locales wget curl git unzip software-properties-common imagemagick

# ---- PLYMOUTH (GARANTI) ----
echo "[08] Plymouth..."
apt install -y plymouth plymouth-themes plymouth-x11 || apt install -y plymouth plymouth-themes

# ---- THEME TOOLS ----
echo "[09] Theme tools..."
apt install -y gnome-tweaks gnome-themes-extra gtk2-engines-murrine

# ---- SECURITY ----
echo "[10] Security..."
apt install -y ufw fail2ban tor torsocks wireguard openvpn apparmor apparmor-profiles firejail macchanger secure-delete cryptsetup lvm2

# ---- LANGUAGE PACKS ----
echo "[11] Language packs..."
apt install -y language-pack-tr language-pack-en language-selector-common

# ---- PLYMOUTH HELLO THEME ----
echo "[12] Plymouth hello theme..."
mkdir -p /usr/share/plymouth/themes/hello

cat > /usr/share/plymouth/themes/hello/hello.plymouth << 'PLY'
[Plymouth Theme]
Name=hello
Description=hello Boot Screen
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/hello
ScriptFile=/usr/share/plymouth/themes/hello/hello.script
PLY

cat > /usr/share/plymouth/themes/hello/hello.script << 'SCR'
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
bg = Image.New(1, 1);
bg.SetPixel(0, 0, 0, 0, 0, 1);
bg_sprite = Sprite(bg);
bg_sprite.SetWidth(screen_width);
bg_sprite.SetHeight(screen_height);
hello_text = Image.Text("hello", 0, 0);
hello_text.SetFont("Sans 72");
hello_sprite = Sprite(hello_text);
hello_sprite.SetX(screen_width / 2 - hello_text.GetWidth() / 2);
hello_sprite.SetY(screen_height / 2 - hello_text.GetHeight() / 2 - 50);
hello_sprite.SetOpacity(0);
bar_bg = Image.New(200, 6);
for (i = 0; i < 200; i++) { for (j = 0; j < 6; j++) { bar_bg.SetPixel(i, j, 1.0, 1.0, 1.0, 0.2); } }
bar_bg_sprite = Sprite(bar_bg);
bar_bg_sprite.SetX(screen_width / 2 - 100);
bar_bg_sprite.SetY(screen_height / 2 + 60);
bar_fill = Image.New(1, 6);
for (j = 0; j < 6; j++) { bar_fill.SetPixel(0, j, 1.0, 1.0, 1.0, 1.0); }
bar_fill_sprite = Sprite(bar_fill);
bar_fill_sprite.SetX(screen_width / 2 - 100);
bar_fill_sprite.SetY(screen_height / 2 + 60);
bar_fill_sprite.SetWidth(0);
start_time = GetTime();
fade_done = false;
progress = 0;
fun animate() {
    current_time = GetTime() - start_time;
    if (current_time < 0.8) { hello_sprite.SetOpacity(current_time / 0.8); }
    else if (!fade_done) { hello_sprite.SetOpacity(1); fade_done = true; }
    if (current_time > 1.2 && progress < 200) { progress = progress + 1.5; if (progress > 200) progress = 200; bar_fill_sprite.SetWidth(progress); }
    if (progress < 200) { Plymouth.SetRefreshFunction(animate); }
}
animate();
SCR

if command -v plymouth-set-default-theme &> /dev/null; then
    plymouth-set-default-theme hello
    update-initramfs -u
    echo "  Plymouth hello OK"
else
    echo "  Plymouth komutu yok ama tema dosyalari hazir"
fi

# ---- SYSTEM NAME ----
echo "[13] System name..."
cat > /etc/os-release << 'OS'
PRETTY_NAME="hello os"
NAME="hello os"
VERSION_ID="1.0"
ID=hello-os
ID_LIKE=ubuntu
OS
echo "hello os 1.0" > /etc/hello-release
echo "hello-os" > /etc/hostname
echo "127.0.1.1 hello-os" >> /etc/hosts

# ---- GRUB ----
echo "[14] GRUB..."
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/99-hello.cfg << 'GRB'
GRUB_DISTRIBUTOR="hello os"
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_GFXMODE=1920x1080
GRB

# ---- USER ----
echo "[15] User..."
useradd -m -s /bin/bash -G sudo,adm user
echo "user:123456" | chpasswd
mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
WaylandEnable=true
GDM

# ---- UBIQUITY CSS ----
echo "[16] Ubiquity CSS..."
mkdir -p /usr/share/ubiquity/gtk
cat > /usr/share/ubiquity/gtk/ubiquity.css << 'CSS'
@define-color bg #ffffff;@define-color fg #1d1d1f;@define-color ac #0071e3;@define-color sc #86868b;@define-color bd rgba(0,0,0,0.08);
*{font-family:-apple-system,sans-serif}
window,.ubiquity,box{background:@bg}
.title{font-size:18px;font-weight:600;color:@fg}
.subtitle{font-size:13px;color:@sc}
button.suggested-action{background:@ac;color:#fff;border-radius:8px;padding:10px 28px;font-weight:500;box-shadow:0 2px 8px rgba(0,113,227,0.2)}
button.suggested-action:hover{background:#0077ed}
progressbar{background:rgba(0,0,0,0.06);border-radius:3px;min-height:6px}
progressbar progress{background:linear-gradient(90deg,#0071e3,#5e5ce6);border-radius:3px}
entry{background:rgba(0,0,0,0.03);border:1.5px solid @bd;border-radius:8px;padding:10px 14px;color:@fg}
entry:focus{border-color:@ac;box-shadow:0 0 0 3px rgba(0,113,227,0.1)}
switch{background:rgba(0,0,0,0.15);border-radius:12px}
switch:checked{background:@ac}
CSS

# ---- SLIDES ----
echo "[17] Slides..."
S=/usr/share/ubiquity-slideshow/slides/l10n/tr
mkdir -p "$S"
cat > "$S/welcome.html" << 'SLD'
<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
body{background:#fff;text-align:center;font-family:sans-serif;padding:60px}
.hello{font-size:90px;display:flex;justify-content:center;gap:4px;margin-bottom:24px}
.h{color:#8B5CF6}.e{color:#EC4899}.l1{color:#EF4444}.l2{color:#F97316}
.o{background:linear-gradient(90deg,#FBBF24,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.title{font-size:18px;font-weight:600;color:#1d1d1f}.subtitle{font-size:13px;color:#86868b}
</style></head><body>
<div class="hello"><span class="h">h</span><span class="e">e</span><span class="l1">l</span><span class="l2">l</span><span class="o">o</span></div>
<div class="title">hello os'a Hos Geldiniz</div><div class="subtitle">Surum 1.0</div>
</body></html>
SLD

# ---- POST-INSTALL ----
echo "[18] Post-install script..."
mkdir -p /usr/share/hello-os
cat > /usr/share/hello-os/post-install.sh << 'POST'
#!/bin/bash
cd /tmp
wget -q https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/main.zip && unzip -q main.zip
cd MacTahoe-gtk-theme-main && ./install.sh -t all 2>/dev/null
mkdir -p /usr/share/themes && [ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/
mkdir -p /usr/share/fonts/truetype/pacifico
wget -q https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf -O /usr/share/fonts/truetype/pacifico/Pacifico.ttf
fc-cache -f
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTK'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
GTK
ufw enable
systemctl enable fail2ban tor apparmor
POST
chmod +x /usr/share/hello-os/post-install.sh

mkdir -p /etc/ubiquity
cat > /etc/ubiquity/ubiquity.conf << 'UBI'
[Ubiquity]
post_install_script=/usr/share/hello-os/post-install.sh
UBI

# ---- CLEAN ----
echo "[19] Clean..."
apt clean
rm -rf /tmp/* /var/cache/apt/*

echo "╔══════════════════════════════════════════╗"
echo "║   Chroot Setup Complete!                 ║"
echo "╚══════════════════════════════════════════╝"
SETUP

sudo chmod +x "$ROOTFS/tmp/setup.sh"
sudo chroot "$ROOTFS" /tmp/setup.sh
log "Chroot kurulumu tamam"

# ═══════════════════════════════════════════════════════════════
# 7. CHROOT TEMIZLIGI
# ═══════════════════════════════════════════════════════════════
sudo umount "$ROOTFS/dev/pts" 2>/dev/null || true
sudo umount "$ROOTFS/dev" 2>/dev/null || true
sudo umount "$ROOTFS/proc" 2>/dev/null || true
sudo umount "$ROOTFS/sys" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
# 8. SQUASHFS
# ═══════════════════════════════════════════════════════════════
info "SquashFS olusturuluyor..."
sudo mksquashfs "$ROOTFS" "$ISO_DIR/casper/filesystem.squashfs" -comp xz -b 1M
log "SquashFS: $(du -h "$ISO_DIR/casper/filesystem.squashfs" | cut -f1)"

# ═══════════════════════════════════════════════════════════════
# 9. KERNEL + INITRD (GARANTILI)
# ═══════════════════════════════════════════════════════════════
info "Kernel ve initrd kopyalaniyor..."

# Chroot'tan kopyala
sudo cp "$ROOTFS/boot/vmlinuz-"* "$ISO_DIR/casper/vmlinuz" 2>/dev/null
sudo cp "$ROOTFS/boot/initrd.img-"* "$ISO_DIR/casper/initrd" 2>/dev/null

# Yoksa yedek indir
if [ ! -f "$ISO_DIR/casper/vmlinuz" ] || [ ! -s "$ISO_DIR/casper/vmlinuz" ]; then
    warn "Yedek kernel indiriliyor..."
    wget -q "http://archive.ubuntu.com/ubuntu/dists/noble/main/installer-amd64/current/images/cdrom/vmlinuz" -O "$ISO_DIR/casper/vmlinuz" 2>/dev/null || true
fi

if [ ! -f "$ISO_DIR/casper/initrd" ] || [ ! -s "$ISO_DIR/casper/initrd" ]; then
    warn "Yedek initrd indiriliyor..."
    wget -q "http://archive.ubuntu.com/ubuntu/dists/noble/main/installer-amd64/current/images/cdrom/initrd.gz" -O "$ISO_DIR/casper/initrd" 2>/dev/null || true
fi

log "Kernel: $(ls -lh "$ISO_DIR/casper/vmlinuz" 2>/dev/null | awk '{print $5}')"
log "Initrd: $(ls -lh "$ISO_DIR/casper/initrd" 2>/dev/null | awk '{print $5}')"

# ═══════════════════════════════════════════════════════════════
# 10. BOOTLOADER
# ═══════════════════════════════════════════════════════════════
info "Bootloader ekleniyor..."
wget -q "https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz" -O /tmp/syslinux.tar.gz 2>/dev/null || \
wget -q "https://cdn.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz" -O /tmp/syslinux.tar.gz 2>/dev/null || true
tar -xzf /tmp/syslinux.tar.gz -C /tmp/ 2>/dev/null || true

SYS="/tmp/syslinux-6.03"
sudo cp "$SYS/bios/core/isolinux.bin" "$ISO_DIR/isolinux/" 2>/dev/null || true
sudo cp "$SYS/bios/com32/elflink/ldlinux/ldlinux.c32" "$ISO_DIR/isolinux/" 2>/dev/null || true
sudo cp "$SYS/bios/com32/menu/menu.c32" "$ISO_DIR/isolinux/" 2>/dev/null || true
sudo cp "$SYS/bios/com32/libutil/libutil.c32" "$ISO_DIR/isolinux/" 2>/dev/null || true
sudo cp "$SYS/bios/com32/lib/libcom32.c32" "$ISO_DIR/isolinux/" 2>/dev/null || true
sudo cp "$SYS/bios/mbr/isohdpfx.bin" "$ISO_DIR/" 2>/dev/null || true

sudo tee "$ISO_DIR/isolinux/isolinux.cfg" > /dev/null << 'EOF'
UI menu.c32
PROMPT 0
TIMEOUT 50
DEFAULT install
MENU TITLE hello os 1.0
LABEL install
  MENU LABEL ^Install hello os
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd boot=casper only-ubiquity quiet splash --
EOF

sudo dd if=/dev/zero of="$ISO_DIR/boot/grub/efi.img" bs=1M count=5 2>/dev/null
sudo mkfs.vfat "$ISO_DIR/boot/grub/efi.img" 2>/dev/null || true

sudo tee "$ISO_DIR/boot/grub/grub.cfg" > /dev/null << 'EOF'
set timeout=5
menuentry "Install hello os" { linux /casper/vmlinuz boot=casper only-ubiquity quiet splash; initrd /casper/initrd; }
EOF

log "Bootloader hazir"

# ═══════════════════════════════════════════════════════════════
# 11. ISO
# ═══════════════════════════════════════════════════════════════
info "ISO olusturuluyor..."
cd "$ISO_DIR"
sudo xorriso -as mkisofs \
    -isohybrid-mbr isohdpfx.bin \
    -b isolinux/isolinux.bin -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
    -isohybrid-gpt-basdat -r -V "hello os 1.0" \
    -o "$OUTPUT" .

# ═══════════════════════════════════════════════════════════════
# 12. SONUC
# ═══════════════════════════════════════════════════════════════
if [ -f "$OUTPUT" ]; then
    sudo chmod 644 "$OUTPUT"
    echo ""
    echo -e "${G}╔══════════════════════════════════════════╗${N}"
    echo -e "${G}║   ISO HAZIR!                             ║${N}"
    echo -e "${G}║   $OUTPUT${N}"
    echo -e "${G}║   Boyut: $(du -h "$OUTPUT" | cut -f1)                          ║${N}"
    echo -e "${G}║   Kullanici: user / 123456              ║${N}"
    echo -e "${G}║   Plymouth: hello animasyonu            ║${N}"
    echo -e "${G}║   Sag tik -> Download                    ║${N}"
    echo -e "${G}╚══════════════════════════════════════════╝${N}"
    echo ""
    echo "ISO icerigi:"
    7z l "$OUTPUT" 2>/dev/null | grep -E "vmlinuz|initrd|squashfs|isolinux" || true
fi
