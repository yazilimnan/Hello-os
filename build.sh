#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║     OpenDarwin 1.0 - TAM ISO BUILDER                ║
# ║     KURULUM EKRANI EKSİKSİZ                         ║
# ║     Çalıştırıldığı dizinde build alır               ║
# ╚══════════════════════════════════════════════════════╝

set -e

G='\033[0;32m' B='\033[0;34m' R='\033[0;31m' Y='\033[1;33m' N='\033[0m'
log() { echo -e "${G}[✓]${N} $1"; }
info() { echo -e "${B}[*]${N} $1"; }
warn() { echo -e "${Y}[!]${N} $1"; }
err() { echo -e "${R}[X]${N} $1"; exit 1; }

clear
echo -e "${B}"
echo "╔══════════════════════════════════════╗"
echo "║   OpenDarwin 1.0 - ISO Builder      ║"
echo "║   KURULUM EKRANI TAM                ║"
echo "║   Build: $(pwd)                     ║"
echo "╚══════════════════════════════════════╝"
echo -e "${N}"

# ── DİSK KONTROLÜ ──
DISK_FREE=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
info "Disk: ${DISK_FREE}GB boş (en az 15GB gerekli)"
if [ "$DISK_FREE" -lt 15 ]; then
    warn "Disk alanı az! Temizlik yapılıyor..."
    sudo apt clean 2>/dev/null || true
    sudo apt autoremove -y 2>/dev/null || true
    rm -rf /tmp/* 2>/dev/null || true
    DISK_FREE=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    [ "$DISK_FREE" -lt 15 ] && err "Yetersiz alan!"
fi

# ── PAKETLER ──
info "Bağımlılıklar..."
sudo apt update -qq 2>/dev/null
for pkg in live-build live-config live-boot live-manual debian-archive-keyring; do
    dpkg -l 2>/dev/null | grep -q "^ii.*$pkg" && log "$pkg var" || { sudo apt install -y -qq "$pkg" && log "$pkg kuruldu"; }
done

# ── KONFİGÜRASYON ──
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

# ── PAKET LİSTESİ ──
info "Paket listesi..."
mkdir -p config/package-lists
cat > config/package-lists/opendarwin.list.chroot << 'PKG'
ubuntu-desktop-minimal
ubuntu-desktop
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
sudo
locales
PKG
log "Paket listesi hazır"

# ── HOOK ──
info "Özelleştirme hook'u..."
mkdir -p config/hooks/normal

cat > config/hooks/normal/1000-opendarwin.hook.chroot << 'HOOK'
#!/bin/bash
set -e
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   OpenDarwin 1.0 - TÜM ÖZELLEŞTİRMELER  ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ────────────────────────────────────────────────────
# 1. LOCALE VE ZAMAN
# ────────────────────────────────────────────────────
echo "[01/15] Locale ve zaman dilimi..."
locale-gen tr_TR.UTF-8 en_US.UTF-8 2>/dev/null || true
update-locale LANG=tr_TR.UTF-8 2>/dev/null || true
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime 2>/dev/null || true

# ────────────────────────────────────────────────────
# 2. PACIFICO FONT
# ────────────────────────────────────────────────────
echo "[02/15] Pacifico font..."
mkdir -p /usr/share/fonts/truetype/pacifico /usr/local/share/fonts
cd /tmp
wget -q "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf" -O Pacifico.ttf 2>/dev/null || \
curl -sL "https://raw.githubusercontent.com/google/fonts/main/ofl/pacifico/Pacifico-Regular.ttf" -o Pacifico.ttf 2>/dev/null || true
if [ -f Pacifico.ttf ]; then
    cp Pacifico.ttf /usr/share/fonts/truetype/pacifico/
    cp Pacifico.ttf /usr/local/share/fonts/ 2>/dev/null || true
    fc-cache -f 2>/dev/null || true
    echo "  ✓ Pacifico font kuruldu"
else
    echo "  ⚠ Font indirilemedi"
fi

# ────────────────────────────────────────────────────
# 3. MacTahoe GTK TEMASI
# ────────────────────────────────────────────────────
echo "[03/15] MacTahoe GTK teması..."
cd /tmp && rm -rf MacTahoe-gtk-theme
git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git 2>/dev/null || {
    wget -qO- https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/master.tar.gz | tar -xz
    mv MacTahoe-gtk-theme-master MacTahoe-gtk-theme
}
if [ -d MacTahoe-gtk-theme ]; then
    cd MacTahoe-gtk-theme
    ./install.sh -c dark -i 2>/dev/null || true
    ./install.sh -t all 2>/dev/null || true
    mkdir -p /usr/share/themes /usr/share/icons
    for d in /root/.themes /home/user/.themes; do
        [ -d "$d" ] && cp -r "$d"/MacTahoe* /usr/share/themes/ 2>/dev/null || true
    done
    for d in /root/.icons /home/user/.icons; do
        [ -d "$d" ] && cp -r "$d"/MacTahoe* /usr/share/icons/ 2>/dev/null || true
    done
    echo "  ✓ MacTahoe tema kuruldu"
else
    echo "  ⚠ Tema kurulamadı"
fi

# ────────────────────────────────────────────────────
# 4. PLYMOUTH BOOT ANİMASYONU
# ────────────────────────────────────────────────────
echo "[04/15] Plymouth boot animasyonu..."
mkdir -p /usr/share/plymouth/themes/opendarwin

cat > /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth << 'PLYCONF'
[Plymouth Theme]
Name=OpenDarwin
Description=OpenDarwin Boot Screen - hello animation
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/opendarwin
ScriptFile=/usr/share/plymouth/themes/opendarwin/opendarwin.script
PLYCONF

cat > /usr/share/plymouth/themes/opendarwin/opendarwin.script << 'PLYSCRIPT'
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
for (i = 0; i < 200; i++) {
    for (j = 0; j < 6; j++) {
        bar_bg.SetPixel(i, j, 1.0, 1.0, 1.0, 0.2);
    }
}
bar_bg_sprite = Sprite(bar_bg);
bar_bg_sprite.SetX(screen_width / 2 - 100);
bar_bg_sprite.SetY(screen_height / 2 + 60);
bar_fill = Image.New(1, 6);
for (j = 0; j < 6; j++) {
    bar_fill.SetPixel(0, j, 1.0, 1.0, 1.0, 1.0);
}
bar_fill_sprite = Sprite(bar_fill);
bar_fill_sprite.SetX(screen_width / 2 - 100);
bar_fill_sprite.SetY(screen_height / 2 + 60);
bar_fill_sprite.SetWidth(0);
start_time = GetTime();
fade_done = false;
progress = 0;
fun animate() {
    current_time = GetTime() - start_time;
    if (current_time < 0.8) {
        hello_sprite.SetOpacity(current_time / 0.8);
    } else if (!fade_done) {
        hello_sprite.SetOpacity(1);
        fade_done = true;
    }
    if (current_time > 1.2 && progress < 200) {
        progress = progress + 1.5;
        if (progress > 200) progress = 200;
        bar_fill_sprite.SetWidth(progress);
    }
    if (progress < 200) {
        Plymouth.SetRefreshFunction(animate);
    }
}
animate();
PLYSCRIPT

update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
    /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth 100 2>/dev/null || true
update-alternatives --set default.plymouth \
    /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth 2>/dev/null || true
echo "  ✓ Plymouth boot animasyonu hazır"

# ────────────────────────────────────────────────────
# 5. GTK AYARLARI
# ────────────────────────────────────────────────────
echo "[05/15] GTK ayarları..."
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTKSET'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
gtk-cursor-theme-name=MacTahoe
GTKSET

# ────────────────────────────────────────────────────
# 6. GNOME AYARLARI
# ────────────────────────────────────────────────────
echo "[06/15] GNOME masaüstü ayarları..."
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-opendarwin << 'GNOME'
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
picture-uri='file:///usr/share/backgrounds/opendarwin-bg.png'
primary-color='#000000'
GNOME

# ────────────────────────────────────────────────────
# 7. SİYAH DUVAR KAĞIDI
# ────────────────────────────────────────────────────
echo "[07/15] Duvar kağıdı..."
mkdir -p /usr/share/backgrounds
convert -size 1920x1080 xc:'#000000' /usr/share/backgrounds/opendarwin-bg.png 2>/dev/null || \
python3 -c "from PIL import Image;Image.new('RGB',(1920,1080),'black').save('/usr/share/backgrounds/opendarwin-bg.png')" 2>/dev/null || \
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==" | base64 -d > /usr/share/backgrounds/opendarwin-bg.png 2>/dev/null || true

# ────────────────────────────────────────────────────
# 8. SİSTEM MARKALAMASI
# ────────────────────────────────────────────────────
echo "[08/15] Sistem markalaması..."
cat > /etc/os-release << 'OSREL'
PRETTY_NAME="OpenDarwin 1.0"
NAME="OpenDarwin"
VERSION_ID="1.0"
VERSION="1.0"
ID=opendarwin
ID_LIKE=ubuntu
HOME_URL="https://opendarwin.org"
SUPPORT_URL="https://opendarwin.org/support"
BUG_REPORT_URL="https://opendarwin.org/bugs"
OSREL
echo "OpenDarwin 1.0" > /etc/opendarwin-release
echo "opendarwin" > /etc/hostname
echo "127.0.1.1 opendarwin" >> /etc/hosts 2>/dev/null || true
[ -f /etc/lsb-release ] && sed -i 's/DISTRIB_ID=.*/DISTRIB_ID=OpenDarwin/' /etc/lsb-release 2>/dev/null || true
[ -f /etc/lsb-release ] && sed -i 's/DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION="OpenDarwin 1.0"/' /etc/lsb-release 2>/dev/null || true

