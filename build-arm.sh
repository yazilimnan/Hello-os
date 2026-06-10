#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║   OpenDarwin 1.0 ARM64 - TAM KURULUM EKRANLI       ║
# ║   GitHub Actions - ubuntu-24.04-arm                 ║
# ╚══════════════════════════════════════════════════════╝

set -e
G='\033[0;32m' B='\033[0;34m' R='\033[0;31m' N='\033[0m'
log() { echo -e "${G}[✓]${N} $1"; }
info() { echo -e "${B}[*]${N} $1"; }

echo -e "${B}"
echo "╔══════════════════════════════════════╗"
echo "║   OpenDarwin 1.0 ARM64 ISO Builder  ║"
echo "║   TAM Kurulum Arayüzü               ║"
echo "╚══════════════════════════════════════╝"
echo -e "${N}"

# ── 1. BAĞIMLILIKLAR ──
info "Paketler kuruluyor..."
sudo apt update -qq
sudo apt install -y -qq live-build live-config live-boot live-manual debian-archive-keyring qemu-user-static
log "Paketler hazır"

# ── 2. KONFİGÜRASYON ──
info "Live-build konfigürasyonu..."
sudo lb config \
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
log "Konfigürasyon tamam"

# ── 3. DİZİNLER ──
mkdir -p config/package-lists config/hooks/normal

# ── 4. PAKET LİSTESİ ──
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

# ── 5. HOOK - TÜM ÖZELLİKLER ──
cat > config/hooks/normal/1000-opendarwin.hook.chroot << 'FULLHOOK'
#!/bin/bash
set -e

echo "╔══════════════════════════════════════╗"
echo "║   OpenDarwin ARM64 - Özelleştirme   ║"
echo "╚══════════════════════════════════════╝"

# 1. LOCALE
echo "[01/12] Locale..."
locale-gen tr_TR.UTF-8 en_US.UTF-8 2>/dev/null || true
update-locale LANG=tr_TR.UTF-8 2>/dev/null || true
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime

# 2. FONT
echo "[02/12] Pacifico font..."
mkdir -p /usr/share/fonts/truetype/pacifico
cd /tmp
wget -q "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf" -O Pacifico.ttf 2>/dev/null || true
[ -f Pacifico.ttf ] && cp Pacifico.ttf /usr/share/fonts/truetype/pacifico/ && fc-cache -f

