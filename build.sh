#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   hello os 1.0 – SON BUILD (Tema sonradan kurulur)            ║
# ╚══════════════════════════════════════════════════════════════════╝

set -e
G='\033[0;32m' B='\033[0;34m' R='\033[0;31m' Y='\033[1;33m' N='\033[0m'
log() { echo -e "${G}[✓]${N} $1"; }
info() { echo -e "${B}[*]${N} $1"; }
warn() { echo -e "${Y}[!]${N} $1"; }

clear
echo -e "${B}"
echo "╔══════════════════════════════════════════╗"
echo "║   hello os 1.0 – SON BUILD              ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${N}"

SCRIPT_DIR="/workspaces/Hello-os"
FONT_FILE="$SCRIPT_DIR/Pacifico-Regular.ttf"
THEME_FILE="$SCRIPT_DIR/MacTahoe-gtk-theme-main.zip"

# Dosya kontrolü
[ -f "$FONT_FILE" ] && log "Font: $FONT_FILE ($(du -h "$FONT_FILE" | cut -f1))" || warn "Font YOK!"
[ -f "$THEME_FILE" ] && log "Tema: $THEME_FILE ($(du -h "$THEME_FILE" | cut -f1))" || warn "Tema YOK!"

# Disk
DISK_FREE=$(df -BG /tmp | awk 'NR==2{print $4}' | sed 's/G//')
info "Disk: ${DISK_FREE} GB"
[ "$DISK_FREE" -lt 15 ] && { echo "Disk yetersiz!"; exit 1; }

# Bağımlılıklar
info "Paketler kuruluyor..."
sudo apt update -qq 2>/dev/null || true
sudo apt install -y -qq live-build live-config live-boot live-manual debian-archive-keyring isolinux xorriso p7zip-full wget grub-efi-amd64-bin grub-pc-bin grub2-common unzip 2>/dev/null || true
log "Paketler hazır"

# Syslinux
SYSLINUX_DIR="/tmp/syslinux-6.03"
if [ ! -f "$SYSLINUX_DIR/bios/core/isolinux.bin" ]; then
    info "Syslinux indiriliyor..."
    rm -rf "$SYSLINUX_DIR" /tmp/syslinux.tar.gz
    wget -q --timeout=30 --tries=3 "https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz" -O /tmp/syslinux.tar.gz || \
    wget -q --timeout=30 --tries=3 "https://cdn.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz" -O /tmp/syslinux.tar.gz || \
    { echo "Syslinux indirilemedi!"; exit 1; }
    tar -xzf /tmp/syslinux.tar.gz -C /tmp/
fi
log "Syslinux hazır"

# Live-build
WORK="/tmp/hello-amd64-build"
sudo rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

info "Live-build konfigürasyonu..."
sudo lb config --architecture amd64 --distribution noble --binary-images iso-hybrid --mode ubuntu --archive-areas "main restricted universe multiverse" --parent-archive-areas "main restricted universe multiverse" --bootappend-live "boot=live components quiet splash plymouth.theme=hello" --iso-application "hello os 1.0" --iso-volume "hello os 1.0" --memtest none --apt-options "--yes" --debian-installer false --bootloader grub-efi --cache false --apt-indices false
log "Konfigürasyon tamam"

mkdir -p config/package-lists
cat > config/package-lists/hello.list.chroot << 'PKG'
gnome-session gnome-shell gnome-terminal gnome-control-center nautilus gdm3 xorg
gnome-shell-extensions xwayland casper ubiquity ubiquity-frontend-gtk
ubiquity-slideshow-ubuntu network-manager git wget plymouth plymouth-themes
gnome-tweaks gnome-themes-extra gtk2-engines-murrine imagemagick python3 sudo locales unzip
PKG

info "Bootstrap başlıyor..."
sudo lb bootstrap
log "Bootstrap tamam"

info "Chroot başlıyor..."
sudo lb chroot
log "Chroot tamam"

CHROOT_DIR="$WORK/chroot"

# ═══════════════════════════════════════════════════════════════
# YEREL DOSYALARI CHROOT'A KOPYALA
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════"
echo "  DOSYALAR CHROOT'A KOPYALANIYOR"
echo "══════════════════════════════════════════"

