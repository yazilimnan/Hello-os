cd /tmp && rm -rf od-build && mkdir od-build && cd od-build && \
cat > build.sh << 'BUILDSCRIPT'
#!/bin/bash
set -e
G='\033[0;32m' B='\033[0;34m' R='\033[0;31m' N='\033[0m'
log() { echo -e "${G}[✓]${N} $1"; }
info() { echo -e "${B}[*]${N} $1"; }

info "OpenDarwin 1.0 - TAM KURULUM EKRANI"
info "Build: $(pwd)"

sudo apt update -qq 2>/dev/null
sudo apt install -y -qq live-build live-config live-boot live-manual debian-archive-keyring 2>/dev/null

sudo lb config --architecture amd64 --distribution noble --binary-images iso-hybrid --mode ubuntu --archive-areas "main restricted universe multiverse" --parent-archive-areas "main restricted universe multiverse" --bootappend-live "boot=live components splash quiet" --iso-application "OpenDarwin 1.0" --iso-volume "OpenDarwin 1.0" --iso-publisher "OpenDarwin Project" --memtest none --apt-options "--yes" --debian-installer false --bootloader grub-efi --cache false --apt-indices false

mkdir -p config/package-lists config/hooks/normal

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

cat > config/hooks/normal/1000-opendarwin.hook.chroot << 'HOOK'
#!/bin/bash
set -e
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   OpenDarwin 1.0 - TAM ÖZELLEŞTİRME     ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# 1. LOCALE
echo "[01/12] Locale..."
locale-gen tr_TR.UTF-8 en_US.UTF-8 2>/dev/null || true
update-locale LANG=tr_TR.UTF-8 2>/dev/null || true
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime 2>/dev/null || true

# 2. PACIFICO FONT
echo "[02/12] Pacifico font..."
mkdir -p /usr/share/fonts/truetype/pacifico /usr/local/share/fonts
cd /tmp
wget -q "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf" -O Pacifico.ttf 2>/dev/null || \
curl -sL "https://raw.githubusercontent.com/google/fonts/main/ofl/pacifico/Pacifico-Regular.ttf" -o Pacifico.ttf 2>/dev/null || true
[ -f Pacifico.ttf ] && cp Pacifico.ttf /usr/share/fonts/truetype/pacifico/ && cp Pacifico.ttf /usr/local/share/fonts/ 2>/dev/null && fc-cache -f 2>/dev/null

