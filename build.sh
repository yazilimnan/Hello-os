#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   hello os 1.0 – AMD64 ISO Builder (Düzeltilmiş)               ║
# ║   Ubuntu 24.04 Noble – GitHub Codespaces                       ║
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
echo "║   hello os 1.0 – AMD64 ISO Builder      ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${N}"

# ── Disk kontrolü ──
DISK_FREE=$(df -BG /tmp | awk 'NR==2{print $4}' | sed 's/G//')
info "Disk: ${DISK_FREE} GB (Gerekli: ~15 GB)"
[ "$DISK_FREE" -lt 15 ] && err "En az 15 GB boş alan gerekli!"

# ── Bağımlılıklar ──
info "Gerekli paketler kuruluyor..."
sudo apt update -qq
sudo apt install -y -qq \
    live-build live-config live-boot live-manual debian-archive-keyring \
    isolinux xorriso p7zip-full wget rsync \
    grub-efi-amd64-bin grub-pc-bin grub2-common
log "Paketler hazır"

# ═══════════════════════════════════════════════════════════════
# Syslinux indir (gzip hatası düzeltildi)
# ═══════════════════════════════════════════════════════════════
info "Syslinux indiriliyor..."
SYSLINUX_DIR="/tmp/syslinux-6.03"

if [ ! -d "$SYSLINUX_DIR" ] || [ ! -f "$SYSLINUX_DIR/bios/core/isolinux.bin" ]; then
    rm -rf "$SYSLINUX_DIR" /tmp/syslinux.tar.gz
    
    # Birden fazla kaynak dene
    for URL in \
        "https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz" \
        "https://cdn.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz" \
        "https://mirrors.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz"; do
        
        info "Deneniyor: $URL"
        if wget -q --timeout=60 --tries=3 "$URL" -O /tmp/syslinux.tar.gz 2>/dev/null; then
            if gzip -t /tmp/syslinux.tar.gz 2>/dev/null; then
                log "Arşiv doğrulandı, açılıyor..."
                tar -xzf /tmp/syslinux.tar.gz -C /tmp/ 2>/dev/null
                if [ -f "$SYSLINUX_DIR/bios/core/isolinux.bin" ]; then
                    log "Syslinux hazır"
                    break
                fi
            fi
        fi
        warn "Bu kaynak başarısız, diğeri deneniyor..."
        rm -f /tmp/syslinux.tar.gz
    done
    
    if [ ! -f "$SYSLINUX_DIR/bios/core/isolinux.bin" ]; then
        err "Syslinux indirilemedi! İnternet bağlantını kontrol et."
    fi
else
    log "Syslinux zaten var"
fi

# ═══════════════════════════════════════════════════════════════
# AMD64 ISO Build
# ═══════════════════════════════════════════════════════════════
WORK="/tmp/hello-amd64-build"
sudo rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"
log "Çalışma dizini: $WORK"

# Live-build config
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
    --apt-indices false
log "Konfigürasyon tamam"

# Paket listesi
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
wireless-tools
wpasupplicant
git
wget
curl
plymouth
plymouth-themes
plymouth-x11
gnome-tweaks
gnome-themes-extra
gtk2-engines-murrine
gtk2-engines-pixbuf
imagemagick
python3
python3-pip
sudo
locales
tzdata
PKG

# Build: Bootstrap + Chroot
info "Bootstrap başlıyor (bu uzun sürebilir)..."
sudo lb bootstrap 2>&1 | tee /tmp/bootstrap.log
log "Bootstrap tamam"

info "Chroot başlıyor (paketler indiriliyor)..."
sudo lb chroot 2>&1 | tee /tmp/chroot.log
log "Chroot tamam"

# ═══════════════════════════════════════════════════════════════
# MANUEL CHROOT ÖZELLEŞTİRME (Hook yerine direkt müdahale)
# ═══════════════════════════════════════════════════════════════
CHROOT_DIR="$WORK/chroot"
info "Chroot'a manuel müdahale ediliyor..."

