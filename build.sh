#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║   hello os - NetInstall (Masaustu Sonradan)               ║
# ║   Sadece kurulum arayuzu - Her sey sonradan               ║
# ╚══════════════════════════════════════════════════════════════╝

set -e
G='\033[0;32m' B='\033[0;34m' R='\033[0;31m' Y='\033[1;33m' N='\033[0m'
log()   { echo -e "${G}[✓]${N} $1"; }
info()  { echo -e "${B}[*]${N} $1"; }
warn()  { echo -e "${Y}[!]${N} $1"; }
err()   { echo -e "${R}[X]${N} $1"; exit 1; }

clear
echo -e "${B}"
echo "╔══════════════════════════════════════════╗"
echo "║   hello os - NetInstall (Light)         ║"
echo "║   Masaustu + Boot SONRADAN              ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${N}"

DISK=$(df -BG /tmp | awk 'NR==2{print $4}' | sed 's/G//')
info "Disk: ${DISK} GB (gerekli: ~3 GB)"
[ "$DISK" -lt 3 ] && err "Disk yetersiz!"

# Paketler
info "Paketler kuruluyor..."
sudo apt update -qq
sudo apt install -y -qq debootstrap squashfs-tools xorriso wget p7zip-full isolinux unzip 2>/dev/null || true
log "Paketler hazir"

# Dizinler
WORK="/tmp/hello-light-$(date +%s)"
ROOTFS="$WORK/rootfs"
ISO_DIR="$WORK/iso"
OUTPUT="/workspaces/Hello-os/hello-os-netinstall.iso"

sudo rm -rf "$WORK"
mkdir -p "$ROOTFS" "$ISO_DIR"/{casper,isolinux,boot/grub}

# ═══════════════════════════════════════════════════════════════
# MINIMAL DEBOOTSTRAP
# ═══════════════════════════════════════════════════════════════
info "Minimal Ubuntu base indiriliyor..."
sudo debootstrap --arch=amd64 noble "$ROOTFS" http://archive.ubuntu.com/ubuntu/
log "Base hazir"

# ═══════════════════════════════════════════════════════════════
# CHROOT - SADECE KURULUM ARACI (MASUSTU YOK, BOOT YOK)
# ═══════════════════════════════════════════════════════════════
sudo mount --bind /dev "$ROOTFS/dev"
sudo mount --bind /proc "$ROOTFS/proc"
sudo mount --bind /sys "$ROOTFS/sys"
sudo cp /etc/resolv.conf "$ROOTFS/etc/"

sudo tee "$ROOTFS/tmp/setup.sh" > /dev/null << 'SETUP'
#!/bin/bash
echo "╔══════════════════════════════════════════╗"
echo "║   hello os - Light Setup                ║"
echo "╚══════════════════════════════════════════╝"

apt update
apt upgrade -y

# ---- SADECE TEMEL PAKETLER (MASUSTU YOK, BOOT YOK) ----
echo "[1] Temel sistem..."
apt install -y --no-install-recommends \
    linux-image-generic \
    casper \
    ubiquity ubiquity-frontend-gtk \
    network-manager wireless-tools wpasupplicant \
    net-tools iproute2 \
    sudo locales wget curl \
    cryptsetup lvm2 \
    git unzip imagemagick

# ---- LOCALE ----
echo "[2] Locale..."
locale-gen tr_TR.UTF-8 en_US.UTF-8
update-locale LANG=tr_TR.UTF-8
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime

# ---- SISTEM ADI ----
echo "[3] Sistem adi..."
cat > /etc/os-release << 'OS'
PRETTY_NAME="hello os"
NAME="hello os"
VERSION_ID="1.0"
ID=hello-os
ID_LIKE=ubuntu
HOME_URL="https://hello-os.org"
OS
echo "hello os 1.0" > /etc/hello-release
echo "hello-os" > /etc/hostname
echo "127.0.1.1 hello-os" >> /etc/hosts

