#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║   hello os RENKLI Boot Animasyonu                          ║
# ║   Google Cloud Shell - Pacifico font                       ║
# ╚══════════════════════════════════════════════════════════════╝

G='\033[0;32m' N='\033[0m'
log() { echo -e "${G}[✓]${N} $1"; }

clear
echo "╔══════════════════════════════════════════╗"
echo "║   hello os - Renkli Boot Animasyonu     ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# PIL kur
pip install --user Pillow -q 2>/dev/null

# Pacifico font indir
[ ! -f Pacifico-Regular.ttf ] && wget -q "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf"

WORK=~/bootanim
rm -rf "$WORK"
mkdir -p "$WORK/part0" "$WORK/part1"
cd "$WORK"

echo "Renkli 'hello' animasyonu oluşturuluyor..."
echo ""

python3 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1080, 2400
FPS = 30
FRAMES = 45  # 1.5 saniye

# Pacifico font
try:
    font = ImageFont.truetype("../Pacifico-Regular.ttf", 160)
    print("Pacifico font yüklendi")
except:
    font = ImageFont.load_default()
    print("Varsayılan font")

# Renkler (HTML'deki gibi)
colors = [
    (139, 92, 246),   # h - mor
    (236, 72, 153),   # e - pembe
    (239, 68, 68),    # l1 - kırmızı
    (249, 115, 22),   # l2 - turuncu
    (16, 185, 129),   # o - yeşil
]

text = "hello"
print(f"Yazı: {text}")
print(f"Renkler: mor, pembe, kırmızı, turuncu, yeşil")
print("")

for i in range(FRAMES):
    img = Image.new('RGB', (W, H), color='#0A0A0F')
    draw = ImageDraw.Draw(img)
    
    # Her harfi ayrı renkte yaz
    x = W // 2
    y = H // 2
    
    # Toplam genişliği hesapla
    total_w = 0
    for ch in text:
        bbox = draw.textbbox((0, 0), ch, font=font)
        total_w += bbox[2] - bbox[0] + 8  # 8px boşluk
    
    start_x = (W - total_w) // 2
    
    # Her harfi çiz
    for j, ch in enumerate(text):
        color = colors[j]
        bbox = draw.textbbox((0, 0), ch, font=font)
        ch_w = bbox[2] - bbox[0]
        ch_h = bbox[3] - bbox[1]
        ch_y = (H - ch_h) // 2
        
        # Opacity animasyonu (fade-in)
        opacity = min(1.0, i / 15)  # 15 karede fade-in
        
        # Renk uygula
        draw.text((start_x, ch_y), ch, fill=color, font=font)
        start_x += ch_w + 8
    
    # Progress bar
    bar_y = H - 400
    bar_h = 6
    bar_w = W - 200
    bar_x = 100
    
    progress = (i * 100) // (FRAMES - 1)
    fill_w = (bar_w * progress) // 100
    
    # Bar arka plan
    draw.rectangle([bar_x, bar_y, bar_x + bar_w, bar_y + bar_h], fill=(40, 40, 50))
    # Bar dolgu
    draw.rectangle([bar_x, bar_y, bar_x + fill_w, bar_y + bar_h], fill=(139, 92, 246))
    
    img.save(f'part0/frame_{i:04d}.png')
    
    if i % 10 == 0 or i == FRAMES - 1:
        print(f"  Kare: {i+1}/{FRAMES}")

# Part1 - son kare (hello tam görünür)
img = Image.new('RGB', (W, H), color='#0A0A0F')
draw = ImageDraw.Draw(img)

total_w = 0
for ch in text:
    bbox = draw.textbbox((0, 0), ch, font=font)
    total_w += bbox[2] - bbox[0] + 8

start_x = (W - total_w) // 2

for j, ch in enumerate(text):
    color = colors[j]
    bbox = draw.textbbox((0, 0), ch, font=font)
    ch_h = bbox[3] - bbox[1]
    ch_y = (H - ch_h) // 2
    draw.text((start_x, ch_y), ch, fill=color, font=font)
    start_x += bbox[2] - bbox[0] + 8

img.save('part1/frame_0001.png')

# desc.txt
with open('desc.txt', 'w') as f:
    f.write(f'{W} {H} {FPS}\n')
    f.write('c 1 0 part0\n')
    f.write('c 0 0 part1\n')

print(f"\nToplam: {FRAMES} kare, {W}x{H}, {FPS} FPS")
print("Tamamlandı!")
PYEOF

# ZIP
rm -f bootanimation.zip
zip -0 -r bootanimation.zip desc.txt part0/ part1/ 2>/dev/null

if [ -f bootanimation.zip ]; then
    SIZE=$(du -h bootanimation.zip | cut -f1)
    
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   🎉 RENKLI BOOT ANİMASYONU HAZIR!     ║"
    echo "║   Dosya: $(pwd)/bootanimation.zip       ║"
    echo "║   Boyut: $SIZE                          ║"
    echo "║                                        ║"
    echo "║   Görünüm:                             ║"
    echo "║   h: mor  e: pembe  l: kırmızı        ║"
    echo "║   l: turuncu  o: yeşil                ║"
    echo "║                                        ║"
    echo "║   İNDİR: cloudshell download bootanimation.zip ║"
    echo "╚══════════════════════════════════════════╝"
fi
