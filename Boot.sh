#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║   hello os - FONT SORUNU ÇÖZÜLDÜ                           ║
# ╚══════════════════════════════════════════════════════════════╝

G='\033[0;32m' N='\033[0m'
log() { echo -e "${G}[✓]${N} $1"; }

clear
echo "╔══════════════════════════════════════════╗"
echo "║   FONT SORUNU ÇÖZÜLDÜ                   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

pip install --user Pillow -q 2>/dev/null

# Pacifico font İNDİR ve KONTROL ET
FONT_FILE="$HOME/Pacifico-Regular.ttf"

if [ ! -f "$FONT_FILE" ]; then
    log "Font indiriliyor..."
    wget -q "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf" -O "$FONT_FILE"
fi

# Font dosyasını kontrol et
FONT_SIZE=$(stat -c%s "$FONT_FILE" 2>/dev/null || echo 0)
echo "Font dosyası: $FONT_FILE"
echo "Font boyutu: $FONT_SIZE byte"

if [ "$FONT_SIZE" -lt 1000 ]; then
    echo "Font indirme başarısız! Tekrar deneniyor..."
    rm "$FONT_FILE"
    curl -L "https://github.com/google/fonts/raw/main/ofl/pacifico/Pacifico-Regular.ttf" -o "$FONT_FILE"
    FONT_SIZE=$(stat -c%s "$FONT_FILE")
    echo "Yeni boyut: $FONT_SIZE byte"
fi

WORK=~/bootanim-final
rm -rf "$WORK"
mkdir -p "$WORK/part0" "$WORK/part1"
cd "$WORK"

# Font'u çalışma dizinine kopyala
cp "$FONT_FILE" .

echo ""
echo "Font hazır, animasyon oluşturuluyor..."
echo ""

python3 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os
import sys

W, H = 1080, 2400
FPS = 30
FRAMES = 45

# Font yükle - BİRDEN FAZLA YOL DENE
font = None
font_paths = [
    "Pacifico-Regular.ttf",
    "../Pacifico-Regular.ttf",
    os.path.expanduser("~/Pacifico-Regular.ttf"),
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
]

for path in font_paths:
    try:
        font = ImageFont.truetype(path, 400)
        print(f"Font yüklendi: {path} (400px)")
        break
    except:
        pass

if font is None:
    print("HİÇBİR font yüklenemedi! Varsayılan kullanılıyor.")
    font = ImageFont.load_default()

# Test: Yazı ne kadar büyük?
test_img = Image.new('RGB', (W, H), color='black')
test_draw = ImageDraw.Draw(test_img)

for size in [100, 200, 300, 400, 500, 600]:
    try:
        test_font = ImageFont.truetype(font_paths[0], size)
        tw = 0
        for ch in "hello":
            bbox = test_draw.textbbox((0, 0), ch, font=test_font)
            tw += bbox[2] - bbox[0] + 15
        print(f"  Font {size}px → toplam genişlik: {tw}px (ekran: {W}px) {'✓' if tw < W*0.9 else '✗ TAŞIYOR'}")
    except:
        pass

# En uygun boyutu bul
BEST_SIZE = 400
for size in [600, 500, 450, 400, 350, 300]:
    try:
        test_font = ImageFont.truetype(font_paths[0], size)
        tw = 0
        for ch in "hello":
            bbox = test_draw.textbbox((0, 0), ch, font=test_font)
            tw += bbox[2] - bbox[0] + 15
        if tw < W * 0.85:
            BEST_SIZE = size
            break
    except:
        pass

print(f"\nEn uygun font boyutu: {BEST_SIZE}px")
font = ImageFont.truetype(font_paths[0], BEST_SIZE)

# Renkler
colors = [
    (139, 92, 246),   # h - mor
    (236, 72, 153),   # e - pembe
    (239, 68, 68),    # l1 - kırmızı
    (249, 115, 22),   # l2 - turuncu
    (16, 185, 129),   # o - yeşil
]

text = "hello"
print(f"\nKareler oluşturuluyor ({FRAMES} kare)...")

for i in range(FRAMES):
    img = Image.new('RGB', (W, H), color='#0A0A0F')
    draw = ImageDraw.Draw(img)
    
    total_w = 0
    for ch in text:
        bbox = draw.textbbox((0, 0), ch, font=font)
        total_w += bbox[2] - bbox[0] + 15
    
    start_x = (W - total_w) // 2
    
    for j, ch in enumerate(text):
        bbox = draw.textbbox((0, 0), ch, font=font)
        ch_h = bbox[3] - bbox[1]
        ch_y = (H - ch_h) // 2
        draw.text((start_x, ch_y), ch, fill=colors[j], font=font)
        start_x += bbox[2] - bbox[0] + 15
    
    # Progress bar
    bar_y = H - 250
    bar_h = 8
    bar_w = W - 120
    bar_x = 60
    
    progress = (i * 100) // (FRAMES - 1)
    fill_w = (bar_w * progress) // 100
    
    draw.rectangle([bar_x, bar_y, bar_x + bar_w, bar_y + bar_h], fill=(40, 40, 50))
    draw.rectangle([bar_x, bar_y, bar_x + fill_w, bar_y + bar_h], fill=(139, 92, 246))
    
    img.save(f'part0/frame_{i:04d}.png')

# Part1
img = Image.new('RGB', (W, H), color='#0A0A0F')
draw = ImageDraw.Draw(img)
total_w = 0
for ch in text:
    bbox = draw.textbbox((0, 0), ch, font=font)
    total_w += bbox[2] - bbox[0] + 15

start_x = (W - total_w) // 2
for j, ch in enumerate(text):
    bbox = draw.textbbox((0, 0), ch, font=font)
    ch_h = bbox[3] - bbox[1]
    ch_y = (H - ch_h) // 2
    draw.text((start_x, ch_y), ch, fill=colors[j], font=font)
    start_x += bbox[2] - bbox[0] + 15
img.save('part1/frame_0001.png')

with open('desc.txt', 'w') as f:
    f.write(f'{W} {H} {FPS}\n')
    f.write('c 1 0 part0\n')
    f.write('c 0 0 part1\n')

print(f"\n✓ Tamamlandı! Font: {BEST_SIZE}px")
PYEOF

# ZIP
rm -f bootanimation.zip
zip -0 -r bootanimation.zip desc.txt part0/ part1/ 2>/dev/null

if [ -f bootanimation.zip ]; then
    cp bootanimation.zip /workspaces/Hello-os/ 2>/dev/null || true
    SIZE=$(du -h bootanimation.zip | cut -f1)
    
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   🎉 BOOT ANİMASYONU HAZIR!            ║"
    echo "║   Boyut: $SIZE                          ║"
    echo "║   Font: Pacifico (oto-boyutlu)         ║"
    echo "║   h:mor e:pembe l:kırmızı l:turuncu   ║"
    echo "║   o:yeşil                              ║"
    echo "║   Sağ tık → Download                   ║"
    echo "╚══════════════════════════════════════════╝"
fi
