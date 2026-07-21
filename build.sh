#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║   hello os - Dil DEGISIMLI + Plymouth Sonradan            ║
# ║   macOS Tahoe Stili - TR/EN tam destek                   ║
# ╚══════════════════════════════════════════════════════════════╝

set -e
G='\033[0;32m' B='\033[0;34m' R='\033[0;31m' N='\033[0m'
log() { echo -e "${G}[✓]${N} $1"; }
info() { echo -e "${B}[*]${N} $1"; }

clear
echo -e "${B}"
echo "╔══════════════════════════════════════════╗"
echo "║   hello os - Cok Dilli Kurulum          ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${N}"

DISK=$(df -BG /tmp | awk 'NR==2{print $4}' | sed 's/G//')
info "Disk: ${DISK} GB"
[ "$DISK" -lt 5 ] && { echo "Disk yetersiz!"; exit 1; }

sudo apt update -qq
sudo apt install -y -qq debootstrap squashfs-tools xorriso wget p7zip-full isolinux unzip
log "Paketler hazir"

WORK="/tmp/hello-lang"
ROOTFS="$WORK/rootfs"
ISO_DIR="$WORK/iso"
OUTPUT="/workspaces/Hello-os/hello-os-multilang.iso"

sudo rm -rf "$WORK"
mkdir -p "$ROOTFS" "$ISO_DIR"/{casper,isolinux,boot/grub}

# ═══════════════════════════════════════════════════════════════
# 1. BASE
# ═══════════════════════════════════════════════════════════════
info "Ubuntu base indiriliyor..."
sudo debootstrap --arch=amd64 noble "$ROOTFS" http://archive.ubuntu.com/ubuntu/
log "Base hazir"

# ═══════════════════════════════════════════════════════════════
# 2. SISTEM (COK DILLI)
# ═══════════════════════════════════════════════════════════════
sudo mount --bind /dev "$ROOTFS/dev"
sudo mount --bind /proc "$ROOTFS/proc"
sudo mount --bind /sys "$ROOTFS/sys"
sudo cp /etc/resolv.conf "$ROOTFS/etc/"

sudo tee "$ROOTFS/tmp/setup.sh" > /dev/null << 'SETUP'
#!/bin/bash
echo "=== hello os - Cok Dilli Sistem ==="

# Locale olustur (TR ve EN)
locale-gen tr_TR.UTF-8 en_US.UTF-8
update-locale LANG=tr_TR.UTF-8

apt update
apt install -y --no-install-recommends \
    casper ubiquity ubiquity-frontend-gtk ubiquity-slideshow-ubuntu \
    network-manager wireless-tools wpasupplicant \
    linux-image-generic sudo locales wget curl \
    gnome-session gnome-shell gnome-terminal gnome-control-center \
    nautilus gdm3 xorg xwayland gnome-shell-extensions \
    gnome-tweaks gnome-themes-extra gtk2-engines-murrine \
    git unzip \
    ubuntu-drivers-common software-properties-common \
    ufw fail2ban tor torsocks wireguard openvpn \
    cryptsetup lvm2 apparmor apparmor-profiles \
    firejail macchanger secure-delete \
    language-pack-tr language-pack-en \
    language-selector-common

# Plymouth'u SIL
apt purge -y plymouth plymouth-themes plymouth-x11 2>/dev/null || true
rm -rf /usr/share/plymouth /etc/plymouth
update-initramfs -u

# ═══════════════════════════════════════════════════════════════
# COK DILLI KURULUM SLAYT HAZIRLAMA
# ═══════════════════════════════════════════════════════════════

# ---- TURKCE SLAYT HAZIRLAMA ----
mkdir -p /usr/share/ubiquity-slideshow/slides/l10n/tr

