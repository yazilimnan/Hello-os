#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║   OpenDarwin 1.0 ARM64 Wayland - TAM ISO BUILD     ║
# ║   Boot + Kurulum Arayüzü + Kullanıcı + Saat        ║
# ╚══════════════════════════════════════════════════════╝

set -e
echo "╔══════════════════════════════════════╗"
echo "║   OpenDarwin 1.0 ARM64 Wayland      ║"
echo "║   TAM KURULUM EKRANI               ║"
echo "╚══════════════════════════════════════╝"

# ── 1. KONFİGÜRASYON ──
mkdir -p build && cd build

lb config \
    --architecture arm64 \
    --distribution noble \
    --binary-images iso-hybrid \
    --mode ubuntu \
    --archive-areas "main restricted universe multiverse" \
    --parent-archive-areas "main restricted universe multiverse" \
    --bootappend-live "boot=live components splash quiet" \
    --iso-application "OpenDarwin 1.0 ARM64" \
    --iso-volume "OpenDarwin 1.0 ARM" \
    --iso-publisher "OpenDarwin Project" \
    --memtest none \
    --apt-options "--yes" \
    --debian-installer false \
    --bootloader grub-efi \
    --bootstrap qemu-debootstrap \
    --parent-mirror-bootstrap http://ports.ubuntu.com/ubuntu-ports/ \
    --mirror-bootstrap http://ports.ubuntu.com/ubuntu-ports/ \
    --cache false \
    --apt-indices false

# ── 2. PAKET LİSTESİ ──
mkdir -p config/package-lists
cat > config/package-lists/opendarwin.list.chroot << 'PKG'
ubuntu-desktop-minimal
ubuntu-desktop
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
gnome-shell-extensions
gtk2-engines-murrine
gtk2-engines-pixbuf
imagemagick
python3
python3-pip
sudo
locales
tzdata
PKG

# ── 3. HOOK - TÜM ÖZELLİKLER ──
mkdir -p config/hooks/normal
cat > config/hooks/normal/1000-opendarwin.hook.chroot << 'FULLHOOK'
#!/bin/bash
set -e
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   OpenDarwin 1.0 ARM64 Wayland          ║"
echo "║   TAM KURULUM + BOOT + KULLANICI        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────
# 1. X11 KALDIR - WAYLAND ZORLA
# ─────────────────────────────────────────────
echo "[01/15] X11 kaldırılıyor, Wayland aktif..."
apt remove -y --purge xserver-xorg xserver-xorg-core xserver-xorg-video-all x11-common x11-utils 2>/dev/null || true
apt autoremove -y 2>/dev/null || true

mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf << 'GDM'
[daemon]
WaylandEnable=true
AutomaticLoginEnable=true
AutomaticLogin=user
TimedLoginEnable=true
TimedLogin=user
TimedLoginDelay=3
GDM

# ─────────────────────────────────────────────
# 2. LOCALE & ZAMAN DİLİMİ & SAAT
# ─────────────────────────────────────────────
echo "[02/15] Locale, saat ve zaman dilimi..."
locale-gen tr_TR.UTF-8 en_US.UTF-8 de_DE.UTF-8 fr_FR.UTF-8 2>/dev/null || true
update-locale LANG=tr_TR.UTF-8 2>/dev/null || true
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime

# Saat göstergesi ayarları
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/00-clock << 'CLOCK'
[org/gnome/desktop/interface]
clock-show-date=true
clock-show-seconds=true
clock-show-weekday=true
clock-format='24h'

[org/gnome/shell]
favorite-apps=['firefox.desktop','org.gnome.Terminal.desktop','org.gnome.Nautilus.desktop']

[org/gnome/desktop/datetime]
automatic-timezone=false
CLOCK

