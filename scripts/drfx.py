# Pack templates/ into one .drfx file: a zip with the folder layout Resolve expects (Edit/Titles/..., Edit/Effects/...,
# Edit/Transitions/...). Dragging that file into Resolve installs every template in it, on Windows and on macOS.
# usage: python drfx.py [destination.drfx]     (default: dist/Resolve-Fusion-Templates.drfx, which git ignores)
import os
import sys
import zipfile

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, '..', 'templates')
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', 'dist', 'Resolve-Fusion-Templates.drfx')
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)

count = {}
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for kind in sorted(os.listdir(root)):
        folder = os.path.join(root, kind)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            if name.lower().endswith('.setting'):
                # fixed date, so the same templates always give the same file
                info = zipfile.ZipInfo('Edit/%s/%s' % (kind, name), date_time=(2020, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                with open(os.path.join(folder, name), 'rb') as f:
                    z.writestr(info, f.read())
                count[kind] = count.get(kind, 0) + 1

print(os.path.abspath(out), os.path.getsize(out) // 1024, 'KB')
print(', '.join('%s %d' % (k, v) for k, v in sorted(count.items())), '= %d templates' % sum(count.values()))
