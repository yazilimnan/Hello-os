#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   hello os 1.0 – Tam Loglu ISO Builder                         ║
# ║   Ubuntu 24.04 Noble – GitHub Codespaces                       ║
# ╚══════════════════════════════════════════════════════════════════╝

set -e
G='\033[0;32m' B='\033[0;34m' R='\033[0;31m' Y='\033[1;33m' N='\033[0m'

# Log dizini
LOG_DIR="/tmp/hello-os-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/build-$(date +%Y%m%d-%H%M%S).log"
exec 2> >(tee -a "$LOG_FILE" >&2)
exec 1> >(tee -a "$LOG_FILE")

log()   { echo -e "${G}[✓]${N} $1"; }
info()  { echo -e "${B}[*]${N} $1"; }
warn()  { echo -e "${Y}[!]${N} $1"; }
err()   { echo -e "${R}[X]${N} $1"; exit 1; }

clear
echo -e "${B}"
echo "╔══════════════════════════════════════════╗"
echo "║   hello os 1.0 – Tam Loglu Build        ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${N}"
echo "Log dosyası: $LOG_FILE"
echo ""

# ── Disk kontrolü ──
DISK_FREE=$(df -BG /tmp | awk 'NR==2{print $4}' | sed 's/G//')
info "Disk: ${DISK_FREE} GB"
[ "$DISK_FREE" -lt 15 ] && err "En az 15 GB boş alan gerekli!"

# ── Bağımlılıklar ──
info "Paketler kuruluyor..."
sudo apt update -qq 2>&1 | tee -a "$LOG_FILE"
sudo apt install -y -qq \
    live-build live-config live-boot live-manual debian-archive-keyring \
    isolinux xorriso p7zip-full wget rsync \
    grub-efi-amd64-bin grub-pc-bin grub2-common 2>&1 | tee -a "$LOG_FILE"
log "Paketler hazır"

# ── Syslinux ──
info "Syslinux indiriliyor..."
SYSLINUX_DIR="/tmp/syslinux-6.03"
if [ ! -f "$SYSLINUX_DIR/bios/core/isolinux.bin" ]; then
    rm -rf "$SYSLINUX_DIR" /tmp/syslinux.tar.gz
    wget -q --timeout=60 --tries=5 \
        "https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz" \
        -O /tmp/syslinux.tar.gz 2>&1 | tee -a "$LOG_FILE" || \
    wget -q --timeout=60 --tries=5 \
        "https://cdn.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz" \
        -O /tmp/syslinux.tar.gz 2>&1 | tee -a "$LOG_FILE" || \
    err "Syslinux indirilemedi!"
    tar -xzf /tmp/syslinux.tar.gz -C /tmp/ 2>&1 | tee -a "$LOG_FILE"
fi
log "Syslinux hazır"

# ── Live-build ──
WORK="/tmp/hello-amd64-build"
sudo rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

info "Live-build konfigürasyonu..."
sudo lb config \
    --architecture amd64 \
    --distribution noble \
    --binary-images iso-hybrid \
    --mode ubuntu \
    --archive-areas "main restricted universe multiverse" \
    --parent-archive-areas "main restricted universe multiverse" \
    --bootappend-live "boot=live components quiet splash plymouth.theme=hello" \
    --iso-application "hello os 1.0" \
    --iso-volume "hello os 1.0" \
    --iso-publisher "hello os Project" \
    --memtest none \
    --apt-options "--yes" \
    --debian-installer false \
    --bootloader grub-efi \
    --cache false \
    --apt-indices false 2>&1 | tee -a "$LOG_FILE"
log "Konfigürasyon tamam"

mkdir -p config/package-lists
cat > config/package-lists/hello.list.chroot << 'PKG'
gnome-session
gnome-shell
gnome-terminal
gnome-control-center
nautilus
gdm3
xorg
gnome-shell-extensions
xwayland
casper
ubiquity
ubiquity-frontend-gtk
ubiquity-slideshow-ubuntu
network-manager
git
wget
plymouth
plymouth-themes
gnome-tweaks
gnome-themes-extra
gtk2-engines-murrine
imagemagick
python3
sudo
locales
PKG