# ─────────────────────────────────────────────
# 3. PACIFICO FONT
# ─────────────────────────────────────────────
echo "[03/15] Pacifico font indiriliyor..."
mkdir -p /usr/share/fonts/truetype/pacifico /usr/local/share/fonts
cd /tmp
wget -q "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf" -O Pacifico.ttf 2>/dev/null || \
curl -sL "https://raw.githubusercontent.com/google/fonts/main/ofl/pacifico/Pacifico-Regular.ttf" -o Pacifico.ttf 2>/dev/null || true
if [ -f Pacifico.ttf ]; then
    cp Pacifico.ttf /usr/share/fonts/truetype/pacifico/
    cp Pacifico.ttf /usr/local/share/fonts/ 2>/dev/null || true
    fc-cache -f 2>/dev/null || true
    echo "  ✓ Pacifico font kuruldu"
fi

# ─────────────────────────────────────────────
# 4. MacTahoe GTK TEMASI
# ─────────────────────────────────────────────
echo "[04/15] MacTahoe GTK teması..."
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
    [ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/ 2>/dev/null || true
    [ -d /root/.icons ] && cp -r /root/.icons/MacTahoe* /usr/share/icons/ 2>/dev/null || true
    [ -d /home/user/.themes ] && cp -r /home/user/.themes/MacTahoe* /usr/share/themes/ 2>/dev/null || true
    [ -d /home/user/.icons ] && cp -r /home/user/.icons/MacTahoe* /usr/share/icons/ 2>/dev/null || true
    echo "  ✓ MacTahoe teması kuruldu"
fi

# ─────────────────────────────────────────────
# 5. PLYMOUTH BOOT ANİMASYONU
# ─────────────────────────────────────────────
echo "[05/15] Plymouth boot animasyonu..."
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
echo "  ✓ Boot animasyonu hazır"

# ─────────────────────────────────────────────
# 6. GTK AYARLARI
# ─────────────────────────────────────────────
echo "[06/15] GTK ayarları..."
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTKSET'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
gtk-cursor-theme-name=MacTahoe
GTKSET

# ─────────────────────────────────────────────
# 7. GNOME AYARLARI
# ─────────────────────────────────────────────
echo "[07/15] GNOME masaüstü ayarları..."
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

# ─────────────────────────────────────────────
# 8. DUVAR KAĞIDI
# ─────────────────────────────────────────────
echo "[08/15] Siyah duvar kağıdı..."
mkdir -p /usr/share/backgrounds
convert -size 1920x1080 xc:'#000000' /usr/share/backgrounds/opendarwin-bg.png 2>/dev/null || \
python3 -c "from PIL import Image;Image.new('RGB',(1920,1080),'black').save('/usr/share/backgrounds/opendarwin-bg.png')" 2>/dev/null || true

# ─────────────────────────────────────────────
# 9. SİSTEM MARKALAMASI
# ─────────────────────────────────────────────
echo "[09/15] Sistem markalaması..."
cat > /etc/os-release << 'OSRELEASE'
PRETTY_NAME="OpenDarwin 1.0 ARM64"
NAME="OpenDarwin"
VERSION_ID="1.0"
VERSION="1.0"
ID=opendarwin
ID_LIKE=ubuntu
HOME_URL="https://opendarwin.org"
OSRELEASE
echo "OpenDarwin 1.0 ARM64" > /etc/opendarwin-release
echo "opendarwin" > /etc/hostname
echo "127.0.1.1 opendarwin" >> /etc/hosts 2>/dev/null || true
[ -f /etc/lsb-release ] && sed -i 's/DISTRIB_ID=.*/DISTRIB_ID=OpenDarwin/' /etc/lsb-release 2>/dev/null || true

# ─────────────────────────────────────────────
# 10. GRUB ÖZELLEŞTİRMESİ
# ─────────────────────────────────────────────
echo "[10/15] GRUB..."
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/99-opendarwin.cfg << 'GRUB'
GRUB_DISTRIBUTOR="OpenDarwin"
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_GFXMODE=1920x1080
GRUB_BACKGROUND="#000000"
GRUB_COLOR_NORMAL="white/black"
GRUB_COLOR_HIGHLIGHT="magenta/black"
GRUB

# ─────────────────────────────────────────────
# 11. KULLANICI HESABI
# ─────────────────────────────────────────────
echo "[11/15] Kullanıcı: user / 123456"
useradd -m -s /bin/bash -G sudo,adm,cdrom,dip,plugdev,lpadmin,netdev user 2>/dev/null || true
echo "user:123456" | chpasswd 2>/dev/null || true
mkdir -p /home/user/Masaüstü /home/user/Belgeler /home/user/İndirilenler

# ─────────────────────────────────────────────
# 12. UBIQUITY CSS (TAM KURULUM ARAYÜZÜ)
# ─────────────────────────────────────────────
echo "[12/15] KURULUM ARAYÜZÜ CSS..."

mkdir -p /usr/share/ubiquity/gtk

cat > /usr/share/ubiquity/gtk/ubiquity.css << 'UBIQUITYCSS'
@define-color bg #ffffff;
@define-color fg #1d1d1f;
@define-color ac #0071e3;
@define-color sc #86868b;
@define-color bd rgba(0,0,0,0.08);
@define-color hb rgba(0,113,227,0.05);
@define-color sb rgba(0,113,227,0.08);

* { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }

window, .ubiquity, box, notebook, .live-installer, dialog {
    background-color: @bg; color: @fg;
}

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
entry:focus, input:focus {
    border-color: @ac; box-shadow: 0 0 0 3px rgba(0,113,227,0.1); outline: none;
}

switch { background: rgba(0,0,0,0.15); border-radius: 12px; min-width: 44px; min-height: 24px; }
switch:checked { background: @ac; }

treeview, .disk-list, list {
    background: rgba(0,0,0,0.03); border: 1.5px solid @bd; border-radius: 10px; padding: 4px;
}
treeview:selected, list row:selected { background: @sb; color: @fg; }

.language-option, .language-item {
    background: rgba(0,0,0,0.03); border: 1.5px solid @bd;
    border-radius: 10px; padding: 14px; margin: 4px;
}
.language-option:hover { border-color: @ac; background: @hb; }
.language-option:checked, .language-option.selected {
    border-color: @ac; background: @sb; box-shadow: 0 0 0 3px rgba(0,113,227,0.1);
}

.step-indicator { margin: 20px 0; }
.step-dot { min-width: 8px; min-height: 8px; border-radius: 50%; background: rgba(0,0,0,0.15); margin: 0 4px; }
.step-dot.active { background: @ac; min-width: 24px; border-radius: 4px; box-shadow: 0 0 8px rgba(0,113,227,0.4); }
.step-dot.done { background: #34c759; }

.license-text { background: rgba(0,0,0,0.02); border: 1px solid @bd; border-radius: 8px; padding: 16px; font-size: 12px; color: @sc; line-height: 1.6; }
.network-status { background: rgba(52,199,89,0.08); border: 1px solid rgba(52,199,89,0.2); border-radius: 10px; padding: 16px; }
.partition-visual { background: rgba(0,0,0,0.05); border: 1px solid @bd; border-radius: 6px; min-height: 30px; }
.install-log { background: @fg; color: #34c759; font-family: monospace; font-size: 11px; padding: 16px; border-radius: 8px; }
.reboot-countdown { font-size: 48px; font-weight: 300; color: @fg; margin: 20px 0; }

.theme-option { border-radius: 10px; padding: 20px 16px; border: 2px solid transparent; text-align: center; margin: 4px; }
.theme-option.light { background: #ffffff; border-color: @bd; }
.theme-option.dark { background: @fg; color: #ffffff; }
.theme-option.auto { background: linear-gradient(135deg, #ffffff 50%, @fg 50%); }
.theme-option:checked, .theme-option.selected { border-color: @ac !important; box-shadow: 0 0 0 3px rgba(0,113,227,0.15); }

checkbutton, radiobutton { color: @fg; }
checkbutton:checked, radiobutton:checked { color: @ac; }
UBIQUITYCSS

# Ubiquity konfigürasyonu
mkdir -p /etc/ubiquity
cat > /etc/ubiquity/ubiquity.conf << 'UBCNF'
[Ubiquity]
theme=MacTahoe
gtk_theme=MacTahoe
icon_theme=MacTahoe
UBCNF

echo "  ✓ Ubiquity CSS tamam"

# ─────────────────────────────────────────────
# 13. KURULUM EKRANI OTOMATİK BAŞLATMA
# ─────────────────────────────────────────────
echo "[13/15] Kurulum ekranı otomatik başlatma..."
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/ubiquity.desktop << 'AUTOSTART'
[Desktop Entry]
Type=Application
Name=Install OpenDarwin
Exec=ubiquity --automatic
Icon=system-software-install
X-GNOME-Autostart-enabled=true
NoDisplay=true
AUTOSTART

# ─────────────────────────────────────────────
# 14. KURULUM SLAYT HAZIRLAMA (5 SLAYT)
# ─────────────────────────────────────────────
echo "[14/15] Kurulum slaytları..."
S=/usr/share/ubiquity-slideshow/slides/l10n/tr
mkdir -p "$S"

# SLAYT 1: HOŞ GELDİNİZ - RENKLİ HELLO + ADIMLAR
cat > "$S/welcome.html" << 'S1'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Pacifico&display=swap" rel="stylesheet"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;text-align:center;font-family:-apple-system,sans-serif;padding:60px 40px}
.hello{font-family:'Pacifico',cursive;font-size:90px;display:flex;justify-content:center;gap:4px;margin-bottom:24px}
.h{color:#8B5CF6;text-shadow:0 0 20px rgba(139,92,246,.15)}
.e{color:#EC4899;text-shadow:0 0 20px rgba(236,72,153,.15)}
.l1{color:#EF4444;text-shadow:0 0 20px rgba(239,68,68,.15)}
.l2{color:#F97316;text-shadow:0 0 20px rgba(249,115,22,.15)}
.o{background:linear-gradient(90deg,#FBBF24,#F59E0B,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent;animation:oShift 3s infinite}
@keyframes oShift{0%,100%{filter:hue-rotate(0deg)}50%{filter:hue-rotate(15deg)}}
.title{font-size:18px;font-weight:600;color:#1d1d1f;margin-bottom:6px}
.subtitle{font-size:13px;color:#86868b}
.dots{display:flex;justify-content:center;gap:8px;margin-bottom:30px}
.dot{width:8px;height:8px;border-radius:50%;background:rgba(0,0,0,.15)}
.dot.active{background:#0071e3;width:24px;border-radius:4px;box-shadow:0 0 8px rgba(0,113,227,.4)}
.dot.done{background:#34c759}
</style></head><body>
<div class="dots"><div class="dot done"></div><div class="dot active"></div><div class="dot"></div><div class="dot"></div><div class="dot"></div></div>
<div class="hello"><span class="h">h</span><span class="e">e</span><span class="l1">l</span><span class="l2">l</span><span class="o">o</span></div>
<div class="title">OpenDarwin'e Hoş Geldiniz</div><div class="subtitle">Sürüm 1.0 ARM64 · Wayland</div>
</body></html>
S1

# SLAYT 2: DİL & BÖLGE SEÇİMİ
cat > "$S/language.html" << 'S2'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8"><style>
*{margin:0;padding:0}body{background:#fff;text-align:center;font-family:sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:10px}
.g{display:grid;grid-template-columns:1fr 1fr;gap:8px;max-width:400px;margin:0 auto 20px;text-align:left}
.i{background:rgba(0,0,0,.03);border:1.5px solid rgba(0,0,0,.08);border-radius:8px;padding:12px;font-size:14px}
.i.s{border-color:#0071e3;background:rgba(0,113,227,.08)}
.c{font-weight:600;color:#1d1d1f}.n{color:#86868b;font-size:12px}
.region{margin-top:16px;text-align:left;max-width:400px;margin:0 auto}
.region select{width:100%;padding:10px;border:1.5px solid rgba(0,0,0,.1);border-radius:8px;font-size:14px}
</style></head><body>
<h2>Dil Seçin</h2><div class="g">
<div class="i s"><span class="c">TR</span> <span class="n">Türkçe</span></div>
<div class="i"><span class="c">EN</span> <span class="n">English</span></div>
<div class="i"><span class="c">DE</span> <span class="n">Deutsch</span></div>
<div class="i"><span class="c">FR</span> <span class="n">Français</span></div>
</div>
<div class="region"><p style="color:#86868b;font-size:13px;margin-bottom:4px">Bölge:</p>
<select><option>Türkiye</option><option>ABD</option><option>Almanya</option><option>Fransa</option></select></div>
</body></html>
S2

# SLAYT 3: DİSK SEÇİMİ + BÖLÜMLEME
cat > "$S/disk.html" << 'S3'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8"><style>
*{margin:0;padding:0}body{background:#fff;text-align:center;font-family:sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.d{background:rgba(0,0,0,.03);border:1.5px solid rgba(0,0,0,.08);border-radius:10px;padding:16px;margin:10px auto;max-width:400px;text-align:left;display:flex;align-items:center;gap:12px}
.d.s{border-color:#0071e3;background:rgba(0,113,227,.08)}
.ic{width:32px;height:32px;background:#86868b;border-radius:6px}
.dn{font-weight:500;font-size:15px}.dd{color:#86868b;font-size:12px}
.partition{margin-top:20px;background:rgba(0,0,0,.05);border-radius:6px;padding:12px;max-width:400px;margin:20px auto}
.bar{display:flex;height:24px;border-radius:4px;overflow:hidden}
.used{background:#0071e3;width:40%}.free{background:rgba(0,0,0,.1);width:25%}.new{background:#34c759;width:35%}
</style></head><body>
<h2>Kurulum Diski Seçin</h2>
<div class="d s"><div class="ic"></div><div><div class="dn">Darwin HD</div><div class="dd">APFS · 476 GB kullanılabilir</div></div></div>
<div class="d"><div class="ic"></div><div><div class="dn">Harici SSD</div><div class="dd">exFAT · 210 GB kullanılabilir</div></div></div>
<div class="partition"><p style="color:#86868b;font-size:12px;margin-bottom:8px">Disk Bölümleme</p>
<div class="bar"><div class="used"></div><div class="free"></div><div class="new"></div></div>
<p style="color:#86868b;font-size:11px;margin-top:4px">Sistem 200GB | Boş 130GB | Yeni 180GB</p></div>
</body></html>
S3

# SLAYT 4: KULLANICI OLUŞTURMA + İLERLEME
cat > "$S/progress.html" << 'S4'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8"><style>
*{margin:0;padding:0}body{background:#fff;text-align:center;font-family:sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.b{width:300px;height:6px;background:rgba(0,0,0,.08);border-radius:3px;margin:20px auto;overflow:hidden}
.f{height:100%;background:linear-gradient(90deg,#0071e3,#5e5ce6);border-radius:3px;width:45%;animation:fi 3s infinite}
@keyframes fi{0%{width:10%}50%{width:70%}100%{width:95%}}
.st{display:flex;justify-content:space-between;max-width:400px;margin:20px auto;font-size:11px;color:#86868b}
.sd{color:#34c759}.sc{color:#0071e3}.t{color:#86868b;font-size:13px;margin-top:8px}
.user-form{text-align:left;max-width:300px;margin:20px auto}
.user-form input{width:100%;padding:10px;border:1.5px solid rgba(0,0,0,.1);border-radius:8px;margin-bottom:8px;font-size:14px}
</style></head><body>
<h2>Hesap Oluşturun</h2>
<div class="user-form">
<input type="text" placeholder="Tam Ad" value="Kullanıcı">
<input type="text" placeholder="Kullanıcı Adı" value="user">
<input type="password" placeholder="Parola" value="123456">
<input type="password" placeholder="Parola Tekrar" value="123456">
</div>
<h2 style="margin-top:30px">Kurulum Devam Ediyor</h2>
<div class="b"><div class="f"></div></div>
<div class="t">Kalan süre: ~22 dk</div>
<div class="st"><span class="sd">✓ Hazırlık</span><span class="sc">⟳ Kopyalama</span><span>Kurulum</span><span>Tamamlama</span></div>
</body></html>
S4

# SLAYT 5: TAMAMLANDI + GERİ SAYIM
cat > "$S/complete.html" << 'S5'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Pacifico&display=swap" rel="stylesheet"><style>
*{margin:0;padding:0}body{background:#fff;text-align:center;font-family:sans-serif;padding:40px}
.h{font-family:'Pacifico',cursive;font-size:60px;display:flex;justify-content:center;gap:4px;margin-bottom:20px}
.h1{color:#8B5CF6}.h2{color:#EC4899}.h3{color:#EF4444}.h4{color:#F97316}
.h5{background:linear-gradient(90deg,#FBBF24,#F59E0B,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.t{font-size:18px;font-weight:600;color:#1d1d1f}.s{font-size:13px;color:#86868b}
.c{font-size:48px;font-weight:300;color:#1d1d1f;margin:20px 0}
</style></head><body>
<div class="h"><span class="h1">h</span><span class="h2">e</span><span class="h3">l</span><span class="h4">l</span><span class="h5">o</span></div>
<div class="t">Kurulum Tamamlandı!</div><div class="s">OpenDarwin başarıyla yüklendi</div>
<div class="c">10</div><div class="s">saniye içinde yeniden başlatılacak...</div>
</body></html>
S5

echo "  ✓ 5 slayt hazır"

# ─────────────────────────────────────────────
# 15. TEMİZLİK
# ─────────────────────────────────────────────
echo "[15/15] Temizlik..."
apt clean 2>/dev/null || true
rm -rf /tmp/* /var/cache/apt/*

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   TÜM ÖZELLİŞTİRMELER TAMAM         ║"
echo "║  ✓ Wayland (X11 kaldırıldı)          ║"
echo "║  ✓ Plymouth Boot Animasyonu          ║"
echo "║  ✓ MacTahoe GTK Teması              ║"
echo "║  ✓ Pacifico Font                    ║"
echo "║  ✓ Saat Göstergesi                  ║"
echo "║  ✓ Ubiquity CSS (BEYAZ TEMA)        ║"
echo "║  ✓ 5 Kurulum Slaytı                 ║"
echo "║  ✓ Otomatik Kurulum Başlatma        ║"
echo "║  ✓ Kullanıcı: user / 123456         ║"
echo "╚══════════════════════════════════════╝"
FULLHOOK

chmod +x config/hooks/normal/1000-opendarwin.hook.chroot

# ── 4. BUILD ──
echo ""
echo "╔══════════════════════════════════════╗"
echo "║   ISO OLUŞTURULUYOR...              ║"
echo "║   30-60 dakika sürebilir            ║"
echo "╚══════════════════════════════════════╝"
echo ""

lb build 2>&1 | tee /tmp/build.log

# ── 5. SONUÇ ──
if [ -f "live-image-arm64.iso" ]; then
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║   ARM64 ISO HAZIR!                   ║"
    echo "║   live-image-arm64.iso              ║"
    echo "║   Boyut: $(du -h live-image-arm64.iso | cut -f1)                         ║"
    echo "║   Kullanıcı: user / 123456           ║"
    echo "╚══════════════════════════════════════╝"
else
    echo "HATA!"
    tail -30 /tmp/build.log
fi
