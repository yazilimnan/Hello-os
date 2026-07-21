#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║   hello os - debootstrap Build (GitHub Codespaces)        ║
# ╚══════════════════════════════════════════════════════════════╝

set -e
G='\033[0;32m' B='\033[0;34m' R='\033[0;31m' N='\033[0m'
log() { echo -e "${G}[✓]${N} $1"; }
info() { echo -e "${B}[*]${N} $1"; }
err() { echo -e "${R}[X]${N} $1"; exit 1; }

clear
echo -e "${B}"
echo "╔══════════════════════════════════════════╗"
echo "║   hello os - Codespaces Build           ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${N}"

# ── Disk kontrolü ──
DISK=$(df -BG /tmp | awk 'NR==2{print $4}' | sed 's/G//')
info "Disk: ${DISK} GB (gerekli: ~8 GB)"
[ "$DISK" -lt 8 ] && err "Disk yetersiz!"

# ── Paketler ──
info "Paketler kuruluyor..."
sudo apt update -qq
sudo apt install -y -qq debootstrap squashfs-tools xorriso wget p7zip-full isolinux
log "Paketler hazır"

# ── Dizinler ──
WORK="/tmp/hello-os-build"
ROOTFS="$WORK/rootfs"
ISO_DIR="$WORK/iso"
OUTPUT="/workspaces/Hello-os/hello-os-1.0-amd64.iso"

sudo rm -rf "$WORK"
mkdir -p "$ROOTFS" "$ISO_DIR"/{casper,isolinux,boot/grub}

# ═══════════════════════════════════════════════════════════════
# 1. DEBOOTSTRAP - Sıfırdan sistem
# ═══════════════════════════════════════════════════════════════
info "Ubuntu 24.04 base indiriliyor (10-15 dk)..."
sudo debootstrap --arch=amd64 noble "$ROOTFS" http://archive.ubuntu.com/ubuntu/
log "Base sistem hazır"

# ═══════════════════════════════════════════════════════════════
# 2. CHROOT İÇİNDE PAKET KURULUMU
# ═══════════════════════════════════════════════════════════════
info "Chroot hazırlanıyor..."

# Mount'ları bağla
sudo mount --bind /dev "$ROOTFS/dev"
sudo mount --bind /proc "$ROOTFS/proc"
sudo mount --bind /sys "$ROOTFS/sys"
sudo cp /etc/resolv.conf "$ROOTFS/etc/"

# Kurulum script'ini oluştur
sudo tee "$ROOTFS/tmp/setup.sh" > /dev/null << 'SETUP'
#!/bin/bash
set -e

echo "=== hello os - Paket Kurulumu ==="

# Depoları güncelle
apt update

# GNOME + Wayland + Kurulum araçları
apt install -y --no-install-recommends \
    gnome-session gnome-shell gnome-terminal gnome-control-center \
    nautilus gdm3 xorg xwayland gnome-shell-extensions \
    casper ubiquity ubiquity-frontend-gtk ubiquity-slideshow-ubuntu \
    network-manager wireless-tools wpasupplicant \
    plymouth plymouth-themes plymouth-x11 \
    gnome-tweaks gnome-themes-extra gtk2-engines-murrine \
    git wget imagemagick python3 sudo locales \
    linux-image-generic

