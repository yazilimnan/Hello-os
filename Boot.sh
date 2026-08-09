#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║   hello os - DEV BOOT ANİMASYONU (Çok Büyük)              ║
# ╚══════════════════════════════════════════════════════════════╝

G='\033[0;32m' N='\033[0m'
log() { echo -e "${G}[✓]${N} $1"; }

clear
echo "╔══════════════════════════════════════════╗"
echo "║   DEV BOOT ANİMASYONU                   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

pip install --user Pillow -q 2>/dev/null

# Pacifico font kontrol
if [ ! -f Pacifico-Regular.ttf ]; then
    wget -q "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf"
fi

# Font gerçekten var mı?
ls -lh Pacifico-Regular.ttf
echo ""

WORK=~/bootanim-dev
rm -rf "$WORK"
mkdir -p "$WORK/part0" "$WORK/part1"
cd "$WORK"

python3 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1080, 2400
FPS = 30
FRAMES = 45

# Font kontrol ve yükleme
font_path = "../Pacifico-Regular.ttf"
try:
    font = ImageFont.truetype(font_path, 500)  # 500px!
    print(f"Font yüklendi: 500px ✓")
except Exception as e:
    print(f"Font hatası: {e}")
    print("Varsayılan font kullanılıyor (küçük olabilir)")
    font = ImageFont.load_default()

# Renkler
colors = [
    (139, 92, 246),   # h - mor
    (236, 72, 153),   # e - pembe
    (239, 68, 68),    # l1 - kırmızı
    (249, 115, 22),   # l2 - turuncu
    (16, 185, 129),   # o - yeşil
]

text = "hello"
print(f"Font boyutu: 500px")
print(f"Ekran: {W}x{H}")
print(f"Yazı: {text}")
print("")

# Önce bir test karesi oluştur - yazının boyutunu görelim
test_img = Image.new('RGB', (W, H), color='#0A0A0F')
test_draw = ImageDraw.Draw(test_img)

total_w = 0
max_h = 0
for ch in text:
    bbox = test_draw.textbbox((0, 0), ch, font=font)
    ch_w = bbox[2] - bbox[0]
    ch_h = bbox[3] - bbox[1]
    total_w += ch_w + 20
    max_h = max(max_h, ch_h)
    print(f"  '{ch}': {ch_w}x{ch_h}px")

print(f"\n  Toplam genişlik: {total_w}px (ekran: {W}px)")
print(f"  Maksimum yükseklik: {max_h}px (ekran: {H}px)")

if total_w > W:
    print("  ⚠ Yazı ekrandan taşıyor! Font küçültülmeli.")
elif total_w < W // 2:
    print("  ⚠ Yazı çok küçük! Font büyütülmeli.")
else:
    print("  ✓ Yazı boyutu ideal.")

print("")

# Kareleri oluştur
for i in range(FRAMES):
    img = Image.new('RGB', (W, H), color='#0A0A0F')
    draw = ImageDraw.Draw(img)
    
    total_w = 0
    for ch in text:
        bbox = draw.textbbox((0, 0), ch, font=font)
        total_w += bbox[2] - bbox[0] + 20
    
    start_x = (W - total_w) // 2
    
    for j, ch in enumerate(text):
        color = colors[j]
        bbox = draw.textbbox((0, 0), ch, font=font)
        ch_h = bbox[3] - bbox[1]
        ch_y = (H - ch_h) // 2
        draw.text((start_x, ch_y), ch, fill=color, font=font)
        start_x += bbox[2] - bbox[0] + 20
    
    # Progress bar
    bar_y = H - 250
    bar_h = 12
    bar_w = W - 120
    bar_x = 60
    
    progress = (i * 100) // (FRAMES - 1)
    fill_w = (bar_w * progress) // 100
    
    draw.rectangle([bar_x, bar_y, bar_x + bar_w, bar_y + bar_h], fill=(30, 30, 40))
    draw.rectangle([bar_x, bar_y, bar_x + fill_w, bar_y + bar_h], fill=(139, 92, 246))
    
    img.save(f'part0/frame_{i:04d}.png')

# Part1
img = Image.new('RGB', (W, H), color='#0A0A0F')
draw = ImageDraw.Draw(img)
total_w = 0
for ch in text:
    bbox = draw.textbbox((0, 0), ch, font=font)
    total_w += bbox[2] - bbox[0] + 20

start_x = (W - total_w) // 2
for j, ch in enumerate(text):
    bbox = draw.textbbox((0, 0), ch, font=font)
    ch_h = bbox[3] - bbox[1]
    ch_y = (H - ch_h) // 2
    draw.text((start_x, ch_y), ch, fill=colors[j], font=font)
    start_x += bbox[2] - bbox[0] + 20
img.save('part1/frame_0001.png')

with open('desc.txt', 'w') as f:
    f.write(f'{W} {H} {FPS}\n')
    f.write('c 1 0 part0\n')
    f.write('c 0 0 part1\n')

print(f"{FRAMES} kare oluşturuldu")
PYEOF

# ZIP
rm -f bootanimation.zip
zip -0 -r bootanimation.zip desc.txt part0/ part1/ 2>/dev/null

if [ -f bootanimation.zip ]; then
    cp bootanimation.zip /workspaces/Hello-os/ 2>/dev/null || true
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   DEV BOOT ANİMASYONU HAZIR!           ║"
    echo "║   Font: Pacifico 500px                 ║"
    echo "║   Progress: 12px kalınlığında          ║"
    echo "║   Sağ tık → Download                   ║"
    echo "╚══════════════════════════════════════════╝"
fi
