#!/bin/bash
set -e

echo "╔══════════════════════════════════════╗"
echo "║   OpenDarwin 1.0 ARM64 Wayland      ║"
echo "║   TAM KURULUM EKRANI               ║"
echo "╚══════════════════════════════════════╝"

rm -rf build
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

sudo mkdir -p chroot cache

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

mkdir -p config/hooks/normal
cat > config/hooks/normal/1000-opendarwin.hook.chroot << 'HOOK'
#!/bin/bash
set -e
echo "OpenDarwin - TAM KURULUM EKRANI"

# X11 kaldir Wayland zorla
apt remove -y --purge xserver-xorg xserver-xorg-core x11-common 2>/dev/null || true
apt autoremove -y 2>/dev/null || true
mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf << 'GDM'
[daemon]
WaylandEnable=true
AutomaticLoginEnable=true
AutomaticLogin=user
GDM

# Locale & Saat
locale-gen tr_TR.UTF-8 en_US.UTF-8 2>/dev/null || true
update-locale LANG=tr_TR.UTF-8 2>/dev/null || true
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/00-clock << 'CLK'
[org/gnome/desktop/interface]
clock-show-date=true
clock-show-seconds=true
clock-show-weekday=true
clock-format='24h'
CLK

# Font
mkdir -p /usr/share/fonts/truetype/pacifico
cd /tmp
wget -q "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf" -O Pacifico.ttf 2>/dev/null || true
[ -f Pacifico.ttf ] && cp Pacifico.ttf /usr/share/fonts/truetype/pacifico/ && fc-cache -f

# MacTahoe
cd /tmp && rm -rf MacTahoe-gtk-theme
git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git 2>/dev/null || { wget -qO- https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/master.tar.gz | tar -xz; mv MacTahoe-gtk-theme-master MacTahoe-gtk-theme; }
[ -d MacTahoe-gtk-theme ] && cd MacTahoe-gtk-theme && ./install.sh -c dark -i 2>/dev/null || true
mkdir -p /usr/share/themes /usr/share/icons
[ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/ 2>/dev/null || true

# Plymouth
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

# GTK
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTK'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
GTK

# Sistem
cat > /etc/os-release << 'OS'
PRETTY_NAME="OpenDarwin 1.0 ARM64"
NAME="OpenDarwin"
VERSION_ID="1.0"
ID=opendarwin
ID_LIKE=ubuntu
OS
echo "OpenDarwin 1.0 ARM64" > /etc/opendarwin-release
echo "opendarwin" > /etc/hostname

# GRUB
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/opendarwin.cfg << 'GRB'
GRUB_DISTRIBUTOR="OpenDarwin"
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRB

# Kullanici
useradd -m -s /bin/bash -G sudo user 2>/dev/null || true
echo "user:123456" | chpasswd 2>/dev/null || true

# ===== UBIQUITY CSS - KURULUM ARAYUZU =====
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
CSS

mkdir -p /etc/ubiquity
cat > /etc/ubiquity/ubiquity.conf << 'UBCNF'
[Ubiquity]
theme=MacTahoe
gtk_theme=MacTahoe
icon_theme=MacTahoe
UBCNF

# Otomatik kurulum başlatma
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/ubiquity.desktop << 'AUTO'
[Desktop Entry]
Type=Application
Name=Install OpenDarwin
Exec=ubiquity --automatic
X-GNOME-Autostart-enabled=true
NoDisplay=true
AUTO

# ===== 5 KURULUM SLAYT =====
S=/usr/share/ubiquity-slideshow/slides/l10n/tr
mkdir -p "$S"

# Slayt 1: Hoş Geldiniz - RENKLİ HELLO + ADIMLAR
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

# Slayt 2: Dil & Bölge
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

# Slayt 3: Disk + Bölümleme
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

# Slayt 4: Kullanıcı + İlerleme
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

# Slayt 5: Tamamlandı + Geri Sayım
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

apt clean 2>/dev/null || true
rm -rf /tmp/*
echo "KURULUM EKRANI TAMAM"
HOOK

chmod +x config/hooks/normal/1000-opendarwin.hook.chroot

echo "ISO oluşturuluyor..."
sudo lb build 2>&1 | tee /tmp/build.log

if [ -f "live-image-arm64.iso" ]; then
    echo "ISO HAZIR! live-image-arm64.iso"
    ls -lh live-image-arm64.iso
else
    echo "HATA!"
    tail -30 /tmp/build.log
fi
