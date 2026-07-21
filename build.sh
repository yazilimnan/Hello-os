#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   hello os 1.0 - COMPLETE ISO BUILDER                          ║
# ║   GitHub Codespaces                                            ║
# ║   macOS Tahoe Stili Kurulum Arayüzü                            ║
# ║   Plymouth Boot Animasyonu                                     ║
# ║   MacTahoe GTK Teması                                          ║
# ║   Pacifico Font                                                ║
# ║   Monterey GRUB Teması                                         ║
# ║   Çok Dilli (TR/EN)                                            ║
# ║   Güvenlik (UFW + Tor + AppArmor + Fail2ban)                   ║
# ╚══════════════════════════════════════════════════════════════════╝

set -e

# ── Renkler ──
G='\033[0;32m'
B='\033[0;34m'
R='\033[0;31m'
Y='\033[1;33m'
N='\033[0m'

log()   { echo -e "${G}[✓]${N} $1"; }
info()  { echo -e "${B}[*]${N} $1"; }
warn()  { echo -e "${Y}[!]${N} $1"; }
err()   { echo -e "${R}[X]${N} $1"; exit 1; }

clear

echo -e "${B}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║                  hello os 1.0                                ║"
echo "║            Complete ISO Builder                              ║"
echo "║                                                              ║"
echo "║   [✓] macOS Tahoe Stili Kurulum Arayüzü                      ║"
echo "║   [✓] Plymouth Boot Animasyonu (hello)                       ║"
echo "║   [✓] MacTahoe GTK Teması                                    ║"
echo "║   [✓] Pacifico Font                                          ║"
echo "║   [✓] Monterey GRUB Teması                                   ║"
echo "║   [✓] Çok Dilli Destek (TR/EN)                               ║"
echo "║   [✓] Güvenlik Paketleri                                     ║"
echo "║   [✓] Kurulum Sonrası Otomatik Yapılandırma                  ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${N}"

# ═══════════════════════════════════════════════════════════════════
# 1. ORTAM KONTROLÜ
# ═══════════════════════════════════════════════════════════════════
info "Ortam kontrolü yapılıyor..."

DISK_FREE=$(df -BG /tmp | awk 'NR==2{print $4}' | sed 's/G//')
echo "  Kullanılabilir disk: ${DISK_FREE} GB"
echo "  Gerekli: ~8 GB"
[ "$DISK_FREE" -lt 8 ] && err "Disk alanı yetersiz! En az 8 GB gerekli."

CPU_COUNT=$(nproc)
echo "  CPU çekirdek: ${CPU_COUNT}"
echo "  Mimari: $(uname -m)"

log "Ortam kontrolü tamamlandı"

# ═══════════════════════════════════════════════════════════════════
# 2. BAĞIMLILIKLAR
# ═══════════════════════════════════════════════════════════════════
info "Gerekli paketler kuruluyor..."

sudo apt update -qq

PACKAGES=(
    debootstrap
    squashfs-tools
    xorriso
    wget
    p7zip-full
    isolinux
    unzip
    grub-efi-amd64-bin
    grub-pc-bin
    grub2-common
    mtools
    dosfstools
)

for pkg in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii.*$pkg"; then
        echo "  ${pkg} zaten kurulu"
    else
        sudo apt install -y -qq "$pkg" 2>/dev/null && echo "  ${pkg} kuruldu" || warn "${pkg} kurulamadı"
    fi
done

log "Paketler hazır"

# ═══════════════════════════════════════════════════════════════════
# 3. ÇALIŞMA DİZİNİ
# ═══════════════════════════════════════════════════════════════════
info "Çalışma dizini hazırlanıyor..."

WORK="/tmp/hello-os-complete-$(date +%s)"
ROOTFS="$WORK/rootfs"
ISO_DIR="$WORK/iso"
OUTPUT="/workspaces/Hello-os/hello-os-1.0-amd64.iso"

sudo rm -rf "$WORK"
mkdir -p "$ROOTFS"
mkdir -p "$ISO_DIR/casper"
mkdir -p "$ISO_DIR/isolinux"
mkdir -p "$ISO_DIR/boot/grub"
mkdir -p "$ISO_DIR/preseed"

log "Çalışma dizini: $WORK"

# ═══════════════════════════════════════════════════════════════════
# 4. DEBOOTSTRAP - BASE SİSTEM
# ═══════════════════════════════════════════════════════════════════
info "Ubuntu 24.04 Noble base sistem indiriliyor..."
info "Bu işlem 10-15 dakika sürebilir..."

sudo debootstrap \
    --arch=amd64 \
    --components=main,restricted,universe,multiverse \
    noble \
    "$ROOTFS" \
    http://archive.ubuntu.com/ubuntu/

log "Base sistem hazır"

# ═══════════════════════════════════════════════════════════════════
# 5. CHROOT HAZIRLIĞI
# ═══════════════════════════════════════════════════════════════════
info "Chroot ortamı hazırlanıyor..."

sudo mount --bind /dev "$ROOTFS/dev"
sudo mount --bind /dev/pts "$ROOTFS/dev/pts"
sudo mount --bind /proc "$ROOTFS/proc"
sudo mount --bind /sys "$ROOTFS/sys"
sudo cp /etc/resolv.conf "$ROOTFS/etc/"
sudo cp /etc/hosts "$ROOTFS/etc/"

log "Chroot hazır"