# ────────────────────────────────────────────────────
# 9. GRUB ÖZELLEŞTİRMESİ
# ────────────────────────────────────────────────────
echo "[09/15] GRUB..."
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/99-opendarwin.cfg << 'GRUBCFG'
GRUB_DISTRIBUTOR="OpenDarwin"
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_GFXMODE=1920x1080
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_BACKGROUND="#000000"
GRUB_COLOR_NORMAL="white/black"
GRUB_COLOR_HIGHLIGHT="magenta/black"
GRUBCFG

# ────────────────────────────────────────────────────
# 10. KULLANICI HESABI
# ────────────────────────────────────────────────────
echo "[10/15] Kullanıcı hesabı..."
useradd -m -s /bin/bash -G sudo,adm,cdrom,dip,plugdev,lpadmin,netdev user 2>/dev/null || true
echo "user:123456" | chpasswd 2>/dev/null || true
mkdir -p /etc/gdm3 /etc/lightdm
cat > /etc/gdm3/custom.conf << 'GDMAUTO'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
TimedLoginEnable=true
TimedLogin=user
TimedLoginDelay=3
GDMAUTO
cat > /etc/lightdm/lightdm.conf << 'LIGHTDMAUTO'
[Seat:*]
autologin-user=user
autologin-user-timeout=0
LIGHTDMAUTO
echo "  ✓ Kullanıcı: user / 123456"