sudo mkdir -p "$CHROOT_DIR/tmp/fonts" "$CHROOT_DIR/tmp/themes"
[ -f "$FONT_FILE" ] && sudo cp "$FONT_FILE" "$CHROOT_DIR/tmp/fonts/" && log "Font kopyalandı"
[ -f "$THEME_FILE" ] && sudo cp "$THEME_FILE" "$CHROOT_DIR/tmp/themes/" && log "Tema kopyalandı"

# Tema kurulum script'ini de chroot'a kopyala
cat > /tmp/install-theme.sh << 'THEMESCRIPT'
#!/bin/bash
echo "=== Tema ve Font Kurulumu ==="
cd /tmp/themes
unzip -o MacTahoe-gtk-theme-main.zip -d /tmp/themes/mactahoe
THEME_DIR=$(ls -d /tmp/themes/mactahoe/*/ | head -1)
cd "$THEME_DIR"
chmod +x install.sh
./install.sh -t all
mkdir -p /usr/share/themes /usr/share/icons
[ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/ 2>/dev/null
[ -d /root/.icons ] && cp -r /root/.icons/MacTahoe* /usr/share/icons/ 2>/dev/null
mkdir -p /usr/share/fonts/truetype/pacifico
cp /tmp/fonts/Pacifico-Regular.ttf /usr/share/fonts/truetype/pacifico/
fc-cache -f
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
gtk-cursor-theme-name=MacTahoe
EOF
echo "Tema ve font kurulumu tamamlandı!"
THEMESCRIPT
sudo cp /tmp/install-theme.sh "$CHROOT_DIR/tmp/install-theme.sh"
sudo chmod +x "$CHROOT_DIR/tmp/install-theme.sh"
log "Tema kurulum script'i chroot'a kopyalandı"

# ═══════════════════════════════════════════════════════════════
# ÖZELLEŞTİRME (Tema hariç her şey)
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════"
echo "  ÖZELLEŞTİRME BAŞLIYOR"
echo "══════════════════════════════════════════"

run_chroot() {
    local cmd="$1"
    local desc="$2"
    echo "[$(date +%H:%M:%S)] $desc"
    sudo chroot "$CHROOT_DIR" bash -c "$cmd" 2>/dev/null && echo "  ✓" || echo "  ✗ (atlanıyor)"
}

# 1. Locale
run_chroot "locale-gen tr_TR.UTF-8 en_US.UTF-8 && update-locale LANG=tr_TR.UTF-8" "Locale"
run_chroot "ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime" "Zaman dilimi"

# 2. Plymouth
echo ""
echo "=== Plymouth ==="
run_chroot "rm -rf /usr/share/plymouth/themes/* && mkdir -p /usr/share/plymouth/themes/hello" "Dizin"

sudo tee "$CHROOT_DIR/usr/share/plymouth/themes/hello/hello.plymouth" > /dev/null << 'PLYCONF'
[Plymouth Theme]
Name=hello
Description=hello Boot Screen
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/hello
ScriptFile=/usr/share/plymouth/themes/hello/hello.script
PLYCONF

sudo tee "$CHROOT_DIR/usr/share/plymouth/themes/hello/hello.script" > /dev/null << 'PLYANIM'
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
bg = Image.New(1, 1);
bg.SetPixel(0, 0, 0, 0, 0, 1);
bg_sprite = Sprite(bg);
bg_sprite.SetWidth(screen_width);
bg_sprite.SetHeight(screen_height);
hello_text = Image.Text("hello", 0, 0);
hello_text.SetFont("Pacifico 72");
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
PLYANIM

run_chroot "plymouth-set-default-theme hello" "Plymouth tema"
run_chroot "update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/hello/hello.plymouth 200" "Alternatives"
run_chroot "update-alternatives --set default.plymouth /usr/share/plymouth/themes/hello/hello.plymouth" "Varsayılan"
sudo mkdir -p "$CHROOT_DIR/etc/plymouth"
sudo tee "$CHROOT_DIR/etc/plymouth/plymouthd.conf" > /dev/null << 'PLYDCONF'
[Daemon]
Theme=hello
ShowDelay=0
PLYDCONF
log "Plymouth hazır"

# 3. Sistem
sudo tee "$CHROOT_DIR/etc/os-release" > /dev/null << 'OSRELEASE'
PRETTY_NAME="hello os"
NAME="hello os"
VERSION_ID="1.0"
ID=hello-os
ID_LIKE=ubuntu
OSRELEASE
run_chroot "echo 'hello os 1.0' > /etc/hello-release && echo 'hello-os' > /etc/hostname" "Hostname"

# 4. GTK
sudo mkdir -p "$CHROOT_DIR/etc/gtk-3.0"
sudo tee "$CHROOT_DIR/etc/gtk-3.0/settings.ini" > /dev/null << 'GTKSET'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
gtk-cursor-theme-name=MacTahoe
GTKSET

# 5. GNOME
sudo mkdir -p "$CHROOT_DIR/etc/dconf/db/local.d"
sudo tee "$CHROOT_DIR/etc/dconf/db/local.d/01-hello" > /dev/null << 'GNOME'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/hello-bg.png'
primary-color='#000000'
GNOME

# 6. Duvar kağıdı
run_chroot "mkdir -p /usr/share/backgrounds && (convert -size 1920x1080 xc:'#000000' /usr/share/backgrounds/hello-bg.png 2>/dev/null || python3 -c \"from PIL import Image;Image.new('RGB',(1920,1080),'black').save('/usr/share/backgrounds/hello-bg.png')\" 2>/dev/null || touch /usr/share/backgrounds/hello-bg.png)" "Duvar kağıdı"

# 7. GRUB
run_chroot "mkdir -p /etc/default/grub.d" "GRUB"
sudo tee "$CHROOT_DIR/etc/default/grub.d/99-hello.cfg" > /dev/null << 'GRUB'
GRUB_DISTRIBUTOR="hello os"
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash plymouth.theme=hello"
GRUB_GFXMODE=1920x1080
GRUB

# 8. Kullanıcı
run_chroot "useradd -m -s /bin/bash -G sudo user 2>/dev/null || true" "Kullanıcı"
run_chroot "echo 'user:123456' | chpasswd" "Şifre"
sudo mkdir -p "$CHROOT_DIR/etc/gdm3"
sudo tee "$CHROOT_DIR/etc/gdm3/custom.conf" > /dev/null << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
WaylandEnable=true
GDM

# 9. Ubiquity CSS
sudo mkdir -p "$CHROOT_DIR/usr/share/ubiquity/gtk"
sudo tee "$CHROOT_DIR/usr/share/ubiquity/gtk/ubiquity.css" > /dev/null << 'CSS'
@define-color bg #ffffff;@define-color fg #1d1d1f;@define-color ac #0071e3;@define-color sc #86868b;
*{font-family:-apple-system,sans-serif}
window,.ubiquity,box{background:@bg}
.title{font-size:18px;font-weight:600;color:@fg}
.subtitle{font-size:13px;color:@sc}
button.suggested-action{background:@ac;color:#fff;border-radius:8px;padding:10px 28px;font-weight:500;box-shadow:0 2px 8px rgba(0,113,227,0.2)}
progressbar{background:rgba(0,0,0,0.08);border-radius:3px;min-height:6px}
progressbar progress{background:linear-gradient(90deg,#0071e3,#5e5ce6);border-radius:3px}
entry{background:rgba(0,0,0,0.03);border:1.5px solid rgba(0,0,0,0.08);border-radius:8px;padding:10px 14px;color:@fg}
entry:focus{border-color:@ac;box-shadow:0 0 0 3px rgba(0,113,227,0.1)}
switch{background:rgba(0,0,0,0.15);border-radius:12px}
switch:checked{background:@ac}
CSS

# 10. Slayt
sudo mkdir -p "$CHROOT_DIR/usr/share/ubiquity-slideshow/slides/l10n/tr"
sudo tee "$CHROOT_DIR/usr/share/ubiquity-slideshow/slides/l10n/tr/welcome.html" > /dev/null << 'SLIDE'
<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
body{background:#fff;text-align:center;font-family:sans-serif;padding:60px}
.hello{font-size:90px;display:flex;justify-content:center;gap:4px}
.h{color:#8B5CF6}.e{color:#EC4899}.l1{color:#EF4444}.l2{color:#F97316}
.o{background:linear-gradient(90deg,#FBBF24,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.title{font-size:18px;font-weight:600;color:#1d1d1f}.subtitle{font-size:13px;color:#86868b}
</style></head><body>
<div class="hello"><span class="h">h</span><span class="e">e</span><span class="l1">l</span><span class="l2">l</span><span class="o">o</span></div>
<div class="title">hello os'a Hoş Geldiniz</div><div class="subtitle">Sürüm 1.0</div>
</body></html>
SLIDE

# 11. Güncellemeler
run_chroot "update-initramfs -u" "Initramfs"
run_chroot "update-grub" "GRUB"
run_chroot "apt clean; rm -rf /tmp/* /var/cache/apt/*" "Temizlik"

log "Tüm özelleştirmeler tamamlandı"

# ═══════════════════════════════════════════════════════════════
# ISO OLUŞTUR
# ═══════════════════════════════════════════════════════════════
info "Binary ISO oluşturuluyor..."
sudo lb binary
log "Binary tamam"

BINARY_ISO="$WORK/live-image-amd64.iso"
[ ! -f "$BINARY_ISO" ] && BINARY_ISO="$WORK/chroot/binary.hybrid.iso"
[ ! -f "$BINARY_ISO" ] && { echo "Binary ISO bulunamadı!"; exit 1; }

info "Boot dosyaları ekleniyor..."
TMPISO="/tmp/hello-final-iso"
rm -rf "$TMPISO"
mkdir -p "$TMPISO"
7z x "$BINARY_ISO" -o"$TMPISO" >/dev/null

mkdir -p "$TMPISO/isolinux"
cp "$SYSLINUX_DIR/bios/core/isolinux.bin" "$TMPISO/isolinux/"
cp "$SYSLINUX_DIR/bios/com32/elflink/ldlinux/ldlinux.c32" "$TMPISO/isolinux/"
cp "$SYSLINUX_DIR/bios/com32/menu/menu.c32" "$TMPISO/isolinux/"
cp "$SYSLINUX_DIR/bios/com32/libutil/libutil.c32" "$TMPISO/isolinux/"
cp "$SYSLINUX_DIR/bios/com32/lib/libcom32.c32" "$TMPISO/isolinux/"
cp "$SYSLINUX_DIR/bios/mbr/isohdpfx.bin" /tmp/isohdpfx.bin

KERNEL=$(ls "$TMPISO/casper"/vmlinuz-* 2>/dev/null | head -1 | xargs basename)
INITRD=$(ls "$TMPISO/casper"/initrd.img-* 2>/dev/null | head -1 | xargs basename)

cat > "$TMPISO/isolinux/isolinux.cfg" << EOF
UI menu.c32
PROMPT 0
TIMEOUT 50
DEFAULT live
MENU TITLE hello os 1.0
LABEL live
  MENU LABEL ^Start hello os
  KERNEL /casper/${KERNEL}
  APPEND initrd=/casper/${INITRD} boot=casper quiet splash plymouth.theme=hello --
LABEL install
  MENU LABEL ^Install hello os
  KERNEL /casper/${KERNEL}
  APPEND initrd=/casper/${INITRD} boot=casper only-ubiquity quiet splash plymouth.theme=hello --
EOF

mkdir -p "$TMPISO/boot/grub"
dd if=/dev/zero of="$TMPISO/boot/grub/efi.img" bs=1M count=5 2>/dev/null
mkfs.vfat "$TMPISO/boot/grub/efi.img" 2>/dev/null || true

cat > "$TMPISO/boot/grub/grub.cfg" << EOF
set timeout=5
menuentry "hello os - Live" { linux /casper/${KERNEL} boot=casper quiet splash plymouth.theme=hello; initrd /casper/${INITRD}; }
menuentry "hello os - Install" { linux /casper/${KERNEL} boot=casper only-ubiquity quiet splash plymouth.theme=hello; initrd /casper/${INITRD}; }
EOF

FINAL_ISO="$SCRIPT_DIR/hello-os-1.0-amd64.iso"
cd "$TMPISO"
xorriso -as mkisofs -isohybrid-mbr /tmp/isohdpfx.bin -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -r -V "hello os 1.0" -o "$FINAL_ISO" .

rm -rf "$TMPISO"

echo ""
echo -e "${G}╔══════════════════════════════════════════╗${N}"
echo -e "${G}║   🎉 ISO HAZIR! 🎉                      ║${N}"
echo -e "${G}║   $FINAL_ISO${N}"
echo -e "${G}║   Boyut: $(du -h "$FINAL_ISO" | cut -f1)                          ║${N}"
echo -e "${G}║   Sağ tık → Download                     ║${N}"
echo -e "${G}║                                          ║${N}"
echo -e "${G}║   Tema kurmak için:                      ║${N}"
echo -e "${G}║   sudo chroot /tmp/hello-amd64-build/chroot /tmp/install-theme.sh${N}"
echo -e "${G}║                                          ║${N}"
echo -e "${G}╚══════════════════════════════════════════╝${N}"