# 3. MacTahoe GTK
echo "[03/12] MacTahoe teması..."
cd /tmp && rm -rf MacTahoe-gtk-theme
git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git 2>/dev/null || \
{ wget -qO- https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/master.tar.gz | tar -xz; mv MacTahoe-gtk-theme-master MacTahoe-gtk-theme; }
[ -d MacTahoe-gtk-theme ] && cd MacTahoe-gtk-theme && ./install.sh -c dark -i 2>/dev/null || true
mkdir -p /usr/share/themes /usr/share/icons
[ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/ 2>/dev/null || true

# 4. PLYMOUTH
echo "[04/12] Boot animasyonu..."
mkdir -p /usr/share/plymouth/themes/opendarwin
cat > /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth << 'PLY'
[Plymouth Theme]
Name=OpenDarwin
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

update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth 100
update-alternatives --set default.plymouth /usr/share/plymouth/themes/opendarwin/opendarwin.plymouth

# 5. GTK
echo "[05/12] GTK ayarları..."
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTK'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
GTK

# 6. GNOME
echo "[06/12] GNOME ayarları..."
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-opendarwin << 'DCNF'
[org/gnome/desktop/interface]
gtk-theme='MacTahoe'
icon-theme='MacTahoe'
font-name='Pacifico 11'
[org/gnome/desktop/wm/preferences]
theme='MacTahoe'
[org/gnome/shell/extensions/user-theme]
name='MacTahoe'
DCNF

# 7. DUVAR KAĞIDI
echo "[07/12] Siyah duvar kağıdı..."
mkdir -p /usr/share/backgrounds
convert -size 1920x1080 xc:'#000000' /usr/share/backgrounds/opendarwin-bg.png 2>/dev/null || true

# 8. SİSTEM
echo "[08/12] Sistem..."
cat > /etc/os-release << 'OS'
PRETTY_NAME="OpenDarwin 1.0 ARM64"
NAME="OpenDarwin"
VERSION_ID="1.0"
ID=opendarwin
ID_LIKE=ubuntu
OS
echo "OpenDarwin 1.0 ARM64" > /etc/opendarwin-release
echo "opendarwin" > /etc/hostname

# 9. GRUB
echo "[09/12] GRUB..."
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/opendarwin.cfg << 'GRB'
GRUB_DISTRIBUTOR="OpenDarwin"
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRB

# 10. KULLANICI
echo "[10/12] Kullanıcı..."
useradd -m -s /bin/bash -G sudo user 2>/dev/null || true
echo "user:123456" | chpasswd 2>/dev/null || true
mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
GDM

# ═══════════════════════════════════════════
# 11. UBIQUITY CSS (TAM KURULUM ARAYÜZÜ)
# ═══════════════════════════════════════════
echo "[11/12] KURULUM ARAYÜZÜ..."

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
button.suggested-action:hover { background: #0077ed; box-shadow: 0 4px 12px rgba(0,113,227,0.3); }

button.secondary {
    background: rgba(0,0,0,0.05); color: @fg;
    border: 1px solid @bd; border-radius: 8px; padding: 10px 28px;
}

progressbar { background: rgba(0,0,0,0.08); border-radius: 3px; min-height: 6px; }
progressbar progress { background: linear-gradient(90deg, #0071e3, #5e5ce6); border-radius: 3px; }

entry, input {
    background: rgba(0,0,0,0.03); border: 1.5px solid @bd;
    border-radius: 8px; padding: 10px 14px; font-size: 14px; color: @fg;
}
entry:focus { border-color: @ac; box-shadow: 0 0 0 3px rgba(0,113,227,0.1); }

switch { background: rgba(0,0,0,0.15); border-radius: 12px; min-width: 44px; min-height: 24px; }
switch:checked { background: @ac; }

treeview, .disk-list, list {
    background: rgba(0,0,0,0.03); border: 1.5px solid @bd; border-radius: 10px; padding: 4px;
}
treeview:selected, list row:selected { background: @sb; color: @fg; }

.license-text { background: rgba(0,0,0,0.02); border: 1px solid @bd; border-radius: 8px; padding: 16px; font-size: 12px; color: @sc; }
.network-status { background: rgba(52,199,89,0.08); border: 1px solid rgba(52,199,89,0.2); border-radius: 10px; padding: 16px; }
.partition-visual { background: rgba(0,0,0,0.05); border: 1px solid @bd; border-radius: 6px; min-height: 30px; }
.install-log { background: @fg; color: #34c759; font-family: monospace; font-size: 11px; padding: 16px; border-radius: 8px; }
.reboot-countdown { font-size: 48px; font-weight: 300; color: @fg; }

.step-indicator { margin: 20px 0; }
.step-dot { min-width: 8px; min-height: 8px; border-radius: 50%; background: rgba(0,0,0,0.15); margin: 0 4px; }
.step-dot.active { background: @ac; min-width: 24px; border-radius: 4px; box-shadow: 0 0 8px rgba(0,113,227,0.4); }
.step-dot.done { background: #34c759; }

.language-option, .language-item {
    background: rgba(0,0,0,0.03); border: 1.5px solid @bd;
    border-radius: 10px; padding: 14px; margin: 4px;
}
.language-option:hover { border-color: @ac; background: @hb; }
.language-option:checked { border-color: @ac; background: @sb; box-shadow: 0 0 0 3px rgba(0,113,227,0.1); }

.theme-option { border-radius: 10px; padding: 20px 16px; border: 2px solid transparent; text-align: center; }
.theme-option.light { background: #ffffff; border-color: @bd; }
.theme-option.dark { background: @fg; color: #ffffff; }
.theme-option:checked { border-color: @ac !important; box-shadow: 0 0 0 3px rgba(0,113,227,0.15); }

checkbutton, radiobutton { color: @fg; }
checkbutton:checked, radiobutton:checked { color: @ac; }
CSS

# Ubiquity konfigürasyonu
mkdir -p /etc/ubiquity
cat > /etc/ubiquity/ubiquity.conf << 'UBCNF'
[Ubiquity]
theme=MacTahoe
gtk_theme=MacTahoe
icon_theme=MacTahoe
UBCNF

echo "  ✓ Kurulum CSS tamam"

# ═══════════════════════════════════════════
# 12. KURULUM SLAYT HAZIRLAMA (5 SLAYT)
# ═══════════════════════════════════════════
echo "[12/12] Kurulum slaytları..."
S="/usr/share/ubiquity-slideshow/slides/l10n/tr"
mkdir -p "$S"

# SLAYT 1: HOŞ GELDİNİZ - RENKLİ HELLO
cat > "$S/welcome.html" << 'S1'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Pacifico&display=swap" rel="stylesheet"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;text-align:center;font-family:-apple-system,sans-serif;padding:60px 40px}
.hello-text{font-family:'Pacifico',cursive;font-size:90px;display:flex;justify-content:center;gap:4px;margin-bottom:24px}
.h{color:#8B5CF6}.e{color:#EC4899}.l1{color:#EF4444}.l2{color:#F97316}
.o{background:linear-gradient(90deg,#FBBF24,#F59E0B,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent;animation:oShift 3s infinite}
@keyframes oShift{0%,100%{filter:hue-rotate(0deg)}50%{filter:hue-rotate(15deg)}}
.title{font-size:18px;font-weight:600;color:#1d1d1f}.subtitle{font-size:13px;color:#86868b}
.dots{display:flex;justify-content:center;gap:8px;margin-bottom:30px}
.dot{width:8px;height:8px;border-radius:50%;background:rgba(0,0,0,.15)}
.dot.active{background:#0071e3;width:24px;border-radius:4px}
.dot.done{background:#34c759}
</style></head><body>
<div class="dots"><div class="dot done"></div><div class="dot active"></div><div class="dot"></div><div class="dot"></div><div class="dot"></div></div>
<div class="hello-text"><span class="h">h</span><span class="e">e</span><span class="l1">l</span><span class="l2">l</span><span class="o">o</span></div>
<div class="title">OpenDarwin'e Hoş Geldiniz</div><div class="subtitle">Sürüm 1.0 ARM64</div>
</body></html>
S1

# SLAYT 2: DİL SEÇİMİ
cat > "$S/language.html" << 'S2'
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
S2

# SLAYT 3: DİSK SEÇİMİ
cat > "$S/disk.html" << 'S3'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#fff;color:#1d1d1f;text-align:center;font-family:-apple-system,sans-serif;padding:40px}
h2{font-size:18px;font-weight:600;margin-bottom:20px}
.disk{background:rgba(0,0,0,.03);border:1.5px solid rgba(0,0,0,.08);border-radius:10px;padding:16px;margin:10px auto;max-width:400px;text-align:left;display:flex;align-items:center;gap:12px}
.disk.sel{border-color:#0071e3;background:rgba(0,113,227,.08)}
.icon{width:32px;height:32px;background:#86868b;border-radius:6px;flex-shrink:0}
.dname{font-weight:500;font-size:15px}.ddetail{color:#86868b;font-size:12px}
</style></head><body><h2>Kurulum Diski Seçin</h2>
<div class="disk sel"><div class="icon"></div><div><div class="dname">Darwin HD</div><div class="ddetail">APFS · 476 GB</div></div></div>
<div class="disk"><div class="icon"></div><div><div class="dname">Harici SSD</div><div class="ddetail">exFAT · 210 GB</div></div></div>
</body></html>
S3

# SLAYT 4: İLERLEME
cat > "$S/progress.html" << 'S4'
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
S4

# SLAYT 5: TAMAMLANDI
cat > "$S/complete.html" << 'S5'
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
<div class="title">Kurulum Tamamlandı!</div><div class="subtitle">OpenDarwin başarıyla yüklendi</div>
<div class="countdown">10</div><div class="subtitle">saniye içinde yeniden başlatılacak...</div>
</body></html>
S5

echo "  ✓ 5 slayt hazır"

apt clean 2>/dev/null || true
rm -rf /tmp/*

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   TÜM ÖZELLEŞTİRMELER TAMAM         ║"
echo "║  ✓ Boot Animasyonu                   ║"
echo "║  ✓ MacTahoe GTK                     ║"
echo "║  ✓ Pacifico Font                    ║"
echo "║  ✓ Ubiquity CSS (BEYAZ TEMA)        ║"
echo "║  ✓ 5 Kurulum Slaytı                 ║"
echo "║  ✓ Kullanıcı: user / 123456         ║"
echo "╚══════════════════════════════════════╝"
FULLHOOK

chmod +x config/hooks/normal/1000-opendarwin.hook.chroot
log "Hook hazır (12 adım - TAM)"

# ── 6. BUILD ──
echo ""
echo -e "${B}╔══════════════════════════════════════╗${N}"
echo -e "${B}║   ARM64 ISO OLUŞTURULUYOR...        ║${N}"
echo -e "${B}║   30-60 dakika                      ║${N}"
echo -e "${B}╚══════════════════════════════════════╝${N}"
echo ""

START=$(date +%s)
sudo lb build 2>&1 | tee /tmp/build-arm64.log
END=$(date +%s)
BUILD_TIME=$(( (END - START) / 60 ))

# ── 7. SONUÇ ──
if [ -f "live-image-arm64.iso" ]; then
    ISO_SIZE=$(du -h live-image-arm64.iso | cut -f1)
    echo ""
    echo -e "${G}╔══════════════════════════════════════╗${N}"
    echo -e "${G}║   ARM64 ISO HAZIR!                   ║${N}"
    echo -e "${G}║   live-image-arm64.iso              ║${N}"
    echo -e "${G}║   Boyut: $ISO_SIZE   Süre: ${BUILD_TIME} dk ║${N}"
    echo -e "${G}║   Kullanıcı: user / 123456           ║${N}"
    echo -e "${G}╚══════════════════════════════════════╝${N}"
else
    echo -e "${R}HATA!${N}"
    tail -30 /tmp/build-arm64.log
    exit 1
fi