# Slayt 1: Hos Geldiniz (TR)
cat > /usr/share/ubiquity-slideshow/slides/l10n/tr/welcome.html << 'S1TR'
<!DOCTYPE html><html lang="tr"><head><meta charset="UTF-8">
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
<div class="feature"><h3>Uc Katmanli Guvenlik</h3><p>UFW + Fail2ban + AppArmor ile cok katmanli koruma</p><span class="badge">GUVENLI</span></div>
<div class="feature"><h3>IP Anonimlastirma</h3><p>Tor ve VPN entegrasyonu ile izlenemez baglanti</p><span class="badge">GIZLI</span></div>
<div class="feature"><h3>Disk Sifreleme</h3><p>LUKS ile tam disk sifreleme destegi</p><span class="badge">KORUMALI</span></div>
<div class="feature"><h3>Guvenli Silme</h3><p>Dosyalar geri getirilemez sekilde silinir</p><span class="badge">KALICI</span></div>
</div>
</div></body></html>
S1TR

# Slayt 2: Dil Secimi (TR)
cat > /usr/share/ubiquity-slideshow/slides/l10n/tr/language.html << 'S2TR'
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
S2TR

# Slayt 3: Disk Secimi (TR)
cat > /usr/share/ubiquity-slideshow/slides/l10n/tr/disk.html << 'S3TR'
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
S3TR

# Slayt 4: Ilerleme (TR)
cat > /usr/share/ubiquity-slideshow/slides/l10n/tr/progress.html << 'S4TR'
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
S4TR

# Slayt 5: Tamamlandi (TR)
cat > /usr/share/ubiquity-slideshow/slides/l10n/tr/complete.html << 'S5TR'
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
S5TR

# ---- INGILIZCE SLAYT HAZIRLAMA ----
mkdir -p /usr/share/ubiquity-slideshow/slides/l10n/en

# Slayt 1: Welcome (EN)
cat > /usr/share/ubiquity-slideshow/slides/l10n/en/welcome.html << 'S1EN'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
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
<div class="version">ENTERPRISE EDITION 1.0</div>
<div class="features">
<div class="feature"><h3>Triple-Layer Security</h3><p>UFW + Fail2ban + AppArmor multi-layer protection</p><span class="badge">SECURE</span></div>
<div class="feature"><h3>IP Anonymization</h3><p>Untraceable connection with Tor and VPN integration</p><span class="badge">PRIVATE</span></div>
<div class="feature"><h3>Disk Encryption</h3><p>Full disk encryption support with LUKS</p><span class="badge">PROTECTED</span></div>
<div class="feature"><h3>Secure Deletion</h3><p>Files are permanently deleted, unrecoverable</p><span class="badge">PERMANENT</span></div>
</div>
</div></body></html>
S1EN

# Slayt 2: Language (EN)
cat > /usr/share/ubiquity-slideshow/slides/l10n/en/language.html << 'S2EN'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
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
<h2>Language Selection</h2><p>Choose your preferred language</p>
<div class="grid">
<div class="item"><div class="code">TR</div><div class="name">Turkish</div></div>
<div class="item sel"><div class="code">EN</div><div class="name">English</div></div>
</div></div></body></html>
S2EN

# Slayt 3: Disk (EN)
cat > /usr/share/ubiquity-slideshow/slides/l10n/en/disk.html << 'S3EN'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
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
<h2>Installation Disk</h2><p>Select the disk to install hello os</p>
<div class="disk sel"><div class="icon">HD</div><div><div class="dname">Primary Disk</div><div class="ddetail">NVMe SSD - 512 GB</div></div></div>
<div class="disk"><div class="icon">USB</div><div><div class="dname">External Storage</div><div class="ddetail">USB 3.0 - 256 GB</div></div></div>
</div></body></html>
S3EN

# Slayt 4: Progress (EN)
cat > /usr/share/ubiquity-slideshow/slides/l10n/en/progress.html << 'S4EN'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
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
<h2>Installation in Progress</h2><div class="bar"><div class="fill"></div></div>
<div class="time">Estimated time: ~18 min</div>
<div class="steps">
<span class="step done">Preparing</span><span class="step current">Installing</span><span class="step">Configuring</span><span class="step">Finishing</span>
</div></div></body></html>
S4EN