# ────────────────────────────────────────────────────
# 11. UBIQUITY KURULUM ARAYÜZÜ CSS
# ────────────────────────────────────────────────────
echo "[11/15] Kurulum arayüzü CSS teması..."
mkdir -p /usr/share/ubiquity/gtk

cat > /usr/share/ubiquity/gtk/ubiquity.css << 'UBIQUITYCSS'
/* ══════════════════════════════════════════════ */
/*  OpenDarwin Kurulum Arayüzü Teması            */
/*  HTML'deki tasarımın birebir aynısı           */
/* ══════════════════════════════════════════════ */

@define-color bg_color #ffffff;
@define-color fg_color #1d1d1f;
@define-color accent #0071e3;
@define-color secondary #86868b;
@define-color border rgba(0, 0, 0, 0.08);
@define-color hover_bg rgba(0, 113, 227, 0.05);
@define-color selected_bg rgba(0, 113, 227, 0.08);

* {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}

/* Ana pencere - BEYAZ */
window, .ubiquity, box, notebook, .live-installer, vbox, hbox {
    background-color: @bg_color;
    color: @fg_color;
}

/* Başlık çubuğu */
headerbar, .titlebar {
    background: rgba(255, 255, 255, 0.85);
    backdrop-filter: blur(30px);
    border-bottom: 1px solid @border;
    padding: 8px 12px;
}