run_chroot() {
    sudo chroot "$CHROOT_DIR" /bin/bash -c "$1" 2>/dev/null || warn "Komut başarısız (önemsiz olabilir): $1"
}

# --- Locale ---
run_chroot "locale-gen tr_TR.UTF-8 en_US.UTF-8"
run_chroot "update-locale LANG=tr_TR.UTF-8"
run_chroot "ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime"

# --- Pacifico font ---
run_chroot "mkdir -p /usr/share/fonts/truetype/pacifico"
run_chroot "cd /tmp && wget -q 'https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf' -O Pacifico.ttf && cp Pacifico.ttf /usr/share/fonts/truetype/pacifico/ && fc-cache -f"

# --- MacTahoe teması ---
run_chroot "cd /tmp && rm -rf MacTahoe-gtk-theme && (git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git 2>/dev/null || wget -qO- https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/master.tar.gz | tar -xz && mv MacTahoe-gtk-theme-master MacTahoe-gtk-theme)"
run_chroot "[ -d /tmp/MacTahoe-gtk-theme ] && cd /tmp/MacTahoe-gtk-theme && ./install.sh -c dark -i"
run_chroot "mkdir -p /usr/share/themes /usr/share/icons"
run_chroot "[ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/"

# --- Plymouth: Tüm temaları sil, sadece hello bırak ---
run_chroot "rm -rf /usr/share/plymouth/themes/*"
run_chroot "mkdir -p /usr/share/plymouth/themes/hello"

# Plymouth .plymouth
sudo tee "$CHROOT_DIR/usr/share/plymouth/themes/hello/hello.plymouth" > /dev/null << 'PLYCONF'
[Plymouth Theme]
Name=hello
Description=hello Boot Screen
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/hello
ScriptFile=/usr/share/plymouth/themes/hello/hello.script
PLYCONF

# Plymouth .script (hello animasyonu)
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

run_chroot "plymouth-set-default-theme hello"
run_chroot "update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/hello/hello.plymouth 200"
run_chroot "update-alternatives --set default.plymouth /usr/share/plymouth/themes/hello/hello.plymouth"

sudo mkdir -p "$CHROOT_DIR/etc/plymouth"
sudo tee "$CHROOT_DIR/etc/plymouth/plymouthd.conf" > /dev/null << 'PLYDCONF'
[Daemon]
Theme=hello
ShowDelay=0
PLYDCONF

# --- Sistem markalaması ---
sudo tee "$CHROOT_DIR/etc/os-release" > /dev/null << 'OSRELEASE'
PRETTY_NAME="hello os"
NAME="hello os"
VERSION_ID="1.0"
VERSION="1.0"
ID=hello-os
ID_LIKE=ubuntu
HOME_URL="https://hello-os.org"
OSRELEASE
run_chroot "echo 'hello os 1.0' > /etc/hello-release"
run_chroot "echo 'hello-os' > /etc/hostname"

# --- GTK ---
sudo mkdir -p "$CHROOT_DIR/etc/gtk-3.0"
sudo tee "$CHROOT_DIR/etc/gtk-3.0/settings.ini" > /dev/null << 'GTKSET'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
gtk-cursor-theme-name=MacTahoe
GTKSET

# --- GNOME ---
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

# --- Duvar kağıdı ---
run_chroot "mkdir -p /usr/share/backgrounds"
run_chroot "convert -size 1920x1080 xc:'#000000' /usr/share/backgrounds/hello-bg.png 2>/dev/null || python3 -c \"from PIL import Image;Image.new('RGB',(1920,1080),'black').save('/usr/share/backgrounds/hello-bg.png')\" 2>/dev/null || true"