# Bootstrap + Chroot
info "Bootstrap başlıyor..."
sudo lb bootstrap 2>&1 | tee -a "$LOG_FILE"
log "Bootstrap tamam"

info "Chroot başlıyor..."
sudo lb chroot 2>&1 | tee -a "$LOG_FILE"
log "Chroot tamam"

# ═══════════════════════════════════════════════════════════════
# MANUEL ÖZELLEŞTİRME (HER ADIM LOGLANIR)
# ═══════════════════════════════════════════════════════════════
CHROOT_DIR="$WORK/chroot"
THEME_LOG="$LOG_DIR/theme-install.log"

run_chroot() {
    local cmd="$1"
    local desc="$2"
    echo "[$(date +%H:%M:%S)] $desc" | tee -a "$THEME_LOG"
    if sudo chroot "$CHROOT_DIR" bash -c "$cmd" 2>>"$THEME_LOG"; then
        echo "  ✓ BAŞARILI" | tee -a "$THEME_LOG"
        return 0
    else
        echo "  ✗ BAŞARISIZ (devam ediliyor)" | tee -a "$THEME_LOG"
        return 1
    fi
}

echo ""
echo "══════════════════════════════════════════"
echo "  MANUEL ÖZELLEŞTİRME BAŞLIYOR"
echo "  Log: $THEME_LOG"
echo "══════════════════════════════════════════"
echo ""

# 1. Locale
run_chroot "locale-gen tr_TR.UTF-8 en_US.UTF-8" "Locale oluşturuluyor"
run_chroot "update-locale LANG=tr_TR.UTF-8" "Locale güncelleniyor"
run_chroot "ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime" "Zaman dilimi ayarlanıyor"

# 2. Pacifico font
run_chroot "mkdir -p /usr/share/fonts/truetype/pacifico" "Font dizini oluşturuluyor"
run_chroot "cd /tmp && wget -q 'https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf' -O Pacifico.ttf" "Pacifico font indiriliyor"
run_chroot "cp /tmp/Pacifico.ttf /usr/share/fonts/truetype/pacifico/ 2>/dev/null && fc-cache -f" "Font sisteme yükleniyor"

# 3. MacTahoe GTK Teması - ADIM ADIM
echo ""
echo "=== MacTahoe GTK Teması Kurulumu ==="

# Git clone
run_chroot "cd /tmp && rm -rf MacTahoe-gtk-theme" "Eski tema siliniyor"

if run_chroot "cd /tmp && git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git" "GitHub'dan tema indiriliyor"; then
    echo "  Git clone başarılı"
else
    echo "  Git clone başarısız, arşiv deneniyor..."
    run_chroot "cd /tmp && wget -qO- https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/master.tar.gz | tar -xz && mv MacTahoe-gtk-theme-master MacTahoe-gtk-theme" "Arşivden tema çıkarılıyor"
fi

# Tema kontrol
if sudo test -d "$CHROOT_DIR/tmp/MacTahoe-gtk-theme"; then
    echo "  ✓ Tema dizini mevcut"
else
    echo "  ✗ Tema dizini YOK! Atlanıyor..."
fi

# Install.sh çalıştır
run_chroot "cd /tmp/MacTahoe-gtk-theme && chmod +x install.sh && ./install.sh -c dark -i" "install.sh çalıştırılıyor"

# Temaları sistem dizinine kopyala
run_chroot "mkdir -p /usr/share/themes /usr/share/icons" "Sistem tema dizinleri oluşturuluyor"
run_chroot "[ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/ 2>/dev/null; [ -d /home/user/.themes ] && cp -r /home/user/.themes/MacTahoe* /usr/share/themes/ 2>/dev/null; echo 'Tema kopyalandı'" "Temalar sistem dizinine kopyalanıyor"

