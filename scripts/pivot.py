# pick the point deepest inside a letter stroke (max distance to the glyph edge)
from PIL import Image, ImageFilter
im = Image.open('out/title0119.png').convert('RGBA')
a = im.split()[3].point(lambda v: 255 if v > 128 else 0)
W, H = a.size
depth = 0; cur = a; best = None
while True:
    nxt = cur.filter(ImageFilter.MinFilter(3))
    if nxt.getbbox() is None: break
    cur = nxt; depth += 1
bb = cur.getbbox()
px = cur.load()
pts = [(x, y) for y in range(bb[1], bb[3]) for x in range(bb[0], bb[2]) if px[x, y]]
# prefer the candidate nearest the frame centre
x, y = min(pts, key=lambda p: (p[0] - W/2)**2 + (p[1] - H/2)**2)
print('size', W, H, 'text bbox', a.getbbox(), 'depth px', depth, 'pivot px', x, y)
print('PIVOT %.4f %.4f' % ((x + 0.5) / W, 1 - (y + 0.5) / H))