# Slayt 5: Complete (EN)
cat > /usr/share/ubiquity-slideshow/slides/l10n/en/complete.html << 'S5EN'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
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
<h2>Installation Complete!</h2><p>hello os has been successfully installed</p>
<div class="info">
<div><span class="label">User</span><span class="value">user</span></div>
<div><span class="label">Desktop</span><span class="value">GNOME + Wayland</span></div>
<div><span class="label">Security</span><span class="value">UFW + Tor + AppArmor</span></div>
<div><span class="label">IP Encryption</span><span class="value">ACTIVE</span></div>
</div>
<div class="countdown">10</div><p>seconds until restart</p>
</div></body></html>
S5EN

# ═══════════════════════════════════════════════════════════════
# KURULUM SONRASI
# ═══════════════════════════════════════════════════════════════
mkdir -p /usr/share/hello-os

cat > /usr/share/hello-os/post-install.sh << 'POST'
#!/bin/bash
# Dil kontrolu
CURRENT_LANG=$(grep LANG /etc/default/locale | cut -d= -f2 | cut -d. -f1)

if [ "$CURRENT_LANG" = "tr_TR" ]; then
    MSG_THEME="[1/5] MacTahoe temasi kuruluyor..."
    MSG_FONT="[2/5] Pacifico font indiriliyor..."
    MSG_PLYMOUTH="[3/5] Plymouth boot animasyonu kuruluyor..."
    MSG_GTK="[4/5] GTK ayarlari..."
    MSG_GNOME="[5/5] GNOME ve guvenlik..."
    MSG_DONE="hello os hazir!"
    MSG_USER="Kullanici"
else
    MSG_THEME="[1/5] Installing MacTahoe theme..."
    MSG_FONT="[2/5] Downloading Pacifico font..."
    MSG_PLYMOUTH="[3/5] Installing Plymouth boot animation..."
    MSG_GTK="[4/5] GTK settings..."
    MSG_GNOME="[5/5] GNOME and security..."
    MSG_DONE="hello os is ready!"
    MSG_USER="User"
fi

echo "╔══════════════════════════════════════════╗"
echo "║   hello os - Post-Install Setup         ║"
echo "╚══════════════════════════════════════════╝"

echo "$MSG_THEME"
cd /tmp
wget -q https://github.com/vinceliuice/MacTahoe-gtk-theme/archive/main.zip
unzip -q main.zip
cd MacTahoe-gtk-theme-main
./install.sh -t all 2>/dev/null
mkdir -p /usr/share/themes /usr/share/icons
[ -d /root/.themes ] && cp -r /root/.themes/MacTahoe* /usr/share/themes/

echo "$MSG_FONT"
mkdir -p /usr/share/fonts/truetype/pacifico
wget -q https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf -O /usr/share/fonts/truetype/pacifico/Pacifico.ttf
fc-cache -f

echo "$MSG_PLYMOUTH"
apt update
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

echo "$MSG_GTK"
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTK'
[Settings]
gtk-theme-name=MacTahoe
gtk-icon-theme-name=MacTahoe
gtk-font-name=Pacifico 11
gtk-cursor-theme-name=MacTahoe
GTK

echo "$MSG_GNOME"
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-hello << 'DCNF'
[org/gnome/desktop/interface]
gtk-theme='MacTahoe'
icon-theme='MacTahoe'
font-name='Pacifico 11'
cursor-theme='MacTahoe'
[org/gnome/desktop/wm/preferences]
theme='MacTahoe'
DCNF

mkdir -p /usr/share/backgrounds
convert -size 1920x1080 xc:'#f5f5f7' /usr/share/backgrounds/hello-bg.png 2>/dev/null || true

