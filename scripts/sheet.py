import sys, glob, os
from PIL import Image, ImageDraw
prefix = sys.argv[1]; frames = [int(a) for a in sys.argv[2].split(',')]; cols = int(sys.argv[3]); out = sys.argv[4]
tw = int(sys.argv[5]) if len(sys.argv) > 5 else 384
th = tw * 9 // 16
rows = (len(frames) + cols - 1) // cols
sheet = Image.new('RGB', (cols * tw, rows * th), (40, 40, 40))
for i, f in enumerate(frames):
    p = os.path.join('out', '%s%04d.png' % (prefix, f))
    if not os.path.exists(p): continue
    im = Image.open(p).convert('RGBA')
    bg = Image.new('RGBA', im.size, (0, 0, 0, 255)); bg.alpha_composite(im)
    im = bg.convert('RGB').resize((tw - 4, th - 4))
    sheet.paste(im, ((i % cols) * tw + 2, (i // cols) * th + 2))
    ImageDraw.Draw(sheet).text(((i % cols) * tw + 8, (i // cols) * th + 6), str(f), fill=(255, 255, 0))
sheet.save(out)
