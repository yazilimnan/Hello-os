#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║   OpenDarwin 1.0 - GNOME + Wayland + Monterey GRUB Theme   ║
# ║   Ubuntu 24.04 Noble – GitHub Codespaces                   ║
# ╚══════════════════════════════════════════════════════════════╝

set -e
G='\033[0;32m' B='\033[0;34m' R='\033[0;31m' N='\033[0m'
log() { echo -e "${G}[✓]${N} $1"; }
info() { echo -e "${B}[*]${N} $1"; }
err() { echo -e "${R}[X]${N} $1"; exit 1; }

clear
echo -e "${B}"
echo "╔══════════════════════════════════════════╗"
echo "║   OpenDarwin 1.0 ISO Builder            ║"
echo "║   GNOME + Wayland + Monterey GRUB       ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${N}"

# ── Disk kontrolü ──
DISK_FREE=$(df -BG /tmp | awk 'NR==2{print $4}' | sed 's/G//')
info "Disk: ${DISK_FREE} GB"
[ "$DISK_FREE" -lt 15 ] && err "En az 15 GB gerekli!"

# ── Çalışma dizini ──
WORK="/tmp/opendarwin-build"
sudo rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"
log "Çalışma: $WORK"

# ── Paketler ──
info "Bağımlılıklar..."
sudo apt update -qq
sudo apt install -y -qq live-build live-config live-boot live-manual debian-archive-keyring

# ── Konfigürasyon ──
info "Konfigürasyon..."
sudo lb config \
    --architecture amd64 \
    --distribution noble \
    --binary-images iso-hybrid \
    --mode ubuntu \
    --archive-areas "main restricted universe multiverse" \
    --parent-archive-areas "main restricted universe multiverse" \
    --bootappend-live "boot=live components splash quiet" \
    --iso-application "OpenDarwin 1.0" \
    --iso-volume "OpenDarwin 1.0" \
    --iso-publisher "OpenDarwin Project" \
    --memtest none \
    --apt-options "--yes" \
    --debian-installer false \
    --bootloader grub-efi \
    --cache false \
    --apt-indices false
log "Konfigürasyon tamam"

# ── Dizinler ──
mkdir -p config/package-lists config/hooks/normal

# ── Paket listesi (gnome-session-wayland YOK) ──
cat > config/package-lists/opendarwin.list.chroot << 'PKG'
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
sassc
meson
libglib2.0-dev
libxml2-utils
imagemagick
python3
python3-pip
sudo
locales
tzdata
PKG

# ── Hook ──
info "Hook oluşturuluyor..."
cat > config/hooks/normal/1000-opendarwin-complete.hook.chroot << 'FULLHOOK'
#!/bin/bash
set -e
echo "OpenDarwin 1.0 - Özelleştirme"

# 1. Locale
locale-gen tr_TR.UTF-8 en_US.UTF-8 2>/dev/null || true
update-locale LANG=tr_TR.UTF-8 2>/dev/null || true
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime 2>/dev/null || true

# 2. Pacifico font
mkdir -p /usr/share/fonts/truetype/pacifico
cd /tmp
wget -q "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf" -O Pacifico.ttf 2>/dev/null || \
curl -sL "https://raw.githubusercontent.com/google/fonts/main/ofl/pacifico/Pacifico-Regular.ttf" -o Pacifico.ttf 2>/dev/null || true
[ -f Pacifico.ttf ] && cp Pacifico.ttf /usr/share/fonts/truetype/pacifico/ && fc-cache -f