# --- GRUB + Monterey teması ---
run_chroot "mkdir -p /etc/default/grub.d"
run_chroot "cd /tmp && rm -rf monterey-grub-theme && git clone --depth=1 https://github.com/sandesh236/monterey-grub-theme.git 2>/dev/null && cd monterey-grub-theme && if [ -f install.sh ]; then chmod +x install.sh && ./install.sh; else mkdir -p /boot/grub/themes/monterey && cp -r . /boot/grub/themes/monterey/; fi"

sudo tee "$CHROOT_DIR/etc/default/grub.d/99-hello.cfg" > /dev/null << 'GRUB'
GRUB_DISTRIBUTOR="hello os"
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash plymouth.theme=hello"
GRUB_GFXMODE=1920x1080
GRUB_THEME="/boot/grub/themes/monterey/theme.txt"
GRUB

# --- Kullanıcı ---
run_chroot "useradd -m -s /bin/bash -G sudo,adm,cdrom,dip,plugdev,lpadmin,netdev user"
run_chroot "echo 'user:123456' | chpasswd"

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

# --- Ubiquity CSS ---
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

# --- Slayt ---
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

# --- Initramfs güncelle ---
run_chroot "update-initramfs -u"
run_chroot "update-grub"

# --- Temizlik ---
run_chroot "apt clean; rm -rf /tmp/* /var/cache/apt/*"

log "Chroot özelleştirme tamamlandı"

# ═══════════════════════════════════════════════════════════════
# DEĞİŞİKLİK KONTROLÜ
# ═══════════════════════════════════════════════════════════════
info "Değişiklikler kontrol ediliyor..."
echo ""
echo "=== Plymouth hello ==="
ls -la "$CHROOT_DIR/usr/share/plymouth/themes/hello/" 2>/dev/null || echo "YOK!"
echo ""
echo "=== Plymouth ubuntu-logo (YOK OLMALI) ==="
ls -la "$CHROOT_DIR/usr/share/plymouth/themes/ubuntu-logo/" 2>/dev/null && echo "HALA VAR! SORUN VAR!" || echo "ubuntu-logo YOK (başarılı!)"
echo ""
echo "=== Sistem adı ==="
cat "$CHROOT_DIR/etc/os-release"
echo ""
echo "=== Slayt ==="
head -3 "$CHROOT_DIR/usr/share/ubiquity-slideshow/slides/l10n/tr/welcome.html" 2>/dev/null || echo "YOK"

# ═══════════════════════════════════════════════════════════════
# ISO OLUŞTUR
# ═══════════════════════════════════════════════════════════════
info "Binary ISO oluşturuluyor..."
sudo lb binary 2>&1 | tee /tmp/binary.log
log "Binary tamam"

# Boot dosyalarını ekle
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
[ -z "$KERNEL" ] && err "Kernel bulunamadı!"

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
MBR="/tmp/isohdpfx.bin"
info "Final ISO oluşturuluyor..."
cd "$TMPISO"
xorriso -as mkisofs \
    -isohybrid-mbr "$MBR" \
    -b isolinux/isolinux.bin -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
    -isohybrid-gpt-basdat -r -V "hello os 1.0" \
    -o "$FINAL_ISO" .

log "SON ISO: $FINAL_ISO"
ls -lh "$FINAL_ISO"

rm -rf "$TMPISO"

echo ""
echo -e "${G}╔══════════════════════════════════════════╗${N}"
echo -e "${G}║                                          ║${N}"
echo -e "${G}║   🎉 ISO HAZIR! 🎉                      ║${N}"
echo -e "${G}║                                          ║${N}"
echo -e "${G}║   $FINAL_ISO${N}"
echo -e "${G}║   Boyut: $(du -h "$FINAL_ISO" | cut -f1)                          ║${N}"
echo -e "${G}║                                          ║${N}"
echo -e "${G}║   Sağ tık → Download ile indirebilirsin  ║${N}"
echo -e "${G}║                                          ║${N}"
echo -e "${G}╚══════════════════════════════════════════╝${N}"