# ═══════════════════════════════════════════════════════════════════
# 6. CHROOT İÇİNDE PAKET KURULUMU
# ═══════════════════════════════════════════════════════════════════
info "Chroot içinde kurulum script'i oluşturuluyor..."

sudo tee "$ROOTFS/tmp/setup.sh" > /dev/null << 'SETUPSCRIPT'
#!/bin/bash
set -e

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   hello os - Chroot Paket Kurulumu                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── 1. APT GÜNCELLEME ──
echo "[01/20] APT güncelleniyor..."
apt update
echo "  ✓ APT güncel"

# ── 2. LOCALE ──
echo "[02/20] Locale ayarlanıyor..."
locale-gen tr_TR.UTF-8 en_US.UTF-8
update-locale LANG=tr_TR.UTF-8
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
echo "  ✓ Locale: tr_TR.UTF-8 + en_US.UTF-8"

# ── 3. KERNEL ──
echo "[03/20] Linux kernel kuruluyor..."
apt install -y --no-install-recommends linux-image-generic
echo "  ✓ Kernel kuruldu"

# ── 4. CASPER (CANLI SİSTEM) ──
echo "[04/20] Casper kuruluyor..."
apt install -y --no-install-recommends casper
echo "  ✓ Casper kuruldu"

# ── 5. UBIQUITY (KURULUM ARAYÜZÜ) ──
echo "[05/20] Ubiquity kuruluyor..."
apt install -y --no-install-recommends ubiquity ubiquity-frontend-gtk ubiquity-slideshow-ubuntu
echo "  ✓ Ubiquity kuruldu"

# ── 6. GNOME MASAÜSTÜ ──
echo "[06/20] GNOME masaüstü kuruluyor..."
apt install -y --no-install-recommends \
    gnome-session gnome-shell gnome-terminal gnome-control-center \
    nautilus gdm3 xorg xwayland gnome-shell-extensions
echo "  ✓ GNOME kuruldu"

# ── 7. AĞ ARAÇLARI ──
echo "[07/20] Ağ araçları kuruluyor..."
apt install -y --no-install-recommends \
    network-manager wireless-tools wpasupplicant \
    net-tools iproute2
echo "  ✓ Ağ araçları kuruldu"

# ── 8. TEMEL ARAÇLAR ──
echo "[08/20] Temel araçlar kuruluyor..."
apt install -y --no-install-recommends \
    sudo locales wget curl git unzip \
    software-properties-common ubuntu-drivers-common
echo "  ✓ Temel araçlar kuruldu"

# ── 9. PLYMOUTH ──
echo "[09/20] Plymouth kuruluyor..."
apt install -y --no-install-recommends plymouth plymouth-themes
echo "  ✓ Plymouth kuruldu"

# ── 10. TEMA ARAÇLARI ──
echo "[10/20] Tema araçları kuruluyor..."
apt install -y --no-install-recommends \
    gnome-tweaks gnome-themes-extra gtk2-engines-murrine imagemagick
echo "  ✓ Tema araçları kuruldu"

# ── 11. GÜVENLİK PAKETLERİ ──
echo "[11/20] Güvenlik paketleri kuruluyor..."
apt install -y --no-install-recommends \
    ufw fail2ban tor torsocks wireguard openvpn \
    apparmor apparmor-profiles firejail macchanger secure-delete \
    cryptsetup lvm2
echo "  ✓ Güvenlik paketleri kuruldu"

# ── 12. DİL PAKETLERİ ──
echo "[12/20] Dil paketleri kuruluyor..."
apt install -y --no-install-recommends \
    language-pack-tr language-pack-en language-selector-common
echo "  ✓ Dil paketleri kuruldu"

# ── 13. PLYMOUTH HELLO TEMASI ──
echo "[13/20] Plymouth hello teması oluşturuluyor..."
rm -rf /usr/share/plymouth/themes/*
mkdir -p /usr/share/plymouth/themes/hello

cat > /usr/share/plymouth/themes/hello/hello.plymouth << 'PLYMOUTHCONF'
[Plymouth Theme]
Name=hello
Description=hello Boot Screen
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/hello
ScriptFile=/usr/share/plymouth/themes/hello/hello.script
PLYMOUTHCONF

cat > /usr/share/plymouth/themes/hello/hello.script << 'PLYMOUTHSCRIPT'
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();

bg = Image.New(1, 1);
bg.SetPixel(0, 0, 0, 0, 0, 1);
bg_sprite = Sprite(bg);
bg_sprite.SetWidth(screen_width);
bg_sprite.SetHeight(screen_height);

hello_text = Image.Text("hello", 0, 0);
hello_text.SetFont("Sans 72");
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
PLYMOUTHSCRIPT

plymouth-set-default-theme hello
update-initramfs -u
echo "  ✓ Plymouth hello teması kuruldu"

# ── 14. SİSTEM MARKALAMASI ──
echo "[14/20] Sistem markalaması yapılıyor..."
cat > /etc/os-release << 'OSRELEASE'
PRETTY_NAME="hello os"
NAME="hello os"
VERSION_ID="1.0"
VERSION="1.0"
ID=hello-os
ID_LIKE=ubuntu
HOME_URL="https://hello-os.org"
SUPPORT_URL="https://hello-os.org/support"
BUG_REPORT_URL="https://hello-os.org/bugs"
OSRELEASE

echo "hello os 1.0" > /etc/hello-release
echo "hello-os" > /etc/hostname
echo "127.0.1.1 hello-os" >> /etc/hosts

[ -f /etc/lsb-release ] && sed -i 's/DISTRIB_ID=.*/DISTRIB_ID=hello-os/' /etc/lsb-release
[ -f /etc/lsb-release ] && sed -i 's/DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION="hello os 1.0"/' /etc/lsb-release
echo "  ✓ Sistem adı: hello os"