# Tema kurulum kontrolü
echo ""
echo "Tema kontrolü:"
sudo ls -la "$CHROOT_DIR/usr/share/themes/" 2>/dev/null | grep -i mactahoe && echo "  ✓ MacTahoe temaları kuruldu" || echo "  ✗ MacTahoe temaları YOK"
sudo ls -la "$CHROOT_DIR/root/.themes/" 2>/dev/null | grep -i mactahoe && echo "  ✓ /root/.themes içinde var" || echo "  ✗ /root/.themes içinde YOK"
sudo ls -la "$CHROOT_DIR/home/user/.themes/" 2>/dev/null | grep -i mactahoe && echo "  ✓ /home/user/.themes içinde var" || echo "  ✗ /home/user/.themes içinde YOK"

# 4. Plymouth
echo ""
echo "=== Plymouth Boot Animasyonu ==="
run_chroot "rm -rf /usr/share/plymouth/themes/*" "Eski temalar siliniyor"
run_chroot "mkdir -p /usr/share/plymouth/themes/hello" "Hello tema dizini oluşturuluyor"

sudo tee "$CHROOT_DIR/usr/share/plymouth/themes/hello/hello.plymouth" > /dev/null << 'PLYCONF'
[Plymouth Theme]
Name=hello
Description=hello Boot Screen
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/hello
ScriptFile=/usr/share/plymouth/themes/hello/hello.script
PLYCONF
echo "  ✓ hello.plymouth yazıldı"

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
echo "  ✓ hello.script yazıldı"

run_chroot "plymouth-set-default-theme hello" "Plymouth varsayılan tema ayarlanıyor"
run_chroot "update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/hello/hello.plymouth 200" "update-alternatives install"
run_chroot "update-alternatives --set default.plymouth /usr/share/plymouth/themes/hello/hello.plymouth" "update-alternatives set"

sudo mkdir -p "$CHROOT_DIR/etc/plymouth"
sudo tee "$CHROOT_DIR/etc/plymouth/plymouthd.conf" > /dev/null << 'PLYDCONF'
[Daemon]
Theme=hello
ShowDelay=0
PLYDCONF
echo "  ✓ plymouthd.conf yazıldı"

# 5. Sistem markalaması
echo ""
echo "=== Sistem Markalaması ==="
sudo tee "$CHROOT_DIR/etc/os-release" > /dev/null << 'OSRELEASE'
PRETTY_NAME="hello os"
NAME="hello os"
VERSION_ID="1.0"
VERSION="1.0"
ID=hello-os
ID_LIKE=ubuntu
HOME_URL="https://hello-os.org"
OSRELEASE
echo "  ✓ os-release yazıldı"
run_chroot "echo 'hello os 1.0' > /etc/hello-release && echo 'hello-os' > /etc/hostname" "hostname ve release"

# 6. GTK
sudo mkdir -p "$CHROOT_DIR/etc/gtk-3.0"
sudo tee "$CHROOT_DIR/etc/gtk-3.0/settings.ini" > /dev/null << 'GTKSET'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
gtk-cursor-theme-name=MacTahoe
GTKSET
echo "  ✓ GTK ayarları yazıldı"

# 7. GNOME
sudo mkdir -p "$CHROOT_DIR/etc/dconf/db/local.d"
sudo tee "$CHROOT_DIR/etc/dconf/db/local.d/01-hello" > /dev/null << 'GNOME'
[org/gnome/desktop/interface]
gtk-theme='MacTahoe'
icon-theme='MacTahoe'
font-name='Pacifico 11'
cursor-theme='MacTahoe'
[org/gnome/desktop/wm/preferences]
theme='MacTahoe'
[org/gnome/shell/extensions/user-theme]
name='MacTahoe'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/hello-bg.png'
primary-color='#000000'
GNOME
echo "  ✓ GNOME ayarları yazıldı"

# 8. Duvar kağıdı
run_chroot "mkdir -p /usr/share/backgrounds" "Duvar kağıdı dizini"
run_chroot "convert -size 1920x1080 xc:'#000000' /usr/share/backgrounds/hello-bg.png 2>/dev/null || python3 -c \"from PIL import Image;Image.new('RGB',(1920,1080),'black').save('/usr/share/backgrounds/hello-bg.png')\" 2>/dev/null || touch /usr/share/backgrounds/hello-bg.png" "Siyah duvar kağıdı"