# 3. MacTahoe GTK
cd /tmp && rm -rf MacTahoe-gtk-theme
git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git 2>/dev/null || {
    wget -qO- https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/master.tar.gz | tar -xz
    mv MacTahoe-gtk-theme-master MacTahoe-gtk-theme
}
[ -d MacTahoe-gtk-theme ] && cd MacTahoe-gtk-theme && ./install.sh -c dark -i 2>/dev/null || true
mkdir -p /usr/share/themes /usr/share/icons
[ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/ 2>/dev/null || true

# 4. Plymouth
mkdir -p /usr/share/plymouth/themes/opendarwin
cat > /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth << 'PLYCONF'
[Plymouth Theme]
Name=OpenDarwin
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/opendarwin
ScriptFile=/usr/share/plymouth/themes/opendarwin/opendarwin.script
PLYCONF

cat > /usr/share/plymouth/themes/opendarwin/opendarwin.script << 'PLYANIM'
screen_width=Window.GetWidth();screen_height=Window.GetHeight()
bg=Image.New(1,1);bg.SetPixel(0,0,0,0,0,1);bg_sprite=Sprite(bg)
bg_sprite.SetWidth(screen_width);bg_sprite.SetHeight(screen_height)
hello=Image.Text("hello",0,0);hello.SetFont("Pacifico 72");hello_sprite=Sprite(hello)
hello_sprite.SetX(screen_width/2-hello.GetWidth()/2)
hello_sprite.SetY(screen_height/2-hello.GetHeight()/2-50);hello_sprite.SetOpacity(0)
bar_bg=Image.New(200,6)
for i=0,199 do for j=0,5 do bar_bg.SetPixel(i,j,1,1,1,0.2) end end
bar_bg_sprite=Sprite(bar_bg);bar_bg_sprite.SetX(screen_width/2-100);bar_bg_sprite.SetY(screen_height/2+60)
bar_fill=Image.New(1,6);for j=0,5 do bar_fill.SetPixel(0,j,1,1,1,1) end
bar_fill_sprite=Sprite(bar_fill);bar_fill_sprite.SetX(screen_width/2-100);bar_fill_sprite.SetY(screen_height/2+60)
bar_fill_sprite.SetWidth(0);start_time=GetTime();fade_done=false;progress=0
fun animate()t=GetTime()-start_time
if t<0.8 then hello_sprite.SetOpacity(t/0.8)elseif not fade_done then hello_sprite.SetOpacity(1);fade_done=true end
if t>1.2 and progress<200 then progress=progress+1.5;if progress>200 then progress=200 end;bar_fill_sprite.SetWidth(progress)end
if progress<200 then Plymouth.SetRefreshFunction(animate)end end
animate()
PLYANIM

update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth 100 2>/dev/null
update-alternatives --set default.plymouth /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth 2>/dev/null

# 5. GTK
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTKSET'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
GTKSET

# 6. GNOME
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-opendarwin << 'GNOME'
[org/gnome/desktop/interface]
gtk-theme='MacTahoe'
icon-theme='MacTahoe'
font-name='Pacifico 11'
[org/gnome/desktop/wm/preferences]
theme='MacTahoe'
[org/gnome/shell/extensions/user-theme]
name='MacTahoe'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/opendarwin-bg.png'
primary-color='#000000'
GNOME

# 7. Duvar kağıdı
mkdir -p /usr/share/backgrounds
convert -size 1920x1080 xc:'#000000' /usr/share/backgrounds/opendarwin-bg.png 2>/dev/null || python3 -c "from PIL import Image;Image.new('RGB',(1920,1080),'black').save('/usr/share/backgrounds/opendarwin-bg.png')" 2>/dev/null || true

# 8. Sistem
cat > /etc/os-release << 'OSRELEASE'
PRETTY_NAME="OpenDarwin 1.0"
NAME="OpenDarwin"
VERSION_ID="1.0"
ID=opendarwin
ID_LIKE=ubuntu
OSRELEASE
echo "OpenDarwin 1.0" > /etc/opendarwin-release
echo "opendarwin" > /etc/hostname

# 9. GRUB + Monterey teması
mkdir -p /etc/default/grub.d
cd /tmp
git clone --depth=1 https://github.com/sandesh236/monterey-grub-theme.git 2>/dev/null || true
[ -d monterey-grub-theme ] && mkdir -p /boot/grub/themes && cp -r monterey-grub-theme /boot/grub/themes/opendarwin-grub

cat > /etc/default/grub.d/99-opendarwin.cfg << 'GRUB'
GRUB_DISTRIBUTOR="OpenDarwin"
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_THEME="/boot/grub/themes/opendarwin-grub/theme.txt"
GRUB

# 10. Kullanıcı
useradd -m -s /bin/bash -G sudo user 2>/dev/null || true
echo "user:123456" | chpasswd 2>/dev/null || true
mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
WaylandEnable=true
GDM

# 11. Ubiquity CSS
mkdir -p /usr/share/ubiquity/gtk
cat > /usr/share/ubiquity/gtk/ubiquity.css << 'CSS'
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

# 12. Slaytlar
S=/usr/share/ubiquity-slideshow/slides/l10n/tr
mkdir -p "$S"
cat > "$S/welcome.html" << 'EOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
body{background:#fff;text-align:center;font-family:sans-serif;padding:60px}
.hello{font-size:90px;display:flex;justify-content:center;gap:4px;margin-bottom:24px}
.h{color:#8B5CF6}.e{color:#EC4899}.l1{color:#EF4444}.l2{color:#F97316}
.o{background:linear-gradient(90deg,#FBBF24,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.title{font-size:18px;font-weight:600;color:#1d1d1f}.subtitle{font-size:13px;color:#86868b}
</style></head><body>
<div class="hello"><span class="h">h</span><span class="e">e</span><span class="l1">l</span><span class="l2">l</span><span class="o">o</span></div>
<div class="title">OpenDarwin'e Hoş Geldiniz</div><div class="subtitle">Sürüm 1.0</div>
</body></html>
EOF

apt clean 2>/dev/null || true
rm -rf /tmp/*
echo "Tamam"
FULLHOOK

chmod +x config/hooks/normal/1000-opendarwin-complete.hook.chroot
log "Hook hazır"

# ── Build ──
echo ""
echo -e "${B}╔══════════════════════════════════════╗${N}"
echo -e "${B}║   ISO OLUŞTURULUYOR...              ║${N}"
echo -e "${B}╚══════════════════════════════════════╝${N}"
echo ""

START=$(date +%s)
sudo lb build 2>&1 | tee /tmp/build-opendarwin.log
END=$(date +%s)
BUILD_TIME=$(( (END - START) / 60 ))

# ── Sonuç ──
ISO_FILE="live-image-amd64.iso"
FINAL_ISO="/workspaces/Hello-os/opendarwin-1.0-amd64.iso"

if [ -f "$ISO_FILE" ]; then
    cp "$ISO_FILE" "$FINAL_ISO"
    sudo cp "$ISO_FILE" /root/opendarwin.iso 2>/dev/null || true
    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
    
    echo ""
    echo -e "${G}╔══════════════════════════════════════╗${N}"
    echo -e "${G}║   ISO HAZIR!                         ║${N}"
    echo -e "${G}║   $FINAL_ISO${N}"
    echo -e "${G}║   Boyut: $ISO_SIZE   Süre: ${BUILD_TIME} dk  ║${N}"
    echo -e "${G}║   Kullanıcı: user / 123456           ║${N}"
    echo -e "${G}║   Oturum: GNOME (Wayland)            ║${N}"
    echo -e "${G}║   GRUB: Monterey teması              ║${N}"
    echo -e "${G}║   Sağ tık → Download                 ║${N}"
    echo -e "${G}╚══════════════════════════════════════╝${N}"
else
    echo -e "${R}╔══════════════════════════════════════╗${N}"
    echo -e "${R}║   ISO OLUŞTURULAMADI!               ║${N}"
    echo -e "${R}╚══════════════════════════════════════╝${N}"
    tail -30 /tmp/build-opendarwin.log
fi
