#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   hello os – GNOME + Wayland + Plymouth + Monterey GRUB        ║
# ║   Ubuntu 24.04 Noble – GitHub Codespaces (Telifsiz Sürüm)      ║
# ╚══════════════════════════════════════════════════════════════════╝

set -e
G='\033[0;32m' B='\033[0;34m' R='\033[0;31m' N='\033[0m'
log()   { echo -e "${G}[✓]${N} $1"; }
info()  { echo -e "${B}[*]${N} $1"; }
err()   { echo -e "${R}[X]${N} $1"; exit 1; }

clear
echo -e "${B}"
echo "╔══════════════════════════════════════════╗"
echo "║   hello os ISO Builder                  ║"
echo "║   GNOME + Wayland + Monterey GRUB       ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${N}"

# ── Disk kontrolü ──
DISK_FREE=$(df -BG /tmp | awk 'NR==2{print $4}' | sed 's/G//')
info "Disk: ${DISK_FREE} GB"
[ "$DISK_FREE" -lt 18 ] && err "En az 18 GB boş alan gerekli!"

# ── Çalışma dizini ──
WORK="/tmp/opendarwin-build"
sudo rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"
log "Çalışma dizini: $WORK"

# ── Bağımlılıklar ──
info "Gerekli paketler kuruluyor..."
sudo apt update -qq
sudo apt install -y -qq \
    live-build live-config live-boot live-manual debian-archive-keyring \
    isolinux syslinux-common xorriso p7zip-full wget \
    grub-efi-amd64-bin grub-pc-bin grub2-common
log "Paketler hazır"

# ── Live‑build konfigürasyonu ──
info "Live‑build yapılandırılıyor..."
sudo lb config \
    --architecture amd64 \
    --distribution noble \
    --binary-images iso-hybrid \
    --mode ubuntu \
    --archive-areas "main restricted universe multiverse" \
    --parent-archive-areas "main restricted universe multiverse" \
    --bootappend-live "boot=live components splash quiet" \
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

# ── Dizinler ──
mkdir -p config/package-lists config/hooks/normal

# ── Paket listesi (Wayland destekli GNOME) ──
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

# ── Özelleştirme hook’u (TÜM özellikler) ──
info "Hook oluşturuluyor..."
cat > config/hooks/normal/1000-opendarwin-complete.hook.chroot << 'FULLHOOK'
#!/bin/bash
set -e
echo "hello os – Özelleştirme"

# 1. Locale
echo "[01/16] Locale..."
locale-gen tr_TR.UTF-8 en_US.UTF-8 2>/dev/null || true
update-locale LANG=tr_TR.UTF-8 2>/dev/null || true
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime 2>/dev/null || true

# 2. Pacifico font
echo "[02/16] Pacifico font..."
mkdir -p /usr/share/fonts/truetype/pacifico
cd /tmp
wget -q "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf" -O Pacifico.ttf 2>/dev/null || \
curl -sL "https://raw.githubusercontent.com/google/fonts/main/ofl/pacifico/Pacifico-Regular.ttf" -o Pacifico.ttf 2>/dev/null || true
[ -f Pacifico.ttf ] && cp Pacifico.ttf /usr/share/fonts/truetype/pacifico/ && fc-cache -f