# 9. GRUB + Monterey
echo ""
echo "=== GRUB + Monterey Teması ==="
run_chroot "mkdir -p /etc/default/grub.d" "GRUB config dizini"
run_chroot "cd /tmp && rm -rf monterey-grub-theme && git clone --depth=1 https://github.com/sandesh236/monterey-grub-theme.git 2>/dev/null" "Monterey teması indiriliyor"

if sudo test -d "$CHROOT_DIR/tmp/monterey-grub-theme"; then
    run_chroot "cd /tmp/monterey-grub-theme && if [ -f install.sh ]; then chmod +x install.sh && ./install.sh; else mkdir -p /boot/grub/themes/monterey && cp -r . /boot/grub/themes/monterey/; fi" "Monterey teması kuruluyor"
fi

sudo tee "$CHROOT_DIR/etc/default/grub.d/99-hello.cfg" > /dev/null << 'GRUB'
GRUB_DISTRIBUTOR="hello os"
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash plymouth.theme=hello"
GRUB_GFXMODE=1920x1080
GRUB_THEME="/boot/grub/themes/monterey/theme.txt"
GRUB
echo "  ✓ GRUB config yazıldı"

# Monterey teması kontrol
sudo ls -la "$CHROOT_DIR/boot/grub/themes/" 2>/dev/null && echo "  ✓ GRUB tema dizini var" || echo "  ✗ GRUB tema dizini YOK"

# 10. Kullanıcı
echo ""
echo "=== Kullanıcı Hesabı ==="
run_chroot "useradd -m -s /bin/bash -G sudo,adm,cdrom,dip,plugdev,lpadmin,netdev user 2>/dev/null || true" "Kullanıcı oluşturuluyor"
run_chroot "echo 'user:123456' | chpasswd" "Şifre atanıyor"

sudo mkdir -p "$CHROOT_DIR/etc/gdm3" "$CHROOT_DIR/etc/lightdm"
sudo tee "$CHROOT_DIR/etc/gdm3/custom.conf" > /dev/null << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
WaylandEnable=true
GDM
sudo tee "$CHROOT_DIR/etc/lightdm/lightdm.conf" > /dev/null << 'LIGHTDM'
[Seat:*]
autologin-user=user
autologin-user-timeout=0
LIGHTDM
echo "  ✓ Kullanıcı: user / 123456"