ufw enable
systemctl enable fail2ban tor apparmor

useradd -m -s /bin/bash -G sudo,adm user 2>/dev/null
echo "user:123456" | chpasswd 2>/dev/null

mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
WaylandEnable=true
GDM

systemctl enable gdm
echo "╔══════════════════════════════════════════╗"
echo "║   $MSG_DONE                       ║"
echo "║   $MSG_USER: user / 123456             ║"
echo "╚══════════════════════════════════════════╝"
POST
chmod +x /usr/share/hello-os/post-install.sh

mkdir -p /etc/ubiquity
cat > /etc/ubiquity/ubiquity.conf << 'UBI'
[Ubiquity]
post_install_script=/usr/share/hello-os/post-install.sh
UBI

# Sistemde de dil degisimi kalici olsun
cat > /etc/default/locale << 'LOCALE'
LANG=tr_TR.UTF-8
LC_ALL=tr_TR.UTF-8
LOCALE

apt clean
rm -rf /tmp/*
SETUP

sudo chmod +x "$ROOTFS/tmp/setup.sh"
info "Sistem hazirlaniyor..."
sudo chroot "$ROOTFS" /tmp/setup.sh
log "Sistem hazir"

# ═══════════════════════════════════════════════════════════════
# ISO
# ═══════════════════════════════════════════════════════════════
sudo umount "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" 2>/dev/null || true

sudo mksquashfs "$ROOTFS" "$ISO_DIR/casper/filesystem.squashfs" -comp xz -b 1M
sudo cp "$ROOTFS/boot/vmlinuz-"* "$ISO_DIR/casper/vmlinuz" 2>/dev/null || true
sudo cp "$ROOTFS/boot/initrd.img-"* "$ISO_DIR/casper/initrd" 2>/dev/null || true

wget -q https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz -O /tmp/syslinux.tar.gz
tar -xzf /tmp/syslinux.tar.gz -C /tmp/

sudo cp /tmp/syslinux-6.03/bios/core/isolinux.bin "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/menu/menu.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/libutil/libutil.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/com32/lib/libcom32.c32 "$ISO_DIR/isolinux/"
sudo cp /tmp/syslinux-6.03/bios/mbr/isohdpfx.bin "$ISO_DIR/"

sudo tee "$ISO_DIR/isolinux/isolinux.cfg" > /dev/null << EOF
UI menu.c32
PROMPT 0
TIMEOUT 50
DEFAULT install
MENU TITLE hello os 1.0
LABEL install
  MENU LABEL ^Install hello os
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd boot=casper only-ubiquity quiet splash --
EOF

sudo dd if=/dev/zero of="$ISO_DIR/boot/grub/efi.img" bs=1M count=5 2>/dev/null
sudo tee "$ISO_DIR/boot/grub/grub.cfg" > /dev/null << EOF
set timeout=5
menuentry "Install hello os" { linux /casper/vmlinuz boot=casper only-ubiquity quiet splash; initrd /casper/initrd; }
EOF

cd "$ISO_DIR"
sudo xorriso -as mkisofs \
    -isohybrid-mbr isohdpfx.bin \
    -b isolinux/isolinux.bin -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
    -isohybrid-gpt-basdat -r -V "hello os 1.0" \
    -o "$OUTPUT" .

if [ -f "$OUTPUT" ]; then
    sudo chmod 644 "$OUTPUT"
    echo ""
    echo -e "${G}==============================================${N}"
    echo -e "${G}   COK DILLI ISO HAZIR!${N}"
    echo -e "${G}   $OUTPUT${N}"
    echo -e "${G}   Boyut: $(du -h "$OUTPUT" | cut -f1)${N}"
    echo -e "${G}   Diller: Turkce + English${N}"
    echo -e "${G}   Plymouth sonradan kurulur${N}"
    echo -e "${G}==============================================${N}"
fi