# 3. MacTahoe GTK teması
echo "[03/16] MacTahoe teması..."
cd /tmp && rm -rf MacTahoe-gtk-theme
git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git 2>/dev/null || {
    wget -qO- https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/master.tar.gz | tar -xz
    mv MacTahoe-gtk-theme-master MacTahoe-gtk-theme
}
[ -d MacTahoe-gtk-theme ] && cd MacTahoe-gtk-theme && ./install.sh -c dark -i 2>/dev/null || true
mkdir -p /usr/share/themes /usr/share/icons
[ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/ 2>/dev/null || true

# 4. Plymouth boot animasyonu (hello)
echo "[04/16] Plymouth boot animasyonu..."
mkdir -p /usr/share/plymouth/themes/opendarwin
cat > /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth << 'PLYCONF'
[Plymouth Theme]
Name=hello
Description=hello Boot Screen
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/opendarwin
ScriptFile=/usr/share/plymouth/themes/opendarwin/opendarwin.script
PLYCONF

cat > /usr/share/plymouth/themes/opendarwin/opendarwin.script << 'PLYANIM'
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
PLYANIM

update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
    /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth 100 2>/dev/null || true
update-alternatives --set default.plymouth \
    /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth 2>/dev/null || true

# 5. GTK ayarları
echo "[05/16] GTK ayarları..."
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTKSET'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
gtk-cursor-theme-name=MacTahoe
GTKSET

# 6. GNOME masaüstü ayarları
echo "[06/16] GNOME ayarları..."
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
picture-uri-dark='file:///usr/share/backgrounds/opendarwin-bg.png'
primary-color='#000000'
GNOME

# 7. Siyah duvar kağıdı
echo "[07/16] Duvar kağıdı..."
mkdir -p /usr/share/backgrounds
convert -size 1920x1080 xc:'#000000' /usr/share/backgrounds/opendarwin-bg.png 2>/dev/null || \
python3 -c "from PIL import Image;Image.new('RGB',(1920,1080),'black').save('/usr/share/backgrounds/opendarwin-bg.png')" 2>/dev/null || true

# 8. Sistem markalaması (hello os)
echo "[08/16] Sistem markalaması..."
cat > /etc/os-release << 'OSRELEASE'
PRETTY_NAME="hello os"
NAME="hello os"
VERSION_ID="1.0"
VERSION="1.0"
ID=hello-os
ID_LIKE=ubuntu
HOME_URL="https://hello-os.org"
OSRELEASE
echo "hello os 1.0" > /etc/opendarwin-release
echo "hello-os" > /etc/hostname
echo "127.0.1.1 hello-os" >> /etc/hosts 2>/dev/null || true
[ -f /etc/lsb-release ] && sed -i 's/DISTRIB_ID=.*/DISTRIB_ID=hello-os/' /etc/lsb-release 2>/dev/null || true
[ -f /etc/lsb-release ] && sed -i 's/DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION="hello os 1.0"/' /etc/lsb-release 2>/dev/null || true

# 9. GRUB + Monterey teması (install.sh ile)
echo "[09/16] GRUB + Monterey teması..."
mkdir -p /etc/default/grub.d
cd /tmp
rm -rf monterey-grub-theme
git clone --depth=1 https://github.com/sandesh236/monterey-grub-theme.git 2>/dev/null || true
if [ -d monterey-grub-theme ]; then
    cd monterey-grub-theme
    if [ -f install.sh ]; then
        chmod +x install.sh
        ./install.sh
    else
        mkdir -p /boot/grub/themes/monterey
        cp -r . /boot/grub/themes/monterey/
    fi
fi

cat > /etc/default/grub.d/99-opendarwin.cfg << 'GRUB'
GRUB_DISTRIBUTOR="hello os"
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_GFXMODE=1920x1080
GRUB_THEME="/boot/grub/themes/monterey/theme.txt"
GRUB

# 10. Kullanıcı hesabı (Wayland)
echo "[10/16] Kullanıcı hesabı..."
useradd -m -s /bin/bash -G sudo,adm,cdrom,dip,plugdev,lpadmin,netdev user 2>/dev/null || true
echo "user:123456" | chpasswd 2>/dev/null || true
mkdir -p /etc/gdm3 /etc/lightdm
cat > /etc/gdm3/custom.conf << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
WaylandEnable=true
GDM
cat > /etc/lightdm/lightdm.conf << 'LIGHTDM'
[Seat:*]
autologin-user=user
autologin-user-timeout=0
LIGHTDM

# 11. Ubiquity CSS (beyaz kurulum arayüzü – TAM)
echo "[11/16] Kurulum arayüzü CSS..."
mkdir -p /usr/share/ubiquity/gtk

cat > /usr/share/ubiquity/gtk/ubiquity.css << 'CSS'
@define-color bg #ffffff;
@define-color fg #1d1d1f;
@define-color ac #0071e3;
@define-color sc #86868b;
@define-color bd rgba(0,0,0,0.08);
@define-color hb rgba(0,113,227,0.05);
@define-color sb rgba(0,113,227,0.08);

* { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }

window, .ubiquity, box, notebook, .live-installer, dialog { background-color: @bg; color: @fg; }

.titlebar, headerbar {
    background: rgba(255,255,255,0.85);
    backdrop-filter: blur(30px);
    border-bottom: 1px solid @bd;
    padding: 12px 16px; min-height: 36px;
}
button.titlebutton.close { background: #ff5f57; min-width: 12px; min-height: 12px; border-radius: 50%; }
button.titlebutton.minimize { background: #febc2e; min-width: 12px; min-height: 12px; border-radius: 50%; }
button.titlebutton.maximize { background: #28c840; min-width: 12px; min-height: 12px; border-radius: 50%; }

.title, .section-title, label.title { font-size: 18px; font-weight: 600; color: @fg; }
.subtitle, .section-subtitle, label.subtitle { font-size: 13px; color: @sc; }

button.suggested-action, button.primary {
    background: @ac; color: #fff; border-radius: 8px;
    padding: 10px 28px; font-weight: 500; border: none;
    box-shadow: 0 2px 8px rgba(0,113,227,0.2);
}
button.suggested-action:hover, button.primary:hover {
    background: #0077ed; box-shadow: 0 4px 12px rgba(0,113,227,0.3); transform: translateY(-1px);
}
button.secondary {
    background: rgba(0,0,0,0.05); color: @fg;
    border: 1px solid @bd; border-radius: 8px; padding: 10px 28px;
}
button.secondary:hover { background: rgba(0,0,0,0.08); }

progressbar { background: rgba(0,0,0,0.08); border-radius: 3px; min-height: 6px; }
progressbar progress { background: linear-gradient(90deg, #0071e3, #5e5ce6); border-radius: 3px; }

entry, input {
    background: rgba(0,0,0,0.03); border: 1.5px solid @bd;
    border-radius: 8px; padding: 10px 14px; font-size: 14px; color: @fg;
}
entry:focus, input:focus { border-color: @ac; box-shadow: 0 0 0 3px rgba(0,113,227,0.1); outline: none; }

switch { background: rgba(0,0,0,0.15); border-radius: 12px; min-width: 44px; min-height: 24px; }
switch:checked { background: @ac; }

treeview, .disk-list, list {
    background: rgba(0,0,0,0.03); border: 1.5px solid @bd; border-radius: 10px; padding: 4px;
}
treeview:selected, list row:selected { background: @sb; color: @fg; }

.license-text { background: rgba(0,0,0,0.02); border: 1px solid @bd; border-radius: 8px; padding: 16px; font-size: 12px; color: @sc; line-height: 1.6; }
.network-status { background: rgba(52,199,89,0.08); border: 1px solid rgba(52,199,89,0.2); border-radius: 10px; padding: 16px; }
.partition-visual { background: rgba(0,0,0,0.05); border: 1px solid @bd; border-radius: 6px; min-height: 30px; }
.install-log { background: @fg; color: #34c759; font-family: monospace; font-size: 11px; padding: 16px; border-radius: 8px; }
.reboot-countdown { font-size: 48px; font-weight: 300; color: @fg; margin: 20px 0; }

.step-indicator { margin: 20px 0; }
.step-dot { min-width: 8px; min-height: 8px; border-radius: 50%; background: rgba(0,0,0,0.15); margin: 0 4px; }
.step-dot.active { background: @ac; min-width: 24px; border-radius: 4px; box-shadow: 0 0 8px rgba(0,113,227,0.4); }
.step-dot.done { background: #34c759; }

.language-grid { margin: 16px 0; }
.language-option, .language-item {
    background: rgba(0,0,0,0.03); border: 1.5px solid @bd;
    border-radius: 10px; padding: 14px; margin: 4px;
}
.language-option:hover { border-color: @ac; background: @hb; }
.language-option:checked, .language-option.selected {
    border-color: @ac; background: @sb; box-shadow: 0 0 0 3px rgba(0,113,227,0.1);
}

.theme-option { border-radius: 10px; padding: 20px 16px; border: 2px solid transparent; text-align: center; margin: 4px; }
.theme-option.light { background: #ffffff; border-color: @bd; }
.theme-option.dark { background: @fg; color: #ffffff; }
.theme-option.auto { background: linear-gradient(135deg, #ffffff 50%, @fg 50%); }
.theme-option:checked, .theme-option.selected { border-color: @ac !important; box-shadow: 0 0 0 3px rgba(0,113,227,0.15); }

checkbutton, radiobutton { color: @fg; }
checkbutton:checked, radiobutton:checked { color: @ac; }
CSS

mkdir -p /etc/ubiquity
cat > /etc/ubiquity/ubiquity.conf << 'UBCNF'
[Ubiquity]
theme=MacTahoe
gtk_theme=MacTahoe
icon_theme=MacTahoe
UBCNF

# 12. Kurulum slaytları (5 adet – TAM HTML)
echo "[12/16] Kurulum slaytları..."
S=/usr/share/ubiquity-slideshow/slides/l10n/tr
mkdir -p "$S"

cat > "$S/welcome.html" << 'SLIDE1'
<!DOCTYPE html>
<html lang="tr">
<head><meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Pacifico&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;text-align:center;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;padding:60px 40px}
.hello-text{font-family:'Pacifico',cursive;font-size:90px;display:flex;justify-content:center;gap:4px;margin-bottom:24px}
.h{color:#8B5CF6;text-shadow:0 0 20px rgba(139,92,246,.15)}
.e{color:#EC4899;text-shadow:0 0 20px rgba(236,72,153,.15)}
.l1{color:#EF4444;text-shadow:0 0 20px rgba(239,68,68,.15)}
.l2{color:#F97316;text-shadow:0 0 20px rgba(249,115,22,.15)}
.o{background:linear-gradient(90deg,#FBBF24,#F59E0B,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent;animation:oShift 3s ease-in-out infinite}
@keyframes oShift{0%,100%{filter:hue-rotate(0deg)}50%{filter:hue-rotate(15deg)}}
.title{font-size:18px;font-weight:600;color:#1d1d1f;margin-bottom:6px}
.subtitle{font-size:13px;color:#86868b}
.step-indicator{display:flex;justify-content:center;gap:8px;margin-bottom:30px}
.step-dot{width:8px;height:8px;border-radius:50%;background:rgba(0,0,0,.15)}
.step-dot.active{background:#0071e3;width:24px;border-radius:4px;box-shadow:0 0 8px rgba(0,113,227,.4)}
.step-dot.done{background:#34c759}
</style></head><body>
<div class="step-indicator"><div class="step-dot done"></div><div class="step-dot active"></div><div class="step-dot"></div><div class="step-dot"></div><div class="step-dot"></div></div>
<div class="hello-text"><span class="h">h</span><span class="e">e</span><span class="l1">l</span><span class="l2">l</span><span class="o">o</span></div>
<div class="title">hello os'a Hoş Geldiniz</div><div class="subtitle">Sürüm 1.0</div>
</body></html>
SLIDE1

cat > "$S/language.html" << 'SLIDE2'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#1d1d1f;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;max-width:400px;margin:0 auto;text-align:left}
.item{background:rgba(0,0,0,.03);border:1.5px solid rgba(0,0,0,.08);border-radius:8px;padding:12px;font-size:14px}
.item.sel{border-color:#0071e3;background:rgba(0,113,227,.08)}
.code{font-weight:600;color:#1d1d1f}.name{color:#86868b;font-size:12px}
</style></head><body><h2>Dil Seçin</h2><div class="grid">
<div class="item sel"><span class="code">TR</span> <span class="name">Türkçe</span></div>
<div class="item"><span class="code">EN</span> <span class="name">English</span></div>
<div class="item"><span class="code">DE</span> <span class="name">Deutsch</span></div>
<div class="item"><span class="code">FR</span> <span class="name">Français</span></div>
</div></body></html>
SLIDE2

cat > "$S/disk.html" << 'SLIDE3'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#1d1d1f;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.disk{background:rgba(0,0,0,.03);border:1.5px solid rgba(0,0,0,.08);border-radius:10px;padding:16px;margin:10px auto;max-width:400px;text-align:left;display:flex;align-items:center;gap:12px}
.disk.sel{border-color:#0071e3;background:rgba(0,113,227,.08)}
.icon{width:32px;height:32px;background:#86868b;border-radius:6px;flex-shrink:0}
.dname{font-weight:500;font-size:15px}.ddetail{color:#86868b;font-size:12px}
</style></head><body><h2>Kurulum Diski Seçin</h2>
<div class="disk sel"><div class="icon"></div><div><div class="dname">Darwin HD</div><div class="ddetail">APFS · 476 GB kullanılabilir</div></div></div>
<div class="disk"><div class="icon"></div><div><div class="dname">Harici SSD</div><div class="ddetail">exFAT · 210 GB kullanılabilir</div></div></div>
</body></html>
SLIDE3

cat > "$S/progress.html" << 'SLIDE4'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#1d1d1f;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.bar{width:300px;height:6px;background:rgba(0,0,0,.08);border-radius:3px;margin:20px auto;overflow:hidden}
.fill{height:100%;background:linear-gradient(90deg,#0071e3,#5e5ce6);border-radius:3px;width:45%;animation:fill 3s infinite}
@keyframes fill{0%{width:10%}50%{width:70%}100%{width:95%}}
.steps{display:flex;justify-content:space-between;max-width:400px;margin:20px auto;font-size:11px;color:#86868b}
.sdone{color:#34c759}.scurr{color:#0071e3}.time{color:#86868b;font-size:13px;margin-top:8px}
</style></head><body><h2>Kurulum Devam Ediyor</h2><div class="bar"><div class="fill"></div></div>
<div class="time">Kalan süre: ~22 dk</div><div class="steps">
<span class="sdone">✓ Hazırlık</span><span class="scurr">⟳ Kopyalama</span><span>Kurulum</span><span>Tamamlama</span>
</div></body></html>
SLIDE4

cat > "$S/complete.html" << 'SLIDE5'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Pacifico&display=swap" rel="stylesheet"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
.hello{font-family:'Pacifico',cursive;font-size:60px;display:flex;justify-content:center;gap:4px;margin-bottom:20px}
.h{color:#8B5CF6}.e{color:#EC4899}.l1{color:#EF4444}.l2{color:#F97316}
.o{background:linear-gradient(90deg,#FBBF24,#F59E0B,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.title{font-size:18px;font-weight:600;color:#1d1d1f;margin-bottom:6px}
.subtitle{font-size:13px;color:#86868b}.countdown{font-size:48px;font-weight:300;color:#1d1d1f;margin:20px 0}
</style></head><body>
<div class="hello"><span class="h">h</span><span class="e">e</span><span class="l1">l</span><span class="l2">l</span><span class="o">o</span></div>
<div class="title">Kurulum Tamamlandı!</div><div class="subtitle">hello os başarıyla yüklendi</div>
<div class="countdown">10</div><div class="subtitle">saniye içinde yeniden başlatılacak...</div>
</body></html>
SLIDE5

# 13. Ek ayarlar
echo "[13/16] Ek ayarlar..."
update-initramfs -u 2>/dev/null || true

# 14. Temizlik
echo "[14/16] Temizlik..."
apt clean 2>/dev/null || true
rm -rf /tmp/* /var/cache/apt/*

# 15. İlk açılış sihirbazı
echo "[15/16] İlk açılış sihirbazı..."
[ -f /etc/xdg/autostart/gnome-initial-setup-first-login.desktop ] && \
    echo "X-GNOME-Autostart-enabled=false" >> /etc/xdg/autostart/gnome-initial-setup-first-login.desktop 2>/dev/null || true

# 16. GRUB güncelle
echo "[16/16] GRUB güncelleniyor..."
update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Tüm özelleştirmeler tamamlandı!   ║"
echo "║   GRUB teması: Monterey (install.sh) ║"
echo "╚══════════════════════════════════════╝"
FULLHOOK

chmod +x config/hooks/normal/1000-opendarwin-complete.hook.chroot
log "Hook hazır"

# ── Live‑build çalıştır ──
info "ISO içeriği oluşturuluyor (20‑40 dk)..."
sudo lb build 2>&1 | tee /tmp/build-opendarwin.log
log "Live‑build tamamlandı"

# ── ISO’yu bul ──
BINARY_ISO="$WORK/live-image-amd64.iso"
[ ! -f "$BINARY_ISO" ] && BINARY_ISO="$WORK/chroot/binary.hybrid.iso"
[ ! -f "$BINARY_ISO" ] && err "Live‑build ISO'su bulunamadı!"

# ── Boot dosyalarını ekle ──
info "Boot dosyaları (syslinux) ekleniyor..."
TMPISO="/tmp/opendarwin-iso"
rm -rf "$TMPISO"
mkdir -p "$TMPISO"
7z x "$BINARY_ISO" -o"$TMPISO" >/dev/null

# ISOLINUX dosyalarını ekle
mkdir -p "$TMPISO/isolinux"
for f in isolinux.bin ldlinux.c32 menu.c32 libutil.c32 libcom32.c32; do
    if [ -f "/usr/lib/ISOLINUX/$f" ]; then
        cp "/usr/lib/ISOLINUX/$f" "$TMPISO/isolinux/"
    elif [ -f "/usr/lib/syslinux/modules/bios/$f" ]; then
        cp "/usr/lib/syslinux/modules/bios/$f" "$TMPISO/isolinux/"
    fi
done

# Kernel ve initrd adlarını bul
KERNEL=$(ls "$TMPISO/casper"/vmlinuz-* 2>/dev/null | head -1 | xargs basename)
INITRD=$(ls "$TMPISO/casper"/initrd.img-* 2>/dev/null | head -1 | xargs basename)
[ -z "$KERNEL" ] && err "Kernel bulunamadı!"

# ISOLINUX yapılandırması
cat > "$TMPISO/isolinux/isolinux.cfg" << EOF
UI menu.c32
PROMPT 0
TIMEOUT 50
DEFAULT live

MENU TITLE hello os 1.0

LABEL live
  MENU LABEL ^Start hello os
  KERNEL /casper/${KERNEL}
  APPEND initrd=/casper/${INITRD} boot=casper quiet splash --

LABEL install
  MENU LABEL ^Install hello os
  KERNEL /casper/${KERNEL}
  APPEND initrd=/casper/${INITRD} boot=casper only-ubiquity quiet splash --
EOF

# GRUB yapılandırması
mkdir -p "$TMPISO/boot/grub"
if [ ! -f "$TMPISO/boot/grub/efi.img" ]; then
    dd if=/dev/zero of="$TMPISO/boot/grub/efi.img" bs=1M count=5 2>/dev/null
    mkfs.vfat "$TMPISO/boot/grub/efi.img" 2>/dev/null || true
fi

cat > "$TMPISO/boot/grub/grub.cfg" << EOF
set timeout=5
menuentry "hello os - Live" {
    linux /casper/${KERNEL} boot=casper quiet splash
    initrd /casper/${INITRD}
}
menuentry "hello os - Install" {
    linux /casper/${KERNEL} boot=casper only-ubiquity quiet splash
    initrd /casper/${INITRD}
}
EOF

# Hibrit MBR bul
MBR="/usr/lib/ISOLINUX/isohdpfx.bin"
[ ! -f "$MBR" ] && MBR="/usr/lib/syslinux/isohdpfx.bin"
[ ! -f "$MBR" ] && MBR=""

# Bootable ISO oluştur
FINAL_ISO="/workspaces/Hello-os/hello-os-1.0-amd64.iso"
info "Bootable ISO oluşturuluyor..."
cd "$TMPISO"
if [ -n "$MBR" ]; then
    xorriso -as mkisofs \
        -isohybrid-mbr "$MBR" \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
        -isohybrid-gpt-basdat \
        -r -V "hello os 1.0" \
        -o "$FINAL_ISO" \
        .
else
    xorriso -as mkisofs \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
        -r -V "hello os 1.0" \
        -o "$FINAL_ISO" \
        .
fi

log "Son ISO: $FINAL_ISO"
ls -lh "$FINAL_ISO"

rm -rf "$TMPISO"

echo ""
echo -e "${G}╔══════════════════════════════════════╗${N}"
echo -e "${G}║   ISO HAZIR!                         ║${N}"
echo -e "${G}║   $FINAL_ISO${N}"
echo -e "${G}║   Sağ tık → Download                 ║${N}"
echo -e "${G}╚══════════════════════════════════════╝${N}"