# 11. Ubiquity CSS
echo ""
echo "=== Kurulum Arayüzü CSS ==="
sudo mkdir -p "$CHROOT_DIR/usr/share/ubiquity/gtk"
sudo tee "$CHROOT_DIR/usr/share/ubiquity/gtk/ubiquity.css" > /dev/null << 'CSS'
@define-color bg #ffffff;@define-color fg #1d1d1f;@define-color ac #0071e3;@define-color sc #86868b;@define-color bd rgba(0,0,0,0.08);
*{font-family:-apple-system,sans-serif}
window,.ubiquity,box{background:@bg}
.title{font-size:18px;font-weight:600;color:@fg}
.subtitle{font-size:13px;color:@sc}
button.suggested-action{background:@ac;color:#fff;border-radius:8px;padding:10px 28px;font-weight:500;box-shadow:0 2px 8px rgba(0,113,227,0.2)}
button.suggested-action:hover{background:#0077ed}
progressbar{background:rgba(0,0,0,0.08);border-radius:3px;min-height:6px}
progressbar progress{background:linear-gradient(90deg,#0071e3,#5e5ce6);border-radius:3px}
entry{background:rgba(0,0,0,0.03);border:1.5px solid @bd;border-radius:8px;padding:10px 14px;color:@fg}
entry:focus{border-color:@ac;box-shadow:0 0 0 3px rgba(0,113,227,0.1)}
switch{background:rgba(0,0,0,0.15);border-radius:12px}
switch:checked{background:@ac}
CSS
echo "  ✓ Ubiquity CSS yazıldı"

# 12. Slayt
echo ""
echo "=== Kurulum Slaytı ==="
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
echo "  ✓ Slayt yazıldı"

# 13. Initramfs + GRUB güncelle
echo ""
echo "=== Initramfs ve GRUB Güncelleme ==="
run_chroot "update-initramfs -u" "Initramfs güncelleniyor"
run_chroot "update-grub" "GRUB güncelleniyor"

# 14. Temizlik
run_chroot "apt clean; rm -rf /tmp/* /var/cache/apt/*" "Temizlik"

log "TÜM ÖZELLEŞTİRMELER TAMAMLANDI"

# ═══════════════════════════════════════════════════════════════
# SON KONTROL
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════"
echo "  SON KONTROL"
echo "══════════════════════════════════════════"
echo ""

check_item() {
    local path="$1"
    local name="$2"
    if sudo test -f "$CHROOT_DIR/$path" || sudo test -d "$CHROOT_DIR/$path"; then
        echo -e "  ${G}✓${N} $name"
    else
        echo -e "  ${R}✗${N} $name - EKSİK!"
    fi
}

check_item "usr/share/plymouth/themes/hello/hello.plymouth" "Plymouth hello.plymouth"
check_item "usr/share/plymouth/themes/hello/hello.script" "Plymouth hello.script"
check_item "etc/plymouth/plymouthd.conf" "Plymouth yapılandırması"
check_item "usr/share/themes" "Tema dizini (MacTahoe)"
check_item "etc/os-release" "Sistem adı (os-release)"
check_item "etc/default/grub.d/99-hello.cfg" "GRUB yapılandırması"
check_item "boot/grub/themes/monterey" "Monterey GRUB teması"
check_item "usr/share/ubiquity/gtk/ubiquity.css" "Ubiquity CSS"
check_item "usr/share/ubiquity-slideshow/slides/l10n/tr/welcome.html" "Kurulum slaytı"
check_item "etc/gdm3/custom.conf" "GDM otomatik giriş"
check_item "home/user" "Kullanıcı dizini"

echo ""
echo "Log dosyaları:"
echo "  Ana log: $LOG_FILE"
echo "  Tema log: $THEME_LOG"
echo ""

# ═══════════════════════════════════════════════════════════════
# ISO OLUŞTUR
# ═══════════════════════════════════════════════════════════════
info "Binary ISO oluşturuluyor..."
sudo lb binary 2>&1 | tee -a "$LOG_FILE"
log "Binary tamam"

BINARY_ISO="$WORK/live-image-amd64.iso"
[ ! -f "$BINARY_ISO" ] && BINARY_ISO="$WORK/chroot/binary.hybrid.iso"
[ ! -f "$BINARY_ISO" ] && err "Binary ISO bulunamadı!"

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

FINAL_ISO="/workspaces/Hello-os/hello-os-1.0-amd64.iso"
cd "$TMPISO"
xorriso -as mkisofs \
    -isohybrid-mbr /tmp/isohdpfx.bin \
    -b isolinux/isolinux.bin -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
    -isohybrid-gpt-basdat -r -V "hello os 1.0" \
    -o "$FINAL_ISO" .

rm -rf "$TMPISO"

echo ""
echo -e "${G}╔══════════════════════════════════════════╗${N}"
echo -e "${G}║                                          ║${N}"
echo -e "${G}║   🎉 ISO HAZIR! 🎉                      ║${N}"
echo -e "${G}║                                          ║${N}"
echo -e "${G}║   $FINAL_ISO${N}"
echo -e "${G}║   Boyut: $(du -h "$FINAL_ISO" | cut -f1)                          ║${N}"
echo -e "${G}║                                          ║${N}"
echo -e "${G}║   Log: $LOG_FILE${N}"
echo -e "${G}║   Tema Log: $THEME_LOG${N}"
echo -e "${G}║                                          ║${N}"
echo -e "${G}║   Sağ tık → Download ile indirebilirsin  ║${N}"
echo -e "${G}║                                          ║${N}"
echo -e "${G}╚══════════════════════════════════════════╝${N}"