# ---- GRUB ----
echo "[4] GRUB..."
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/99-hello.cfg << 'GRB'
GRUB_DISTRIBUTOR="hello os"
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_GFXMODE=1920x1080
GRB

# ═══════════════════════════════════════════════════════════════
# macOS Tahoe STILI KURULUM ARAYUZU
# ═══════════════════════════════════════════════════════════════
echo "[5] Kurulum arayuzu..."

mkdir -p /usr/share/ubiquity/gtk
cat > /usr/share/ubiquity/gtk/ubiquity.css << 'CSS'
@define-color bg #f5f5f7;
@define-color surface rgba(255,255,255,0.85);
@define-color fg #1d1d1f;
@define-color ac #0071e3;
@define-color sc #86868b;
@define-color bd rgba(0,0,0,0.08);

* { font-family: -apple-system, BlinkMacSystemFont, 'Inter', sans-serif; }

window, .ubiquity, box, notebook, dialog { background: @bg; color: @fg; }

.titlebar, headerbar {
    background: @surface;
    backdrop-filter: blur(30px);
    border-bottom: 1px solid @bd;
    padding: 12px 18px;
    min-height: 40px;
}

button.titlebutton.close { background: #ff5f57; min-width: 12px; min-height: 12px; border-radius: 50%; }
button.titlebutton.minimize { background: #febc2e; min-width: 12px; min-height: 12px; border-radius: 50%; }
button.titlebutton.maximize { background: #28c840; min-width: 12px; min-height: 12px; border-radius: 50%; }

.title, .section-title { font-size: 24px; font-weight: 600; color: @fg; margin-bottom: 6px; }
.subtitle, .section-subtitle { font-size: 14px; color: @sc; margin-bottom: 28px; }

button.suggested-action, button.primary {
    background: @ac; color: #fff; border-radius: 8px;
    padding: 11px 32px; font-weight: 500; border: none;
    box-shadow: 0 2px 8px rgba(0,113,227,0.2);
    transition: all 0.2s;
}
button.suggested-action:hover { background: #0077ed; box-shadow: 0 4px 16px rgba(0,113,227,0.3); transform: translateY(-1px); }
button.secondary { background: rgba(0,0,0,0.04); color: @fg; border: 1px solid @bd; border-radius: 8px; padding: 11px 32px; }

progressbar { background: rgba(0,0,0,0.06); border-radius: 3px; min-height: 6px; }
progressbar progress { background: linear-gradient(90deg, #0071e3, #5e5ce6); border-radius: 3px; }

entry, input {
    background: rgba(0,0,0,0.02); border: 1.5px solid @bd;
    border-radius: 8px; padding: 11px 16px; font-size: 14px; color: @fg;
}
entry:focus { border-color: @ac; box-shadow: 0 0 0 3px rgba(0,113,227,0.1); outline: none; }

switch { background: rgba(0,0,0,0.15); border-radius: 12px; min-width: 44px; min-height: 24px; }
switch:checked { background: @ac; }

treeview, .disk-list, list {
    background: rgba(255,255,255,0.7); border: 1.5px solid @bd;
    border-radius: 12px; padding: 6px;
}
treeview:selected, list row:selected { background: rgba(0,113,227,0.08); color: @fg; }
CSS

# ---- SLAYT HAZIRLAMA ----
mkdir -p /usr/share/ubiquity-slideshow/slides/l10n/tr

cat > /usr/share/ubiquity-slideshow/slides/l10n/tr/welcome.html << 'S1'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:linear-gradient(180deg,#f5f5f7 0%,#fff 100%);color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:720px}
.logo{font-size:80px;font-weight:300;letter-spacing:5px;margin-bottom:10px}
.logo span{font-weight:700;background:linear-gradient(135deg,#8B5CF6,#EC4899,#EF4444,#F97316,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.version{font-size:13px;color:#86868b;letter-spacing:3px;margin-bottom:40px;text-transform:uppercase}
.features{display:grid;grid-template-columns:1fr 1fr;gap:14px;text-align:left;margin:30px 0}
.feature{background:rgba(255,255,255,0.8);backdrop-filter:blur(20px);border:1px solid rgba(0,0,0,0.08);border-radius:14px;padding:22px;box-shadow:0 2px 12px rgba(0,0,0,0.04)}
.feature h3{font-size:16px;font-weight:600;margin-bottom:8px;color:#1d1d1f}
.feature p{font-size:13px;color:#86868b;line-height:1.5}
.badge{display:inline-block;background:rgba(0,113,227,0.1);color:#0071e3;padding:3px 10px;border-radius:20px;font-size:10px;font-weight:600;margin-top:10px}
</style></head><body><div class="container">
<div class="logo">hello<span> os</span></div>
<div class="version">Light NetInstall 1.0</div>
<div class="features">
<div class="feature"><h3>Hafif Kurulum</h3><p>Sadece temel sistem kurulur, masaustu sonradan</p><span class="badge">MINIMAL</span></div>
<div class="feature"><h3>Guncel Paketler</h3><p>Internet uzerinden en guncel surumler indirilir</p><span class="badge">GUNCEL</span></div>
<div class="feature"><h3>MACOS Benzeri Arayuz</h3><p>MacTahoe temasi ile premium gorunum</p><span class="badge">KALITELI</span></div>
<div class="feature"><h3>Guvenli Altyapi</h3><p>UFW + Tor + AppArmor ile koruma</p><span class="badge">GUVENLI</span></div>
</div>
</div></body></html>
S1

cat > /usr/share/ubiquity-slideshow/slides/l10n/tr/language.html << 'S2'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:600px}
h2{font-size:28px;font-weight:600;margin-bottom:10px}
p{color:#86868b;font-size:14px;margin-bottom:35px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.item{background:rgba(255,255,255,0.8);backdrop-filter:blur(20px);border:1.5px solid rgba(0,0,0,0.08);border-radius:12px;padding:18px;cursor:pointer;box-shadow:0 1px 6px rgba(0,0,0,0.04)}
.item.sel{border-color:#0071e3;background:rgba(0,113,227,0.06);box-shadow:0 0 0 3px rgba(0,113,227,0.1)}
.code{font-size:22px;font-weight:700;margin-bottom:5px}.name{font-size:12px;color:#86868b}
</style></head><body><div class="container">
<h2>Dil Secimi</h2><p>Kullanmak istediginiz dili secin</p>
<div class="grid">
<div class="item sel"><div class="code">TR</div><div class="name">Turkce</div></div>
<div class="item"><div class="code">EN</div><div class="name">English</div></div>
</div></div></body></html>
S2

cat > /usr/share/ubiquity-slideshow/slides/l10n/tr/disk.html << 'S3'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:600px}
h2{font-size:28px;font-weight:600;margin-bottom:10px}
p{color:#86868b;font-size:14px;margin-bottom:35px}
.disk{background:rgba(255,255,255,0.8);backdrop-filter:blur(20px);border:1.5px solid rgba(0,0,0,0.08);border-radius:14px;padding:22px;margin:12px 0;text-align:left;display:flex;align-items:center;gap:16px;cursor:pointer;box-shadow:0 1px 6px rgba(0,0,0,0.04)}
.disk.sel{border-color:#0071e3;background:rgba(0,113,227,0.05);box-shadow:0 0 0 3px rgba(0,113,227,0.1)}
.icon{width:48px;height:48px;background:rgba(0,0,0,0.04);border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:18px;color:#86868b;font-weight:600}
.dname{font-weight:600;font-size:16px}.ddetail{color:#86868b;font-size:12px;margin-top:3px}
</style></head><body><div class="container">
<h2>Kurulum Diski</h2><p>hello os'un kurulacagi diski secin</p>
<div class="disk sel"><div class="icon">HD</div><div><div class="dname">Birincil Disk</div><div class="ddetail">NVMe SSD - 512 GB</div></div></div>
<div class="disk"><div class="icon">USB</div><div><div class="dname">Harici Depolama</div><div class="ddetail">USB 3.0 - 256 GB</div></div></div>
</div></body></html>
S3

cat > /usr/share/ubiquity-slideshow/slides/l10n/tr/progress.html << 'S4'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:500px}
h2{font-size:28px;font-weight:600;margin-bottom:30px}
.bar{width:100%;height:6px;background:rgba(0,0,0,0.06);border-radius:3px;overflow:hidden;margin:24px 0}
.fill{height:100%;background:linear-gradient(90deg,#0071e3,#5e5ce6);border-radius:3px;width:45%;animation:fill 3s infinite}
@keyframes fill{0%{width:8%}50%{width:72%}100%{width:94%}}
.steps{display:flex;justify-content:space-between;margin:20px 0;font-size:12px;color:#86868b}
.step.done{color:#34c759;font-weight:500}.step.current{color:#0071e3;font-weight:600}
.time{color:#86868b;font-size:13px;margin-top:15px}
</style></head><body><div class="container">
<h2>Kurulum Devam Ediyor</h2><div class="bar"><div class="fill"></div></div>
<div class="time">Internet hizina bagli - ~20 dk</div>
<div class="steps">
<span class="step done">Hazirlik</span><span class="step current">Indiriliyor</span><span class="step">Kuruluyor</span><span class="step">Tamamlaniyor</span>
</div></div></body></html>
S4

cat > /usr/share/ubiquity-slideshow/slides/l10n/tr/complete.html << 'S5'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:600px}
h2{font-size:32px;font-weight:600;margin-bottom:10px}
p{color:#86868b;font-size:15px;margin-bottom:35px}
.countdown{font-size:56px;font-weight:300;margin:25px 0;color:#0071e3}
.info{background:rgba(255,255,255,0.8);backdrop-filter:blur(20px);border:1px solid rgba(0,0,0,0.08);border-radius:14px;padding:20px;margin:20px auto;max-width:420px;text-align:left}
.info div{display:flex;justify-content:space-between;padding:10px 0;border-bottom:1px solid rgba(0,0,0,0.04)}
.info div:last-child{border-bottom:none}
.label{color:#86868b;font-size:13px}.value{font-weight:600;font-size:13px}
</style></head><body><div class="container">
<h2>Kurulum Tamamlandi!</h2><p>hello os basariyla yuklendi</p>
<div class="info">
<div><span class="label">Kullanici</span><span class="value">user</span></div>
<div><span class="label">Durum</span><span class="value">Temel sistem hazir</span></div>
<div><span class="label">Sonraki</span><span class="value">Masaustu + tema kurulacak</span></div>
</div>
<div class="countdown">10</div><p>saniye icinde yeniden baslatilacak</p>
</div></body></html>
S5

# ═══════════════════════════════════════════════════════════════
# POST-INSTALL (MASUSTU + BOOT + TEMA + FONT - HEPSI SONRADAN)
# ═══════════════════════════════════════════════════════════════
echo "[6] Post-install script (her sey burada)..."

mkdir -p /usr/share/hello-os
cat > /usr/share/hello-os/post-install.sh << 'POST'
#!/bin/bash
echo "╔══════════════════════════════════════════╗"
echo "║   hello os - Tam Kurulum Basliyor       ║"
echo "║   Masaustu + Boot + Tema + Font         ║"
echo "╚══════════════════════════════════════════╝"

# 1. GNOME MASUSTU
echo "[1/6] GNOME masaustu indiriliyor..."
apt update
apt install -y gnome-session gnome-shell gnome-terminal gnome-control-center nautilus gdm3 xorg xwayland gnome-shell-extensions gnome-tweaks

# 2. PLYMOUTH BOOT ANIMASYONU
echo "[2/6] Boot animasyonu kuruluyor..."
apt install -y plymouth plymouth-themes

rm -rf /usr/share/plymouth/themes/*
mkdir -p /usr/share/plymouth/themes/hello

cat > /usr/share/plymouth/themes/hello/hello.plymouth << 'PLY'
[Plymouth Theme]
Name=hello
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/hello
ScriptFile=/usr/share/plymouth/themes/hello/hello.script
PLY

cat > /usr/share/plymouth/themes/hello/hello.script << 'SCR'
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
SCR

plymouth-set-default-theme hello
update-initramfs -u

# 3. MacTahoe TEMASI
echo "[3/6] MacTahoe temasi..."
cd /tmp
wget -q https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/main.zip && unzip -q main.zip
cd MacTahoe-gtk-theme-main && ./install.sh -t all 2>/dev/null
mkdir -p /usr/share/themes /usr/share/icons
[ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/
[ -d /root/.icons ] && cp -r /root/.icons/MacTahoe* /usr/share/icons/

# 4. Pacifico FONT
echo "[4/6] Pacifico font..."
mkdir -p /usr/share/fonts/truetype/pacifico
wget -q https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf -O /usr/share/fonts/truetype/pacifico/Pacifico.ttf
fc-cache -f

# 5. GTK AYARLARI
echo "[5/6] GTK ayarlari..."
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTK'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
gtk-cursor-theme-name=MacTahoe
GTK

# 6. GUVENLIK + KULLANICI
echo "[6/6] Guvenlik + Kullanici..."
apt install -y ufw fail2ban tor apparmor
ufw enable
systemctl enable fail2ban tor apparmor

useradd -m -s /bin/bash -G sudo,adm user 2>/dev/null || true
echo "user:123456" | chpasswd 2>/dev/null || true

mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
WaylandEnable=true
GDM

systemctl enable gdm

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   hello os TAMAMEN HAZIR!               ║"
echo "║   Masaustu: GNOME + Wayland             ║"
echo "║   Boot: hello animasyonu                ║"
echo "║   Tema: MacTahoe                        ║"
echo "║   Font: Pacifico                        ║"
echo "║   Kullanici: user / 123456             ║"
echo "╚══════════════════════════════════════════╝"
POST
chmod +x /usr/share/hello-os/post-install.sh

mkdir -p /etc/ubiquity
cat > /etc/ubiquity/ubiquity.conf << 'UBI'
[Ubiquity]
post_install_script=/usr/share/hello-os/post-install.sh
UBI

# ---- CLEAN ----
echo "[7] Temizlik..."
apt clean
rm -rf /tmp/* /var/cache/apt/*

echo "╔══════════════════════════════════════════╗"
echo "║   Light Setup Complete!                  ║"
echo "╚══════════════════════════════════════════╝"
SETUP

sudo chmod +x "$ROOTFS/tmp/setup.sh"
sudo chroot "$ROOTFS" /tmp/setup.sh
log "Chroot tamam"

# ═══════════════════════════════════════════════════════════════
# SQUASHFS + KERNEL + BOOT + ISO
# ═══════════════════════════════════════════════════════════════
sudo umount "$ROOTFS/dev/pts" "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" 2>/dev/null || true

info "SquashFS..."
sudo mksquashfs "$ROOTFS" "$ISO_DIR/casper/filesystem.squashfs" -comp xz -b 1M
log "SquashFS: $(du -h "$ISO_DIR/casper/filesystem.squashfs" | cut -f1)"

sudo cp "$ROOTFS/boot/vmlinuz-"* "$ISO_DIR/casper/vmlinuz" 2>/dev/null || true
sudo cp "$ROOTFS/boot/initrd.img-"* "$ISO_DIR/casper/initrd" 2>/dev/null || true

[ ! -f "$ISO_DIR/casper/vmlinuz" ] && wget -q "http://archive.ubuntu.com/ubuntu/dists/noble/main/installer-amd64/current/images/cdrom/vmlinuz" -O "$ISO_DIR/casper/vmlinuz" 2>/dev/null || true
[ ! -f "$ISO_DIR/casper/initrd" ] && wget -q "http://archive.ubuntu.com/ubuntu/dists/noble/main/installer-amd64/current/images/cdrom/initrd.gz" -O "$ISO_DIR/casper/initrd" 2>/dev/null || true

# Bootloader
wget -q "https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz" -O /tmp/syslinux.tar.gz 2>/dev/null || true
tar -xzf /tmp/syslinux.tar.gz -C /tmp/ 2>/dev/null || true
SYS="/tmp/syslinux-6.03"

sudo cp "$SYS/bios/core/isolinux.bin" "$ISO_DIR/isolinux/" 2>/dev/null || true
sudo cp "$SYS/bios/com32/elflink/ldlinux/ldlinux.c32" "$ISO_DIR/isolinux/" 2>/dev/null || true
sudo cp "$SYS/bios/com32/menu/menu.c32" "$ISO_DIR/isolinux/" 2>/dev/null || true
sudo cp "$SYS/bios/com32/libutil/libutil.c32" "$ISO_DIR/isolinux/" 2>/dev/null || true
sudo cp "$SYS/bios/com32/lib/libcom32.c32" "$ISO_DIR/isolinux/" 2>/dev/null || true
sudo cp "$SYS/bios/mbr/isohdpfx.bin" "$ISO_DIR/" 2>/dev/null || true

sudo tee "$ISO_DIR/isolinux/isolinux.cfg" > /dev/null << 'EOF'
UI menu.c32
PROMPT 0
TIMEOUT 50
DEFAULT install
MENU TITLE hello os NetInstall
LABEL install
  MENU LABEL ^Install hello os (Internet Gerekli)
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd boot=casper only-ubiquity quiet splash --
EOF

sudo dd if=/dev/zero of="$ISO_DIR/boot/grub/efi.img" bs=1M count=5 2>/dev/null
sudo mkfs.vfat "$ISO_DIR/boot/grub/efi.img" 2>/dev/null || true

sudo tee "$ISO_DIR/boot/grub/grub.cfg" > /dev/null << 'EOF'
set timeout=5
menuentry "Install hello os (Internet Required)" { linux /casper/vmlinuz boot=casper only-ubiquity quiet splash; initrd /casper/initrd; }
EOF

cd "$ISO_DIR"
sudo xorriso -as mkisofs \
    -isohybrid-mbr isohdpfx.bin \
    -b isolinux/isolinux.bin -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
    -isohybrid-gpt-basdat -r -V "hello os NetInstall" \
    -o "$OUTPUT" .

if [ -f "$OUTPUT" ]; then
    sudo chmod 644 "$OUTPUT"
    echo ""
    echo -e "${G}╔══════════════════════════════════════════╗${N}"
    echo -e "${G}║   ISO HAZIR!                             ║${N}"
    echo -e "${G}║   $OUTPUT${N}"
    echo -e "${G}║   Boyut: $(du -h "$OUTPUT" | cut -f1)                          ║${N}"
    echo -e "${G}║                                          ║${N}"
    echo -e "${G}║   ISO icinde SADECE:                     ║${N}"
    echo -e "${G}║   [x] Kurulum arayuzu                    ║${N}"
    echo -e "${G}║   [x] Dil secimi                         ║${N}"
    echo -e "${G}║   [x] Disk secimi                        ║${N}"
    echo -e "${G}║   [x] Kullanici olusturma                ║${N}"
    echo -e "${G}║                                          ║${N}"
    echo -e "${G}║   SONRADAN INTERNETTEN:                  ║${N}"
    echo -e "${G}║   [x] GNOME masaustu                     ║${N}"
    echo -e "${G}║   [x] Plymouth boot animasyonu           ║${N}"
    echo -e "${G}║   [x] MacTahoe temasi                    ║${N}"
    echo -e "${G}║   [x] Pacifico font                      ║${N}"
    echo -e "${G}║   [x] Guvenlik paketleri                 ║${N}"
    echo -e "${G}╚══════════════════════════════════════════╝${N}"
fi