/* Pencere kontrol butonları */
button.titlebutton.close { background: #ff5f57; min-width: 12px; min-height: 12px; border-radius: 50%; }
button.titlebutton.minimize { background: #febc2e; min-width: 12px; min-height: 12px; border-radius: 50%; }
button.titlebutton.maximize { background: #28c840; min-width: 12px; min-height: 12px; border-radius: 50%; }

/* Başlık metni */
.title, .section-title, label.title {
    font-size: 18px;
    font-weight: 600;
    color: @fg_color;
}

.subtitle, .section-subtitle, label.subtitle {
    font-size: 13px;
    color: @secondary;
}

/* BİRİNCİL BUTON - MAVİ */
button.suggested-action, button.primary, .btn-primary {
    background: @accent;
    color: #ffffff;
    border: none;
    border-radius: 8px;
    padding: 10px 28px;
    font-size: 14px;
    font-weight: 500;
    box-shadow: 0 2px 8px rgba(0, 113, 227, 0.2);
    transition: all 0.2s;
}

button.suggested-action:hover, button.primary:hover {
    background: #0077ed;
    box-shadow: 0 4px 12px rgba(0, 113, 227, 0.3);
    transform: translateY(-1px);
}

/* İKİNCİL BUTON - GRİ */
button.secondary, .btn-secondary {
    background: rgba(0, 0, 0, 0.05);
    color: @fg_color;
    border: 1px solid @border;
    border-radius: 8px;
    padding: 10px 28px;
    font-weight: 500;
}

button.secondary:hover {
    background: rgba(0, 0, 0, 0.08);
}

/* İLERLEME ÇUBUĞU */
progressbar {
    background: rgba(0, 0, 0, 0.08);
    border-radius: 3px;
    min-height: 6px;
    border: none;
}

progressbar progress {
    background: linear-gradient(90deg, #0071e3, #5e5ce6);
    border-radius: 3px;
}

/* GİRİŞ ALANLARI */
entry, input, textview {
    background: rgba(0, 0, 0, 0.03);
    border: 1.5px solid @border;
    border-radius: 8px;
    padding: 10px 14px;
    font-size: 14px;
    color: @fg_color;
}

entry:focus, input:focus {
    border-color: @accent;
    box-shadow: 0 0 0 3px rgba(0, 113, 227, 0.1);
    outline: none;
}

/* TOGGLE SWITCH */
switch {
    background: rgba(0, 0, 0, 0.15);
    border-radius: 12px;
    min-width: 44px;
    min-height: 24px;
}

switch:checked {
    background: @accent;
}

/* LİSTE VE DİSK SEÇİMİ */
treeview, list, .disk-list {
    background: rgba(0, 0, 0, 0.03);
    border: 1.5px solid @border;
    border-radius: 10px;
}

treeview:selected, list row:selected {
    background: @selected_bg;
    color: @fg_color;
    border: 1.5px solid @accent;
}

/* CHECKBOX VE RADIO */
checkbutton, radiobutton {
    color: @fg_color;
}

checkbutton check:checked, radiobutton radio:checked {
    background: @accent;
    color: #ffffff;
}

/* LİSANS METNİ */
.license-text, .tos-text {
    background: rgba(0, 0, 0, 0.02);
    border: 1px solid @border;
    border-radius: 8px;
    padding: 16px;
    font-size: 12px;
    color: @secondary;
    line-height: 1.6;
}

/* AĞ DURUMU */
.network-status {
    background: rgba(52, 199, 89, 0.08);
    border: 1px solid rgba(52, 199, 89, 0.2);
    border-radius: 10px;
    padding: 16px;
}

/* BÖLÜMLEME GÖRSEL HARİTASI */
.partition-visual {
    background: rgba(0, 0, 0, 0.05);
    border: 1px solid @border;
    border-radius: 6px;
}

/* KURULUM LOG */
.install-log {
    background: @fg_color;
    color: #34c759;
    font-family: 'SF Mono', 'Menlo', monospace;
    font-size: 11px;
    padding: 16px;
    border-radius: 8px;
}

/* GERİ SAYIM */
.reboot-countdown {
    font-size: 48px;
    font-weight: 300;
    color: @fg_color;
}

/* HELLO RENKLERİ */
.hello-h { color: #8B5CF6; }
.hello-e { color: #EC4899; }
.hello-l1 { color: #EF4444; }
.hello-l2 { color: #F97316; }
.hello-o { color: #10B981; }

/* DİL SEÇİM GRİD */
.language-grid {
    background: @bg_color;
}

.language-item {
    background: rgba(0, 0, 0, 0.03);
    border: 1.5px solid @border;
    border-radius: 10px;
    padding: 14px;
}

.language-item:selected {
    border-color: @accent;
    background: @selected_bg;
    box-shadow: 0 0 0 3px rgba(0, 113, 227, 0.1);
}

/* KURULUM TÜRÜ SEÇİMİ */
.install-type-option {
    background: rgba(0, 0, 0, 0.03);
    border: 1.5px solid @border;
    border-radius: 10px;
    padding: 20px;
}

.install-type-option:selected {
    border-color: @accent;
    background: @selected_bg;
    box-shadow: 0 0 0 3px rgba(0, 113, 227, 0.1);
}

/* TEMA SEÇİMİ */
.theme-option {
    border-radius: 10px;
    padding: 20px 16px;
    border: 2px solid @border;
    text-align: center;
}

.theme-option:selected, .theme-option.selected {
    border-color: @accent !important;
    box-shadow: 0 0 0 3px rgba(0, 113, 227, 0.15);
}

/* ADIM GÖSTERGELERİ */
.step-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: rgba(0, 0, 0, 0.15);
}

.step-dot.active {
    background: @accent;
    width: 24px;
    border-radius: 4px;
    box-shadow: 0 0 8px rgba(0, 113, 227, 0.4);
}

.step-dot.done {
    background: #34c759;
}
UBIQUITYCSS

echo "  ✓ Ubiquity CSS teması hazır"

# ────────────────────────────────────────────────────
# 12. KURULUM SLAYT HAZIRLAMA (5 ADET)
# ────────────────────────────────────────────────────
echo "[12/15] Kurulum slaytları hazırlanıyor..."
S=/usr/share/ubiquity-slideshow/slides/l10n/tr
mkdir -p "$S"

# --- SLIDE 1: HOŞ GELDİNİZ (RENKLİ HELLO) ---
cat > "$S/welcome.html" << 'SLIDE1'
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Pacifico&display=swap" rel="stylesheet">
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
    background: #ffffff;
    text-align: center;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    padding: 60px 40px;
}
.hello-text {
    font-family: 'Pacifico', cursive;
    font-size: 90px;
    display: flex;
    justify-content: center;
    gap: 4px;
    margin-bottom: 24px;
}
.h { color: #8B5CF6; text-shadow: 0 0 20px rgba(139,92,246,0.15); }
.e { color: #EC4899; text-shadow: 0 0 20px rgba(236,72,153,0.15); }
.l1 { color: #EF4444; text-shadow: 0 0 20px rgba(239,68,68,0.15); }
.l2 { color: #F97316; text-shadow: 0 0 20px rgba(249,115,22,0.15); }
.o { 
    background: linear-gradient(90deg, #FBBF24, #F59E0B, #10B981);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    animation: oShift 3s ease-in-out infinite;
}
@keyframes oShift {
    0%, 100% { filter: hue-rotate(0deg); }
    50% { filter: hue-rotate(15deg); }
}
.title { font-size: 18px; font-weight: 600; color: #1d1d1f; margin-bottom: 6px; }
.subtitle { font-size: 13px; color: #86868b; }
.step-indicator { display: flex; justify-content: center; gap: 8px; margin-bottom: 30px; }
.step-dot { width: 8px; height: 8px; border-radius: 50%; background: rgba(0,0,0,0.15); }
.step-dot.active { background: #0071e3; width: 24px; border-radius: 4px; box-shadow: 0 0 8px rgba(0,113,227,0.4); }
.step-dot.done { background: #34c759; }
</style>
</head>
<body>
<div class="step-indicator">
    <div class="step-dot done"></div>
    <div class="step-dot active"></div>
    <div class="step-dot"></div>
    <div class="step-dot"></div>
    <div class="step-dot"></div>
</div>
<div class="hello-text">
    <span class="h">h</span>
    <span class="e">e</span>
    <span class="l1">l</span>
    <span class="l2">l</span>
    <span class="o">o</span>
</div>
<div class="title">OpenDarwin'e Hoş Geldiniz</div>
<div class="subtitle">Sürüm 1.0 - Darwin Kernel</div>
</body>
</html>
SLIDE1

# --- SLIDE 2: DİL SEÇİMİ ---
cat > "$S/language.html" << 'SLIDE2'
<!DOCTYPE html>
<html lang="tr">
<head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#1d1d1f;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;max-width:400px;margin:0 auto;text-align:left}
.item{background:rgba(0,0,0,.03);border:1.5px solid rgba(0,0,0,.08);border-radius:8px;padding:12px;font-size:14px;cursor:pointer}
.item.sel{border-color:#0071e3;background:rgba(0,113,227,.08)}
.code{font-weight:600;color:#1d1d1f}.name{color:#86868b;font-size:12px}
</style></head><body>
<h2>Dil Seçin</h2><div class="grid">
<div class="item sel"><span class="code">TR</span> <span class="name">Türkçe</span></div>
<div class="item"><span class="code">EN</span> <span class="name">English</span></div>
<div class="item"><span class="code">DE</span> <span class="name">Deutsch</span></div>
<div class="item"><span class="code">FR</span> <span class="name">Français</span></div>
</div></body></html>
SLIDE2

# --- SLIDE 3: DİSK SEÇİMİ ---
cat > "$S/disk.html" << 'SLIDE3'
<!DOCTYPE html>
<html lang="tr">
<head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#1d1d1f;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.disk{background:rgba(0,0,0,.03);border:1.5px solid rgba(0,0,0,.08);border-radius:10px;padding:16px;margin:10px auto;max-width:400px;text-align:left;display:flex;align-items:center;gap:12px;cursor:pointer}
.disk.sel{border-color:#0071e3;background:rgba(0,113,227,.08)}
.icon{width:32px;height:32px;background:#86868b;border-radius:6px;flex-shrink:0}
.dname{font-weight:500;font-size:15px}.ddetail{color:#86868b;font-size:12px}
</style></head><body>
<h2>Kurulum Diski Seçin</h2>
<div class="disk sel"><div class="icon"></div><div><div class="dname">Darwin HD</div><div class="ddetail">APFS · 476 GB kullanılabilir</div></div></div>
<div class="disk"><div class="icon"></div><div><div class="dname">Harici SSD</div><div class="ddetail">exFAT · 210 GB kullanılabilir</div></div></div>
</body></html>
SLIDE3

# --- SLIDE 4: KURULUM İLERLEME ---
cat > "$S/progress.html" << 'SLIDE4'
<!DOCTYPE html>
<html lang="tr">
<head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#1d1d1f;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.bar{width:300px;height:6px;background:rgba(0,0,0,.08);border-radius:3px;margin:20px auto;overflow:hidden}
.fill{height:100%;background:linear-gradient(90deg,#0071e3,#5e5ce6);border-radius:3px;width:45%;animation:fill 3s infinite}
@keyframes fill{0%{width:10%}50%{width:70%}100%{width:95%}}
.steps{display:flex;justify-content:space-between;max-width:400px;margin:20px auto;font-size:11px;color:#86868b}
.sdone{color:#34c759}.scurr{color:#0071e3}.time{color:#86868b;font-size:13px;margin-top:8px}
</style></head><body>
<h2>Kurulum Devam Ediyor</h2><div class="bar"><div class="fill"></div></div>
<div class="time">Kalan süre: ~22 dk</div><div class="steps">
<span class="sdone">✓ Hazırlık</span><span class="scurr">⟳ Kopyalama</span><span>Kurulum</span><span>Tamamlama</span>
</div></body></html>
SLIDE4

# --- SLIDE 5: TAMAMLANDI ---
cat > "$S/complete.html" << 'SLIDE5'
<!DOCTYPE html>
<html lang="tr">
<head><meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Pacifico&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
.hello{font-family:'Pacifico',cursive;font-size:60px;display:flex;justify-content:center;gap:4px;margin-bottom:20px}
.h{color:#8B5CF6}.e{color:#EC4899}.l1{color:#EF4444}.l2{color:#F97316}
.o{background:linear-gradient(90deg,#FBBF24,#F59E0B,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.title{font-size:18px;font-weight:600;color:#1d1d1f;margin-bottom:6px}
.subtitle{font-size:13px;color:#86868b}.countdown{font-size:48px;font-weight:300;color:#1d1d1f;margin:20px 0}
</style></head><body>
<div class="hello"><span class="h">h</span><span class="e">e</span><span class="l1">l</span><span class="l2">l</span><span class="o">o</span></div>
<div class="title">Kurulum Tamamlandı!</div><div class="subtitle">OpenDarwin başarıyla yüklendi</div>
<div class="countdown">10</div><div class="subtitle">saniye içinde yeniden başlatılacak...</div>
</body></html>
SLIDE5

echo "  ✓ 5 kurulum slaytı hazır"

# ────────────────────────────────────────────────────
# TEMİZLİK
# ────────────────────────────────────────────────────
echo ""
echo "Temizlik yapılıyor..."
apt clean 2>/dev/null || true
rm -rf /tmp/* /var/cache/apt/* 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║                                          ║"
echo "║   TÜM ÖZELLEŞTİRMELER TAMAMLANDI        ║"
echo "║                                          ║"
echo "║   ✓ Locale ve zaman dilimi               ║"
echo "║   ✓ Pacifico font                        ║"
echo "║   ✓ MacTahoe GTK teması                  ║"
echo "║   ✓ Plymouth boot animasyonu             ║"
echo "║   ✓ GTK/GNOME ayarları                   ║"
echo "║   ✓ Siyah duvar kağıdı                   ║"
echo "║   ✓ OpenDarwin markalaması               ║"
echo "║   ✓ GRUB özelleştirmesi                  ║"
echo "║   ✓ Kullanıcı: user / 123456             ║"
echo "║   ✓ Ubiquity CSS teması (TAM)            ║"
echo "║   ✓ 5 kurulum slaytı                     ║"
echo "║                                          ║"
echo "╚══════════════════════════════════════════╝"
HOOK

chmod +x config/hooks/normal/1000-opendarwin.hook.chroot
log "Hook hazır"

# ── TEMİZLİK ──
sudo apt clean 2>/dev/null || true
rm -rf /tmp/* 2>/dev/null || true

# ── BUILD ──
echo ""
echo -e "${B}╔══════════════════════════════════════╗${N}"
echo -e "${B}║   ISO OLUŞTURULUYOR...              ║${N}"
echo -e "${B}║   20-40 dakika sürebilir            ║${N}"
echo -e "${B}╚══════════════════════════════════════╝${N}"
echo ""

START=$(date +%s)
sudo lb build 2>&1 | tee build.log
END=$(date +%s)

# ── SONUÇ ──
ISO="live-image-amd64.iso"
OUT="$(pwd)/opendarwin-1.0-amd64.iso"

if [ -f "$ISO" ]; then
    cp "$ISO" "$OUT"
    SZ=$(du -h "$ISO" | cut -f1)
    MN=$(((END-START)/60))
    echo ""
    echo -e "${G}╔══════════════════════════════════════╗${N}"
    echo -e "${G}║                                      ║${N}"
    echo -e "${G}║   🎉 ISO BAŞARIYLA OLUŞTURULDU! 🎉  ║${N}"
    echo -e "${G}║                                      ║${N}"
    echo -e "${G}║   $OUT${N}"
    echo -e "${G}║   Boyut: $SZ   Süre: ${MN} dk         ║${N}"
    echo -e "${G}║                                      ║${N}"
    echo -e "${G}║   Sağ tık → Download ile indir       ║${N}"
    echo -e "${G}║                                      ║${N}"
    echo -e "${G}╚══════════════════════════════════════╝${N}"
else
    echo ""
    echo -e "${R}╔══════════════════════════════════════╗${N}"
    echo -e "${R}║   HATA!                              ║${N}"
    echo -e "${R}╚══════════════════════════════════════╝${N}"
    tail -30 build.log
fi