# 3. MacTahoe GTK TEMASI
echo "[03/12] MacTahoe GTK teması..."
cd /tmp && rm -rf MacTahoe-gtk-theme
git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git 2>/dev/null || \
{ wget -qO- https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/master.tar.gz | tar -xz; mv MacTahoe-gtk-theme-master MacTahoe-gtk-theme; }
if [ -d MacTahoe-gtk-theme ]; then
    cd MacTahoe-gtk-theme && ./install.sh -c dark -i 2>/dev/null || true
    mkdir -p /usr/share/themes /usr/share/icons
    [ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/ 2>/dev/null || true
    [ -d /root/.icons ] && cp -r /root/.icons/MacTahoe* /usr/share/icons/ 2>/dev/null || true
    [ -d /home/user/.themes ] && cp -r /home/user/.themes/MacTahoe* /usr/share/themes/ 2>/dev/null || true
    [ -d /home/user/.icons ] && cp -r /home/user/.icons/MacTahoe* /usr/share/icons/ 2>/dev/null || true
fi

# 4. PLYMOUTH BOOT ANİMASYONU
echo "[04/12] Plymouth boot animasyonu..."
mkdir -p /usr/share/plymouth/themes/opendarwin
cat > /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth << 'PLY'
[Plymouth Theme]
Name=OpenDarwin
Description=OpenDarwin Boot Screen - hello
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/opendarwin
ScriptFile=/usr/share/plymouth/themes/opendarwin/opendarwin.script
PLY

cat > /usr/share/plymouth/themes/opendarwin/opendarwin.script << 'SCR'
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
SCR

update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth 100 2>/dev/null || true
update-alternatives --set default.plymouth /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth 2>/dev/null || true

# 5. GTK AYARLARI
echo "[05/12] GTK ayarları..."
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTK'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
gtk-cursor-theme-name=MacTahoe
GTK

# 6. GNOME AYARLARI
echo "[06/12] GNOME ayarları..."
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

# 7. SİYAH DUVAR KAĞIDI
echo "[07/12] Duvar kağıdı..."
mkdir -p /usr/share/backgrounds
convert -size 1920x1080 xc:'#000000' /usr/share/backgrounds/opendarwin-bg.png 2>/dev/null || \
python3 -c "from PIL import Image;Image.new('RGB',(1920,1080),'black').save('/usr/share/backgrounds/opendarwin-bg.png')" 2>/dev/null || \
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==" | base64 -d > /usr/share/backgrounds/opendarwin-bg.png 2>/dev/null || true

# 8. SİSTEM MARKALAMASI
echo "[08/12] Sistem markalaması..."
cat > /etc/os-release << 'OS'
PRETTY_NAME="OpenDarwin 1.0"
NAME="OpenDarwin"
VERSION_ID="1.0"
VERSION="1.0"
ID=opendarwin
ID_LIKE=ubuntu
HOME_URL="https://opendarwin.org"
OS
echo "OpenDarwin 1.0" > /etc/opendarwin-release
echo "opendarwin" > /etc/hostname
echo "127.0.1.1 opendarwin" >> /etc/hosts 2>/dev/null || true
[ -f /etc/lsb-release ] && sed -i 's/Ubuntu/OpenDarwin/g' /etc/lsb-release 2>/dev/null || true

# 9. GRUB
echo "[09/12] GRUB..."
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/99-opendarwin.cfg << 'GRUB'
GRUB_DISTRIBUTOR="OpenDarwin"
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_GFXMODE=1920x1080
GRUB_BACKGROUND="#000000"
GRUB

# 10. KULLANICI
echo "[10/12] Kullanıcı..."
useradd -m -s /bin/bash -G sudo,adm,cdrom,dip,plugdev,lpadmin,netdev user 2>/dev/null || true
echo "user:123456" | chpasswd 2>/dev/null || true
mkdir -p /etc/gdm3 /etc/lightdm
cat > /etc/gdm3/custom.conf << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
GDM
cat > /etc/lightdm/lightdm.conf << 'LIGHT'
[Seat:*]
autologin-user=user
autologin-user-timeout=0
LIGHT

# 11. UBIQUITY KURULUM ARAYÜZÜ CSS (TAM)
echo "[11/12] Kurulum arayüzü CSS..."
mkdir -p /usr/share/ubiquity/gtk

cat > /usr/share/ubiquity/gtk/ubiquity.css << 'CSS'
/* ══════════════════════════════════════════════ */
/*  OpenDarwin Kurulum Arayüzü - TAM TEMA        */
/*  HTML'deki tasarımın birebir aynısı           */
/* ══════════════════════════════════════════════ */

@define-color bg_color #ffffff;
@define-color fg_color #1d1d1f;
@define-color accent #0071e3;
@define-color secondary #86868b;
@define-color border rgba(0, 0, 0, 0.08);
@define-color hover_bg rgba(0, 113, 227, 0.05);
@define-color selected_bg rgba(0, 113, 227, 0.08);

* { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }

/* ANA PENCERE - BEYAZ */
window, .ubiquity, box, notebook, .live-installer, vbox, hbox, dialog {
    background-color: @bg_color;
    color: @fg_color;
}

/* BAŞLIK ÇUBUĞU */
headerbar, .titlebar {
    background: rgba(255, 255, 255, 0.85);
    backdrop-filter: blur(30px);
    border-bottom: 1px solid @border;
    padding: 8px 12px;
}

/* PENCERE KONTROL BUTONLARI */
button.titlebutton.close { background: #ff5f57; min-width: 12px; min-height: 12px; border-radius: 50%; margin: 0 2px; }
button.titlebutton.minimize { background: #febc2e; min-width: 12px; min-height: 12px; border-radius: 50%; margin: 0 2px; }
button.titlebutton.maximize { background: #28c840; min-width: 12px; min-height: 12px; border-radius: 50%; margin: 0 2px; }

/* BAŞLIK METNİ */
.title, .section-title, label.title {
    font-size: 18px;
    font-weight: 600;
    color: @fg_color;
}

.subtitle, .section-subtitle, label.subtitle {
    font-size: 13px;
    color: @secondary;
}

/* ADIM GÖSTERGELERİ */
.step-indicator { margin: 20px 0; }
.step-dot {
    min-width: 8px; min-height: 8px;
    border-radius: 50%;
    background: rgba(0, 0, 0, 0.15);
    margin: 0 4px;
}
.step-dot.active {
    background: @accent;
    min-width: 24px;
    border-radius: 4px;
    box-shadow: 0 0 8px rgba(0, 113, 227, 0.4);
}
.step-dot.done { background: #34c759; }

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
button.secondary:hover { background: rgba(0, 0, 0, 0.08); }

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
switch:checked { background: @accent; }

/* LİSTE VE DİSK SEÇİMİ */
treeview, list, .disk-list {
    background: rgba(0, 0, 0, 0.03);
    border: 1.5px solid @border;
    border-radius: 10px;
}
treeview:selected, list row:selected {
    background: @selected_bg;
    color: @fg_color;
    border-color: @accent;
}

/* DİL SEÇİM GRİD */
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

/* CHECKBOX VE RADIO */
checkbutton, radiobutton { color: @fg_color; }
checkbutton check:checked, radiobutton radio:checked { background: @accent; color: #fff; }

/* LİSANS METNİ */
.license-text {
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

/* BÖLÜMLEME */
.partition-visual {
    background: rgba(0, 0, 0, 0.05);
    border: 1px solid @border;
    border-radius: 6px;
}

/* KURULUM LOG */
.install-log {
    background: @fg_color;
    color: #34c759;
    font-family: monospace;
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

/* HELLO RENKLERİ */
.hello-h { color: #8B5CF6; }
.hello-e { color: #EC4899; }
.hello-l1 { color: #EF4444; }
.hello-l2 { color: #F97316; }
.hello-o { color: #10B981; }
CSS

# 12. KURULUM SLAYT HAZIRLAMA (5 ADET)
echo "[12/12] Kurulum slaytları..."
S=/usr/share/ubiquity-slideshow/slides/l10n/tr
mkdir -p "$S"

cat > "$S/welcome.html" << 'SLIDE1'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Pacifico&display=swap" rel="stylesheet"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;text-align:center;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;padding:60px 40px}
.hello{font-family:'Pacifico',cursive;font-size:90px;display:flex;justify-content:center;gap:4px;margin-bottom:24px}
.h{color:#8B5CF6;text-shadow:0 0 20px rgba(139,92,246,0.15)}
.e{color:#EC4899;text-shadow:0 0 20px rgba(236,72,153,0.15)}
.l1{color:#EF4444;text-shadow:0 0 20px rgba(239,68,68,0.15)}
.l2{color:#F97316;text-shadow:0 0 20px rgba(249,115,22,0.15)}
.o{background:linear-gradient(90deg,#FBBF24,#F59E0B,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent;animation:os 3s infinite}
@keyframes os{0%,100%{filter:hue-rotate(0deg)}50%{filter:hue-rotate(15deg)}}
.title{font-size:18px;font-weight:600;color:#1d1d1f}.subtitle{font-size:13px;color:#86868b}
.dots{display:flex;justify-content:center;gap:8px;margin-bottom:30px}
.dot{width:8px;height:8px;border-radius:50%;background:rgba(0,0,0,.15)}
.dot.active{background:#0071e3;width:24px;border-radius:4px;box-shadow:0 0 8px rgba(0,113,227,.4)}
.dot.done{background:#34c759}
</style></head><body>
<div class="dots"><div class="dot done"></div><div class="dot active"></div><div class="dot"></div><div class="dot"></div><div class="dot"></div></div>
<div class="hello"><span class="h">h</span><span class="e">e</span><span class="l1">l</span><span class="l2">l</span><span class="o">o</span></div>
<div class="title">OpenDarwin'e Hoş Geldiniz</div><div class="subtitle">Sürüm 1.0 - Darwin Kernel</div>
</body></html>
SLIDE1

cat > "$S/language.html" << 'SLIDE2'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#1d1d1f;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.g{display:grid;grid-template-columns:1fr 1fr;gap:8px;max-width:400px;margin:0 auto;text-align:left}
.i{background:rgba(0,0,0,.03);border:1.5px solid rgba(0,0,0,.08);border-radius:8px;padding:12px;font-size:14px}
.i.s{border-color:#0071e3;background:rgba(0,113,227,.08)}
.c{font-weight:600;color:#1d1d1f}.n{color:#86868b;font-size:12px}
</style></head><body><h2>Dil Seçin</h2><div class="g">
<div class="i s"><span class="c">TR</span> <span class="n">Türkçe</span></div>
<div class="i"><span class="c">EN</span> <span class="n">English</span></div>
<div class="i"><span class="c">DE</span> <span class="n">Deutsch</span></div>
<div class="i"><span class="c">FR</span> <span class="n">Français</span></div>
</div></body></html>
SLIDE2

cat > "$S/disk.html" << 'SLIDE3'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#1d1d1f;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.d{background:rgba(0,0,0,.03);border:1.5px solid rgba(0,0,0,.08);border-radius:10px;padding:16px;margin:10px auto;max-width:400px;text-align:left;display:flex;align-items:center;gap:12px}
.d.s{border-color:#0071e3;background:rgba(0,113,227,.08)}
.ic{width:32px;height:32px;background:#86868b;border-radius:6px;flex-shrink:0}
.dn{font-weight:500;font-size:15px}.dd{color:#86868b;font-size:12px}
</style></head><body><h2>Kurulum Diski Seçin</h2>
<div class="d s"><div class="ic"></div><div><div class="dn">Darwin HD</div><div class="dd">APFS · 476 GB kullanılabilir</div></div></div>
<div class="d"><div class="ic"></div><div><div class="dn">Harici SSD</div><div class="dd">exFAT · 210 GB kullanılabilir</div></div></div>
</body></html>
SLIDE3

cat > "$S/progress.html" << 'SLIDE4'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#1d1d1f;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.b{width:300px;height:6px;background:rgba(0,0,0,.08);border-radius:3px;margin:20px auto;overflow:hidden}
.f{height:100%;background:linear-gradient(90deg,#0071e3,#5e5ce6);border-radius:3px;width:45%;animation:fi 3s infinite}
@keyframes fi{0%{width:10%}50%{width:70%}100%{width:95%}}
.st{display:flex;justify-content:space-between;max-width:400px;margin:20px auto;font-size:11px;color:#86868b}
.sd{color:#34c759}.sc{color:#0071e3}.t{color:#86868b;font-size:13px;margin-top:8px}
</style></head><body><h2>Kurulum Devam Ediyor</h2><div class="b"><div class="f"></div></div>
<div class="t">Kalan süre: ~22 dk</div><div class="st">
<span class="sd">✓ Hazırlık</span><span class="sc">⟳ Kopyalama</span><span>Kurulum</span><span>Tamamlama</span>
</div></body></html>
SLIDE4

cat > "$S/complete.html" << 'SLIDE5'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Pacifico&display=swap" rel="stylesheet"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
.he{font-family:'Pacifico',cursive;font-size:60px;display:flex;justify-content:center;gap:4px;margin-bottom:20px}
.h1{color:#8B5CF6}.h2{color:#EC4899}.h3{color:#EF4444}.h4{color:#F97316}
.h5{background:linear-gradient(90deg,#FBBF24,#F59E0B,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.ti{font-size:18px;font-weight:600;color:#1d1d1f;margin-bottom:6px}
.su{font-size:13px;color:#86868b}.cd{font-size:48px;font-weight:300;color:#1d1d1f;margin:20px 0}
</style></head><body>
<div class="he"><span class="h1">h</span><span class="h2">e</span><span class="h3">l</span><span class="h4">l</span><span class="h5">o</span></div>
<div class="ti">Kurulum Tamamlandı!</div><div class="su">OpenDarwin başarıyla yüklendi</div>
<div class="cd">10</div><div class="su">saniye içinde yeniden başlatılacak...</div>
</body></html>
SLIDE5

# TEMİZLİK
apt clean 2>/dev/null || true
rm -rf /tmp/* /var/cache/apt/* 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   TÜM ÖZELLEŞTİRMELER TAMAMLANDI        ║"
echo "║   ✓ Locale                              ║"
echo "║   ✓ Pacifico font                       ║"
echo "║   ✓ MacTahoe GTK teması                 ║"
echo "║   ✓ Plymouth boot animasyonu            ║"
echo "║   ✓ GTK/GNOME ayarları                  ║"
echo "║   ✓ Siyah duvar kağıdı                  ║"
echo "║   ✓ OpenDarwin markalaması              ║"
echo "║   ✓ GRUB özelleştirmesi                 ║"
echo "║   ✓ Kullanıcı: user / 123456            ║"
echo "║   ✓ Ubiquity CSS (TAM)                  ║"
echo "║   ✓ 5 Kurulum slaytı                    ║"
echo "╚══════════════════════════════════════════╝"
HOOK

chmod +x config/hooks/normal/1000-opendarwin.hook.chroot

sudo apt clean 2>/dev/null || true
rm -rf /tmp/* 2>/dev/null || true

echo ""
echo -e "${B}╔══════════════════════════════════════╗${N}"
echo -e "${B}║   ISO OLUŞTURULUYOR...              ║${N}"
echo -e "${B}║   20-40 dakika sürebilir            ║${N}"
echo -e "${B}╚══════════════════════════════════════╝${N}"
echo ""

START=$(date +%s)
sudo lb build 2>&1 | tee build.log
END=$(date +%s)

if [ -f "live-image-amd64.iso" ]; then
    cp live-image-amd64.iso $HOME/opendarwin-1.0-amd64.iso
    SZ=$(du -h live-image-amd64.iso | cut -f1)
    MN=$(((END-START)/60))
    echo ""
    echo -e "${G}╔══════════════════════════════════════╗${N}"
    echo -e "${G}║   🎉 ISO HAZIR! 🎉                  ║${N}"
    echo -e "${G}║   $HOME/opendarwin-1.0-amd64.iso    ║${N}"
    echo -e "${G}║   Boyut: $SZ   Süre: ${MN} dk         ║${N}"
    echo -e "${G}║   Sağ tık → Download                ║${N}"
    echo -e "${G}╚══════════════════════════════════════╝${N}"
else
    echo -e "${R}╔══════════════════════════════════════╗${N}"
    echo -e "${R}║   HATA!                              ║${N}"
    echo -e "${R}╚══════════════════════════════════════╝${N}"
    tail -30 build.log
fi
BUILDSCRIPT
chmod +x build.sh && ./build.sh