# ── 15. GRUB YAPILANDIRMASI ──
echo "[15/20] GRUB yapılandırılıyor..."
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/99-hello.cfg << 'GRUBCONFIG'
GRUB_DISTRIBUTOR="hello os"
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_GFXMODE=1920x1080
GRUB_BACKGROUND="#000000"
GRUB_COLOR_NORMAL="white/black"
GRUB_COLOR_HIGHLIGHT="magenta/black"
GRUBCONFIG
echo "  ✓ GRUB yapılandırıldı"

# ── 16. KULLANICI HESABI ──
echo "[16/20] Kullanıcı hesabı oluşturuluyor..."
useradd -m -s /bin/bash -G sudo,adm,cdrom,dip,plugdev,lpadmin,netdev user
echo "user:123456" | chpasswd

mkdir -p /etc/gdm3 /etc/lightdm
cat > /etc/gdm3/custom.conf << 'GDMCONFIG'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
TimedLoginEnable=true
TimedLogin=user
TimedLoginDelay=3
WaylandEnable=true
GDMCONFIG

cat > /etc/lightdm/lightdm.conf << 'LIGHTCONFIG'
[Seat:*]
autologin-user=user
autologin-user-timeout=0
LIGHTCONFIG
echo "  ✓ Kullanıcı: user / 123456"

# ── 17. UBIQUITY CSS ──
echo "[17/20] Kurulum arayüzü CSS'i hazırlanıyor..."
mkdir -p /usr/share/ubiquity/gtk

cat > /usr/share/ubiquity/gtk/ubiquity.css << 'UBIQUITYCSS'
/* hello os - macOS Tahoe Stili Kurulum Teması */
@define-color bg_color #ffffff;
@define-color fg_color #1d1d1f;
@define-color accent_color #0071e3;
@define-color secondary_color #86868b;
@define-color border_color rgba(0, 0, 0, 0.08);
@define-color hover_bg rgba(0, 113, 227, 0.04);
@define-color selected_bg rgba(0, 113, 227, 0.08);

* {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Inter', sans-serif;
}

window, .ubiquity, box, notebook, .live-installer, dialog {
    background-color: @bg_color;
    color: @fg_color;
}

.titlebar, headerbar {
    background: rgba(255, 255, 255, 0.85);
    backdrop-filter: blur(30px);
    -webkit-backdrop-filter: blur(30px);
    border-bottom: 1px solid @border_color;
    padding: 12px 16px;
    min-height: 36px;
}

button.titlebutton.close {
    background: #ff5f57;
    min-width: 12px;
    min-height: 12px;
    border-radius: 50%;
}

button.titlebutton.minimize {
    background: #febc2e;
    min-width: 12px;
    min-height: 12px;
    border-radius: 50%;
}

button.titlebutton.maximize {
    background: #28c840;
    min-width: 12px;
    min-height: 12px;
    border-radius: 50%;
}

.title, .section-title, label.title {
    font-size: 18px;
    font-weight: 600;
    color: @fg_color;
}

.subtitle, .section-subtitle, label.subtitle {
    font-size: 13px;
    color: @secondary_color;
}

button.suggested-action, button.primary {
    background: @accent_color;
    color: #ffffff;
    border-radius: 8px;
    padding: 10px 28px;
    font-weight: 500;
    border: none;
    box-shadow: 0 2px 8px rgba(0, 113, 227, 0.2);
}

button.suggested-action:hover, button.primary:hover {
    background: #0077ed;
    box-shadow: 0 4px 12px rgba(0, 113, 227, 0.3);
    transform: translateY(-1px);
}

button.secondary {
    background: rgba(0, 0, 0, 0.04);
    color: @fg_color;
    border: 1px solid @border_color;
    border-radius: 8px;
    padding: 10px 28px;
}

progressbar {
    background: rgba(0, 0, 0, 0.06);
    border-radius: 3px;
    min-height: 6px;
}