# ── Plymouth hello teması ──
rm -rf /usr/share/plymouth/themes/*
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

plymouth-set-default-theme hello
update-initramfs -u

# ── Sistem adı ──
cat > /etc/os-release << 'OS'
PRETTY_NAME="hello os"
NAME="hello os"
VERSION_ID="1.0"
VERSION="1.0"
ID=hello-os
ID_LIKE=ubuntu
OS
echo "hello os 1.0" > /etc/hello-release
echo "hello-os" > /etc/hostname

# ── GRUB ──
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/99-hello.cfg << 'GRUB'
GRUB_DISTRIBUTOR="hello os"
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB

# ── Kullanıcı ──
useradd -m -s /bin/bash -G sudo,adm user
echo "user:123456" | chpasswd
mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
WaylandEnable=true
GDM

# ── Ubiquity CSS ──
mkdir -p /usr/share/ubiquity/gtk
cat > /usr/share/ubiquity/gtk/ubiquity.css << 'CSS'
@define-color bg #ffffff;@define-color fg #1d1d1f;@define-color ac #0071e3;
*{font-family:-apple-system,sans-serif}
window,.ubiquity,box{background:@bg}
.title{font-size:18px;font-weight:600;color:@fg}
button.suggested-action{background:@ac;color:#fff;border-radius:8px;padding:10px 28px;font-weight:500}
progressbar{background:rgba(0,0,0,0.08);border-radius:3px;min-height:6px}
progressbar progress{background:linear-gradient(90deg,#0071e3,#5e5ce6);border-radius:3px}
entry{background:rgba(0,0,0,0.03);border:1.5px solid rgba(0,0,0,0.08);border-radius:8px;padding:10px 14px}
entry:focus{border-color:@ac;box-shadow:0 0 0 3px rgba(0,113,227,0.1)}
CSS

# ── Kurulum slaytı ──
mkdir -p /usr/share/ubiquity-slideshow/slides/l10n/tr
cat > /usr/share/ubiquity-slideshow/slides/l10n/tr/welcome.html << 'SLIDE'
<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
body{background:#fff;text-align:center;font-family:sans-serif;padding:60px}
.hello{font-size:90px;display:flex;justify-content:center;gap:4px}
.h{color:#8B5CF6}.e{color:#EC4899}.l1{color:#EF4444}.l2{color:#F97316}
.o{background:linear-gradient(90deg,#FBBF24,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.title{font-size:18px;font-weight:600;color:#1d1d1f}
</style></head><body>
<div class="hello"><span class="h">h</span><span class="e">e</span><span class="l1">l</span><span class="l2">l</span><span class="o">o</span></div>
<div class="title">hello os'a Hoş Geldiniz</div>
</body></html>
SLIDE

# ── Temizlik ──
apt clean
rm -rf /tmp/*
echo "=== Kurulum tamamlandı ==="
SETUP

sudo chmod +x "$ROOTFS/tmp/setup.sh"
info "Paketler kuruluyor (10-20 dk)..."
sudo chroot "$ROOTFS" /tmp/setup.sh
log "Paket kurulumu tamam"

# ═══════════════════════════════════════════════════════════════
# 3. TEMİZLİK VE SQUASHFS
# ═══════════════════════════════════════════════════════════════
sudo umount "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" 2>/dev/null || true

info "Squashfs oluşturuluyor..."
sudo mksquashfs "$ROOTFS" "$ISO_DIR/casper/filesystem.squashfs" -comp xz -b 1M
log "Squashfs: $(du -h "$ISO_DIR/casper/filesystem.squashfs" | cut -f1)"

# ═══════════════════════════════════════════════════════════════
# 4. KERNEL + INITRD
# ═══════════════════════════════════════════════════════════════
sudo cp "$ROOTFS/boot/vmlinuz-"* "$ISO_DIR/casper/vmlinuz" 2>/dev/null || true
sudo cp "$ROOTFS/boot/initrd.img-"* "$ISO_DIR/casper/initrd" 2>/dev/null || true

# Manifest
sudo chroot "$ROOTFS" dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee "$ISO_DIR/casper/filesystem.manifest" > /dev/null
sudo stat -c%s "$ISO_DIR/casper/filesystem.squashfs" | sudo tee "$ISO_DIR/casper/filesystem.size" > /dev/null

log "Kernel ve initrd kopyalandı"

# ═══════════════════════════════════════════════════════════════
# 5. BOOTLOADER (ISOLINUX + GRUB)
# ═══════════════════════════════════════════════════════════════
info "Bootloader ekleniyor..."

# Syslinux
wget -q https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz -O /tmp/syslinux.tar.gz
tar -xzf /tmp/syslinux.tar.gz -C /tmp/

sudo cp /tmp/syslinux-6.03/bios/core/isolinux.bin "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/menu/menu.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/libutil/libutil.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/lib/libcom32.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/mbr/isohdpfx.bin "$ISO_DIR/"

sudo tee "$ISO_DIR/isolinux/isolinux.cfg" > /dev/null << EOF
UI menu.c32
PROMPT 0
TIMEOUT 50
DEFAULT live
MENU TITLE hello os 1.0
LABEL live
  MENU LABEL ^Start hello os
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd boot=casper quiet splash --
LABEL install
  MENU LABEL ^Install hello os
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd boot=casper only-ubiquity quiet splash --
EOF

sudo dd if=/dev/zero of="$ISO_DIR/boot/grub/efi.img" bs=1M count=5 2>/dev/null
sudo tee "$ISO_DIR/boot/grub/grub.cfg" > /dev/null << EOF
set timeout=5
menuentry "hello os - Live" { linux /casper/vmlinuz boot=casper quiet splash; initrd /casper/initrd; }
menuentry "hello os - Install" { linux /casper/vmlinuz boot=casper only-ubiquity quiet splash; initrd /casper/initrd; }
EOF

log "Bootloader hazır"

# ═══════════════════════════════════════════════════════════════
# 6. ISO OLUŞTUR
# ═══════════════════════════════════════════════════════════════
info "ISO oluşturuluyor..."
cd "$ISO_DIR"
sudo xorriso -as mkisofs \
    -isohybrid-mbr isohdpfx.bin \
    -b isolinux/isolinux.bin -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
    -isohybrid-gpt-basdat -r -V "hello os 1.0" \
    -o "$OUTPUT" .

if [ -f "$OUTPUT" ]; then
    sudo chmod 644 "$OUTPUT"
    echo ""
    echo -e "${G}╔══════════════════════════════════════════╗${N}"
    echo -e "${G}║   🎉 ISO HAZIR!                         ║${N}"
    echo -e "${G}║   $OUTPUT${N}"
    echo -e "${G}║   Boyut: $(du -h "$OUTPUT" | cut -f1)                          ║${N}"
    echo -e "${G}║   Kullanıcı: user / 123456              ║${N}"
    echo -e "${G}║   Sağ tık → Download                     ║${N}"
    echo -e "${G}╚══════════════════════════════════════════╝${N}"
else
    err "ISO oluşturulamadı!"
fi