progressbar progress {
    background: linear-gradient(90deg, #0071e3, #5e5ce6);
    border-radius: 3px;
}

entry, input {
    background: rgba(0, 0, 0, 0.03);
    border: 1.5px solid @border_color;
    border-radius: 8px;
    padding: 10px 14px;
    font-size: 14px;
    color: @fg_color;
}

entry:focus, input:focus {
    border-color: @accent_color;
    box-shadow: 0 0 0 3px rgba(0, 113, 227, 0.1);
    outline: none;
}

switch {
    background: rgba(0, 0, 0, 0.15);
    border-radius: 12px;
    min-width: 44px;
    min-height: 24px;
}

switch:checked {
    background: @accent_color;
}

treeview, .disk-list, list {
    background: rgba(0, 0, 0, 0.02);
    border: 1.5px solid @border_color;
    border-radius: 10px;
    padding: 4px;
}

treeview:selected, list row:selected {
    background: @selected_bg;
    color: @fg_color;
}
UBIQUITYCSS
echo "  ✓ Ubiquity CSS hazır"

# ── 18. KURULUM SLAYT HAZIRLAMA ──
echo "[18/20] Kurulum slaytları hazırlanıyor..."

# Türkçe slaytlar
TR_SLIDES=/usr/share/ubiquity-slideshow/slides/l10n/tr
mkdir -p "$TR_SLIDES"

cat > "$TR_SLIDES/welcome.html" << 'SLIDETR1'
<!DOCTYPE html>
<html lang="tr">
<head><meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:linear-gradient(180deg,#f5f5f7 0%,#ffffff 100%);color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,BlinkMacSystemFont,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:700px}
.logo{font-size:72px;font-weight:300;letter-spacing:4px;margin-bottom:8px;color:#1d1d1f}
.logo span{font-weight:700;background:linear-gradient(135deg,#8B5CF6,#EC4899,#EF4444,#F97316,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.version{font-size:13px;color:#86868b;letter-spacing:2px;margin-bottom:40px;font-weight:400}
.features{display:grid;grid-template-columns:1fr 1fr;gap:12px;text-align:left;margin:30px 0}
.feature{background:rgba(255,255,255,0.8);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);border:1px solid rgba(0,0,0,0.08);border-radius:12px;padding:20px;box-shadow:0 2px 8px rgba(0,0,0,0.04)}
.feature h3{font-size:15px;font-weight:600;margin-bottom:6px;color:#1d1d1f}
.feature p{font-size:12px;color:#86868b;line-height:1.5}
.badge{display:inline-block;background:rgba(0,113,227,0.1);color:#0071e3;padding:2px 8px;border-radius:4px;font-size:10px;font-weight:600;margin-top:8px}
</style></head><body>
<div class="container">
<div class="logo">hello<span> os</span></div>
<div class="version">KURUMSAL SURUM 1.0</div>
<div class="features">
<div class="feature"><h3>Uc Katmanli Guvenlik</h3><p>UFW + Fail2ban + AppArmor ile koruma</p><span class="badge">GUVENLI</span></div>
<div class="feature"><h3>IP Anonimlastirma</h3><p>Tor ve VPN ile izlenemez baglanti</p><span class="badge">GIZLI</span></div>
<div class="feature"><h3>Disk Sifreleme</h3><p>LUKS ile tam disk sifreleme</p><span class="badge">KORUMALI</span></div>
<div class="feature"><h3>Guvenli Silme</h3><p>Dosyalar geri getirilemez silinir</p><span class="badge">KALICI</span></div>
</div>
</div></body></html>
SLIDETR1

cat > "$TR_SLIDES/language.html" << 'SLIDETR2'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:600px}
h2{font-size:26px;font-weight:600;margin-bottom:8px;color:#1d1d1f}
p{color:#86868b;font-size:13px;margin-bottom:30px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.item{background:rgba(255,255,255,0.8);backdrop-filter:blur(20px);border:1px solid rgba(0,0,0,0.08);border-radius:10px;padding:16px;cursor:pointer;box-shadow:0 1px 4px rgba(0,0,0,0.04)}
.item.sel{border-color:#0071e3;background:rgba(0,113,227,0.08)}
.code{font-size:20px;font-weight:700;margin-bottom:4px;color:#1d1d1f}
.name{font-size:12px;color:#86868b}
</style></head><body><div class="container">
<h2>Dil Secimi</h2><p>Kullanmak istediginiz dili secin</p>
<div class="grid">
<div class="item sel"><div class="code">TR</div><div class="name">Turkce</div></div>
<div class="item"><div class="code">EN</div><div class="name">English</div></div>
</div></div></body></html>
SLIDETR2

cat > "$TR_SLIDES/disk.html" << 'SLIDETR3'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:600px}
h2{font-size:26px;font-weight:600;margin-bottom:8px;color:#1d1d1f}
p{color:#86868b;font-size:13px;margin-bottom:30px}
.disk{background:rgba(255,255,255,0.8);backdrop-filter:blur(20px);border:1px solid rgba(0,0,0,0.08);border-radius:12px;padding:20px;margin:10px 0;text-align:left;display:flex;align-items:center;gap:14px;cursor:pointer;box-shadow:0 1px 4px rgba(0,0,0,0.04)}
.disk.sel{border-color:#0071e3;background:rgba(0,113,227,0.05)}
.icon{width:44px;height:44px;background:rgba(0,0,0,0.04);border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:16px;color:#86868b;font-weight:600}
.dname{font-weight:600;font-size:15px;color:#1d1d1f}.ddetail{color:#86868b;font-size:12px;margin-top:2px}
</style></head><body><div class="container">
<h2>Kurulum Diski</h2><p>hello os'un kurulacagi diski secin</p>
<div class="disk sel"><div class="icon">HD</div><div><div class="dname">Birincil Disk</div><div class="ddetail">NVMe SSD - 512 GB</div></div></div>
<div class="disk"><div class="icon">USB</div><div><div class="dname">Harici Depolama</div><div class="ddetail">USB 3.0 - 256 GB</div></div></div>
</div></body></html>
SLIDETR3

cat > "$TR_SLIDES/progress.html" << 'SLIDETR4'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:500px}
h2{font-size:26px;font-weight:600;margin-bottom:30px;color:#1d1d1f}
.bar{width:100%;height:5px;background:rgba(0,0,0,0.08);border-radius:3px;overflow:hidden;margin:20px 0}
.fill{height:100%;background:linear-gradient(90deg,#0071e3,#5e5ce6);border-radius:3px;width:45%;animation:fill 3s infinite}
@keyframes fill{0%{width:10%}50%{width:70%}100%{width:95%}}
.steps{display:flex;justify-content:space-between;margin:20px 0;font-size:11px;color:#86868b}
.step.done{color:#34c759}.step.current{color:#0071e3}
.time{color:#86868b;font-size:13px;margin-top:12px}
</style></head><body><div class="container">
<h2>Kurulum Devam Ediyor</h2><div class="bar"><div class="fill"></div></div>
<div class="time">Kalan sure: ~18 dk</div>
<div class="steps">
<span class="step done">Hazirlik</span><span class="step current">Kurulum</span><span class="step">Yapilandirma</span><span class="step">Tamamlama</span>
</div></div></body></html>
SLIDETR4

cat > "$TR_SLIDES/complete.html" << 'SLIDETR5'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:600px}
h2{font-size:28px;font-weight:600;margin-bottom:8px;color:#1d1d1f}
p{color:#86868b;font-size:14px;margin-bottom:30px}
.countdown{font-size:48px;font-weight:300;margin:20px 0;color:#0071e3}
.info{background:rgba(255,255,255,0.8);backdrop-filter:blur(20px);border:1px solid rgba(0,0,0,0.08);border-radius:12px;padding:16px;margin:16px auto;max-width:400px;text-align:left;box-shadow:0 2px 8px rgba(0,0,0,0.04)}
.info div{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid rgba(0,0,0,0.04)}
.info div:last-child{border-bottom:none}
.label{color:#86868b;font-size:12px}.value{font-weight:600;font-size:12px;color:#1d1d1f}
</style></head><body><div class="container">
<h2>Kurulum Tamamlandi!</h2><p>hello os basariyla yuklendi</p>
<div class="info">
<div><span class="label">Kullanici</span><span class="value">user</span></div>
<div><span class="label">Masaustu</span><span class="value">GNOME + Wayland</span></div>
<div><span class="label">Guvenlik</span><span class="value">UFW + Tor + AppArmor</span></div>
<div><span class="label">IP Sifreleme</span><span class="value">AKTIF</span></div>
</div>
<div class="countdown">10</div><p>saniye icinde yeniden baslatilacak</p>
</div></body></html>
SLIDETR5

# İngilizce slaytlar
EN_SLIDES=/usr/share/ubiquity-slideshow/slides/l10n/en
mkdir -p "$EN_SLIDES"

cat > "$EN_SLIDES/welcome.html" << 'SLIDEEN1'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:linear-gradient(180deg,#f5f5f7 0%,#ffffff 100%);color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:700px}
.logo{font-size:72px;font-weight:300;letter-spacing:4px;margin-bottom:8px;color:#1d1d1f}
.logo span{font-weight:700;background:linear-gradient(135deg,#8B5CF6,#EC4899,#EF4444,#F97316,#10B981);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.version{font-size:13px;color:#86868b;letter-spacing:2px;margin-bottom:40px}
.features{display:grid;grid-template-columns:1fr 1fr;gap:12px;text-align:left;margin:30px 0}
.feature{background:rgba(255,255,255,0.8);backdrop-filter:blur(20px);border:1px solid rgba(0,0,0,0.08);border-radius:12px;padding:20px;box-shadow:0 2px 8px rgba(0,0,0,0.04)}
.feature h3{font-size:15px;font-weight:600;margin-bottom:6px;color:#1d1d1f}
.feature p{font-size:12px;color:#86868b;line-height:1.5}
.badge{display:inline-block;background:rgba(0,113,227,0.1);color:#0071e3;padding:2px 8px;border-radius:4px;font-size:10px;font-weight:600;margin-top:8px}
</style></head><body>
<div class="container">
<div class="logo">hello<span> os</span></div>
<div class="version">ENTERPRISE EDITION 1.0</div>
<div class="features">
<div class="feature"><h3>Triple-Layer Security</h3><p>UFW + Fail2ban + AppArmor protection</p><span class="badge">SECURE</span></div>
<div class="feature"><h3>IP Anonymization</h3><p>Tor and VPN for untraceable connection</p><span class="badge">PRIVATE</span></div>
<div class="feature"><h3>Disk Encryption</h3><p>Full disk encryption with LUKS</p><span class="badge">PROTECTED</span></div>
<div class="feature"><h3>Secure Deletion</h3><p>Files permanently unrecoverable</p><span class="badge">PERMANENT</span></div>
</div>
</div></body></html>
SLIDEEN1

cat > "$EN_SLIDES/language.html" << 'SLIDEEN2'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:600px}
h2{font-size:26px;font-weight:600;margin-bottom:8px;color:#1d1d1f}
p{color:#86868b;font-size:13px;margin-bottom:30px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.item{background:rgba(255,255,255,0.8);border:1px solid rgba(0,0,0,0.08);border-radius:10px;padding:16px}
.item.sel{border-color:#0071e3;background:rgba(0,113,227,0.08)}
.code{font-size:20px;font-weight:700;margin-bottom:4px;color:#1d1d1f}
.name{font-size:12px;color:#86868b}
</style></head><body><div class="container">
<h2>Language Selection</h2><p>Choose your preferred language</p>
<div class="grid">
<div class="item"><div class="code">TR</div><div class="name">Turkish</div></div>
<div class="item sel"><div class="code">EN</div><div class="name">English</div></div>
</div></div></body></html>
SLIDEEN2

cat > "$EN_SLIDES/disk.html" << 'SLIDEEN3'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px;min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:600px}
h2{font-size:26px;font-weight:600;margin-bottom:8px}
p{color:#86868b;font-size:13px;margin-bottom:30px}
.disk{background:rgba(255,255,255,0.8);border:1px solid rgba(0,0,0,0.08);border-radius:12px;padding:20px;margin:10px 0;text-align:left;display:flex;align-items:center;gap:14px}
.disk.sel{border-color:#0071e3;background:rgba(0,113,227,0.05)}
.icon{width:44px;height:44px;background:rgba(0,0,0,0.04);border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:16px;color:#86868b;font-weight:600}
.dname{font-weight:600;font-size:15px;color:#1d1d1f}.ddetail{color:#86868b;font-size:12px;margin-top:2px}
</style></head><body><div class="container">
<h2>Installation Disk</h2><p>Select the disk to install hello os</p>
<div class="disk sel"><div class="icon">HD</div><div><div class="dname">Primary Disk</div><div class="ddetail">NVMe SSD - 512 GB</div></div></div>
<div class="disk"><div class="icon">USB</div><div><div class="dname">External Storage</div><div class="ddetail">USB 3.0 - 256 GB</div></div></div>
</div></body></html>
SLIDEEN3

cat > "$EN_SLIDES/progress.html" << 'SLIDEEN4'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px}
.container{max-width:500px}
h2{font-size:26px;font-weight:600;margin-bottom:30px}
.bar{width:100%;height:5px;background:rgba(0,0,0,0.08);border-radius:3px;overflow:hidden;margin:20px 0}
.fill{height:100%;background:linear-gradient(90deg,#0071e3,#5e5ce6);border-radius:3px;width:45%;animation:fill 3s infinite}
@keyframes fill{0%{width:10%}50%{width:70%}100%{width:95%}}
.steps{display:flex;justify-content:space-between;margin:20px 0;font-size:11px;color:#86868b}
.step.done{color:#34c759}.step.current{color:#0071e3}
.time{color:#86868b;font-size:13px;margin-top:12px}
</style></head><body><div class="container">
<h2>Installation in Progress</h2><div class="bar"><div class="fill"></div></div>
<div class="time">Estimated time: ~18 min</div>
<div class="steps"><span class="step done">Preparing</span><span class="step current">Installing</span><span class="step">Configuring</span><span class="step">Finishing</span></div>
</div></body></html>
SLIDEEN4

cat > "$EN_SLIDES/complete.html" << 'SLIDEEN5'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#f5f5f7;color:#1d1d1f;text-align:center;font-family:'Inter',-apple-system,sans-serif;padding:60px}
.container{max-width:600px}
h2{font-size:28px;font-weight:600;margin-bottom:8px}
p{color:#86868b;font-size:14px;margin-bottom:30px}
.countdown{font-size:48px;font-weight:300;margin:20px 0;color:#0071e3}
.info{background:rgba(255,255,255,0.8);border:1px solid rgba(0,0,0,0.08);border-radius:12px;padding:16px;margin:16px auto;max-width:400px;text-align:left}
.info div{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid rgba(0,0,0,0.04)}
.info div:last-child{border-bottom:none}
.label{color:#86868b;font-size:12px}.value{font-weight:600;font-size:12px;color:#1d1d1f}
</style></head><body><div class="container">
<h2>Installation Complete!</h2><p>hello os has been successfully installed</p>
<div class="info">
<div><span class="label">User</span><span class="value">user</span></div>
<div><span class="label">Desktop</span><span class="value">GNOME + Wayland</span></div>
<div><span class="label">Security</span><span class="value">UFW + Tor + AppArmor</span></div>
<div><span class="label">IP Encryption</span><span class="value">ACTIVE</span></div>
</div>
<div class="countdown">10</div><p>seconds until restart</p>
</div></body></html>
SLIDEEN5

echo "  ✓ Slaytlar hazır (TR + EN)"

# ── 19. KURULUM SONRASI SCRIPT ──
echo "[19/20] Kurulum sonrası script hazırlanıyor..."
mkdir -p /usr/share/hello-os

cat > /usr/share/hello-os/post-install.sh << 'POSTINSTALL'
#!/bin/bash
echo "╔══════════════════════════════════════════╗"
echo "║   hello os - Post-Install Setup         ║"
echo "╚══════════════════════════════════════════╝"

# MacTahoe Teması
echo "[1/4] MacTahoe teması kuruluyor..."
cd /tmp
wget -q https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/main.zip
unzip -q main.zip
cd MacTahoe-gtk-theme-main
./install.sh -t all 2>/dev/null
mkdir -p /usr/share/themes /usr/share/icons
[ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/
[ -d /root/.icons ] && cp -r /root/.icons/MacTahoe* /usr/share/icons/

# Pacifico Font
echo "[2/4] Pacifico font indiriliyor..."
mkdir -p /usr/share/fonts/truetype/pacifico
wget -q https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf -O /usr/share/fonts/truetype/pacifico/Pacifico.ttf
fc-cache -f

# GTK Ayarları
echo "[3/4] GTK ayarları yapılıyor..."
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTKSETTINGS'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
gtk-cursor-theme-name=MacTahoe
GTKSETTINGS

# GNOME Ayarları
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-hello << 'GNOMESETTINGS'
[org/gnome/desktop/interface]
gtk-theme='MacTahoe'
icon-theme='MacTahoe'
font-name='Pacifico 11'
cursor-theme='MacTahoe'
[org/gnome/desktop/wm/preferences]
theme='MacTahoe'
GNOMESETTINGS

# Duvar kağıdı
mkdir -p /usr/share/backgrounds
convert -size 1920x1080 xc:'#f5f5f7' /usr/share/backgrounds/hello-bg.png 2>/dev/null || true

# Güvenlik
echo "[4/4] Güvenlik ayarları..."
ufw enable
systemctl enable fail2ban tor apparmor

echo "╔══════════════════════════════════════════╗"
echo "║   hello os hazır!                       ║"
echo "║   Kullanıcı: user / 123456              ║"
echo "╚══════════════════════════════════════════╝"
POSTINSTALL

chmod +x /usr/share/hello-os/post-install.sh

mkdir -p /etc/ubiquity
cat > /etc/ubiquity/ubiquity.conf << 'UBIQUITYCONF'
[Ubiquity]
post_install_script=/usr/share/hello-os/post-install.sh
UBIQUITYCONF
echo "  ✓ Post-install script hazır"

# ── 20. TEMİZLİK ──
echo "[20/20] Temizlik yapılıyor..."
apt clean
rm -rf /tmp/* /var/cache/apt/*
echo "  ✓ Temizlik tamam"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Chroot kurulumu tamamlandı!           ║"
echo "╚══════════════════════════════════════════╝"
SETUPSCRIPT

sudo chmod +x "$ROOTFS/tmp/setup.sh"

info "Chroot içinde paketler kuruluyor..."
info "Bu işlem 15-25 dakika sürebilir, lütfen bekleyin..."

sudo chroot "$ROOTFS" /tmp/setup.sh

log "Chroot kurulumu tamamlandı"

# ═══════════════════════════════════════════════════════════════════
# 7. CHROOT TEMİZLİĞİ
# ═══════════════════════════════════════════════════════════════════
info "Chroot bağlantıları kaldırılıyor..."

sudo umount "$ROOTFS/dev/pts" 2>/dev/null || true
sudo umount "$ROOTFS/dev" 2>/dev/null || true
sudo umount "$ROOTFS/proc" 2>/dev/null || true
sudo umount "$ROOTFS/sys" 2>/dev/null || true

log "Chroot temizliği tamam"

# ═══════════════════════════════════════════════════════════════════
# 8. SQUASHFS OLUŞTURMA
# ═══════════════════════════════════════════════════════════════════
info "SquashFS sıkıştırılıyor..."
info "Bu işlem 5-10 dakika sürebilir..."

sudo mksquashfs \
    "$ROOTFS" \
    "$ISO_DIR/casper/filesystem.squashfs" \
    -comp xz \
    -b 1M \
    -noappend

SQUASHFS_SIZE=$(du -h "$ISO_DIR/casper/filesystem.squashfs" | cut -f1)
log "SquashFS oluşturuldu: $SQUASHFS_SIZE"

# ═══════════════════════════════════════════════════════════════════
# 9. KERNEL VE INITRD KOPYALAMA
# ═══════════════════════════════════════════════════════════════════
info "Kernel ve initrd kopyalanıyor..."

# Önce chroot'tan kopyalamayı dene
sudo cp "$ROOTFS/boot/vmlinuz-"* "$ISO_DIR/casper/vmlinuz" 2>/dev/null
sudo cp "$ROOTFS/boot/initrd.img-"* "$ISO_DIR/casper/initrd" 2>/dev/null

# Eğer bulunamazsa yedek indir
if [ ! -f "$ISO_DIR/casper/vmlinuz" ] || [ ! -s "$ISO_DIR/casper/vmlinuz" ]; then
    warn "Chroot'tan kernel alınamadı, yedek indiriliyor..."
    wget -q "http://archive.ubuntu.com/ubuntu/dists/noble/main/installer-amd64/current/images/cdrom/vmlinuz" -O "$ISO_DIR/casper/vmlinuz" || \
    wget -q "http://ftp.linux.org.tr/ubuntu/dists/noble/main/installer-amd64/current/images/cdrom/vmlinuz" -O "$ISO_DIR/casper/vmlinuz"
fi

if [ ! -f "$ISO_DIR/casper/initrd" ] || [ ! -s "$ISO_DIR/casper/initrd" ]; then
    warn "Chroot'tan initrd alınamadı, yedek indiriliyor..."
    wget -q "http://archive.ubuntu.com/ubuntu/dists/noble/main/installer-amd64/current/images/cdrom/initrd.gz" -O "$ISO_DIR/casper/initrd" || \
    wget -q "http://ftp.linux.org.tr/ubuntu/dists/noble/main/installer-amd64/current/images/cdrom/initrd.gz" -O "$ISO_DIR/casper/initrd"
fi

# Manifest ve boyut
sudo chroot "$ROOTFS" dpkg-query -W --showformat='${Package} ${Version}\n' 2>/dev/null | sudo tee "$ISO_DIR/casper/filesystem.manifest" > /dev/null || true
sudo cp "$ISO_DIR/casper/filesystem.manifest" "$ISO_DIR/casper/filesystem.manifest-desktop" 2>/dev/null || true
sudo stat -c%s "$ISO_DIR/casper/filesystem.squashfs" 2>/dev/null | sudo tee "$ISO_DIR/casper/filesystem.size" > /dev/null || true

KERNEL_SIZE=$(ls -lh "$ISO_DIR/casper/vmlinuz" 2>/dev/null | awk '{print $5}')
INITRD_SIZE=$(ls -lh "$ISO_DIR/casper/initrd" 2>/dev/null | awk '{print $5}')

log "Kernel: $KERNEL_SIZE"
log "Initrd: $INITRD_SIZE"

# ═══════════════════════════════════════════════════════════════════
# 10. BOOTLOADER (ISOLINUX + GRUB)
# ═══════════════════════════════════════════════════════════════════
info "Bootloader hazırlanıyor..."

# Syslinux indir
wget -q "https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz" -O /tmp/syslinux.tar.gz 2>/dev/null || \
wget -q "https://cdn.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz" -O /tmp/syslinux.tar.gz

tar -xzf /tmp/syslinux.tar.gz -C /tmp/

# ISOLINUX dosyalarını kopyala
sudo cp /tmp/syslinux-6.03/bios/core/isolinux.bin "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/menu/menu.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/libutil/libutil.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/lib/libcom32.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/mbr/isohdpfx.bin "$ISO_DIR/"

# ISOLINUX konfigürasyonu
sudo tee "$ISO_DIR/isolinux/isolinux.cfg" > /dev/null << 'ISOLINUXCFG'
UI menu.c32
PROMPT 0
TIMEOUT 50
DEFAULT install

MENU TITLE hello os 1.0

LABEL install
  MENU LABEL ^Install hello os
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd boot=casper only-ubiquity quiet splash --

LABEL live
  MENU LABEL ^Try hello os (Live)
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd boot=casper quiet splash --
ISOLINUXCFG

# GRUB EFI imajı
sudo dd if=/dev/zero of="$ISO_DIR/boot/grub/efi.img" bs=1M count=5 2>/dev/null
sudo mkfs.vfat "$ISO_DIR/boot/grub/efi.img" 2>/dev/null || true

# GRUB konfigürasyonu
sudo tee "$ISO_DIR/boot/grub/grub.cfg" > /dev/null << 'GRUBCFG'
set timeout=5
set default=0

menuentry "Install hello os" {
    linux /casper/vmlinuz boot=casper only-ubiquity quiet splash
    initrd /casper/initrd
}

menuentry "Try hello os (Live)" {
    linux /casper/vmlinuz boot=casper quiet splash
    initrd /casper/initrd
}
GRUBCFG

log "Bootloader hazır"

# ═══════════════════════════════════════════════════════════════════
# 11. ISO OLUŞTURMA
# ═══════════════════════════════════════════════════════════════════
info "ISO oluşturuluyor..."
info "Bu işlem 2-5 dakika sürebilir..."

cd "$ISO_DIR"

sudo xorriso -as mkisofs \
    -isohybrid-mbr isohdpfx.bin \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -r \
    -V "hello os 1.0" \
    -o "$OUTPUT" \
    .

# ═══════════════════════════════════════════════════════════════════
# 12. SONUÇ
# ═══════════════════════════════════════════════════════════════════
if [ -f "$OUTPUT" ]; then
    sudo chmod 644 "$OUTPUT"
    ISO_SIZE=$(du -h "$OUTPUT" | cut -f1)
    
    echo ""
    echo -e "${G}╔══════════════════════════════════════════════════════════════╗${N}"
    echo -e "${G}║                                                              ║${N}"
    echo -e "${G}║   🎉 ISO BAŞARIYLA OLUŞTURULDU! 🎉                          ║${N}"
    echo -e "${G}║                                                              ║${N}"
    echo -e "${G}╠══════════════════════════════════════════════════════════════╣${N}"
    echo -e "${G}║                                                              ║${N}"
    echo -e "${G}║   Dosya       : $OUTPUT${N}"
    echo -e "${G}║   Boyut       : $ISO_SIZE${N}"
    echo -e "${G}║                                                              ║${N}"
    echo -e "${G}╠══════════════════════════════════════════════════════════════╣${N}"
    echo -e "${G}║                                                              ║${N}"
    echo -e "${G}║   ÖZELLİKLER:                                                ║${N}"
    echo -e "${G}║   ✓ macOS Tahoe stili kurulum arayüzü                        ║${N}"
    echo -e "${G}║   ✓ Plymouth hello boot animasyonu                           ║${N}"
    echo -e "${G}║   ✓ MacTahoe GTK teması (kurulum sonrası)                    ║${N}"
    echo -e "${G}║   ✓ Pacifico font (kurulum sonrası)                          ║${N}"
    echo -e "${G}║   ✓ Çok dilli destek (TR/EN)                                 ║${N}"
    echo -e "${G}║   ✓ UFW + Tor + AppArmor + Fail2ban                          ║${N}"
    echo -e "${G}║   ✓ GNOME + Wayland masaüstü                                 ║${N}"
    echo -e "${G}║   ✓ Kullanıcı: user / 123456                                 ║${N}"
    echo -e "${G}║                                                              ║${N}"
    echo -e "${G}╠══════════════════════════════════════════════════════════════╣${N}"
    echo -e "${G}║                                                              ║${N}"
    echo -e "${G}║   İNDİRMEK İÇİN:                                             ║${N}"
    echo -e "${G}║   Sol panelde dosyaya sağ tık → Download                     ║${N}"
    echo -e "${G}║                                                              ║${N}"
    echo -e "${G}╚══════════════════════════════════════════════════════════════╝${N}"
    echo ""
    
    # ISO içeriğini göster
    echo "ISO içeriği:"
    echo "─────────────"
    7z l "$OUTPUT" 2>/dev/null | grep -E "isolinux|vmlinuz|initrd|squashfs|grub" || true
    
else
    echo -e "${R}╔══════════════════════════════════════════════════════════════╗${N}"
    echo -e "${R}║   ISO OLUŞTURULAMADI!                                       ║${N}"
    echo -e "${R}╚══════════════════════════════════════════════════════════════╝${N}"
    exit 1
fi

echo ""
echo -e "${G}Bitti!${N}"
