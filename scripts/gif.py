# Turn rendered frames into an animated GIF: python gif.py <prefix[,prefix...]> <dest.gif> [fps] [width] [hold]
# Frames are scripts/out/<prefix>NNNN.png, played in order, one prefix after another. hold repeats the last frame.
import sys, glob, os, shutil, subprocess, tempfile
prefixes, dest = sys.argv[1].split(','), sys.argv[2]
fps = sys.argv[3] if len(sys.argv) > 3 else '12'
width = sys.argv[4] if len(sys.argv) > 4 else '480'
hold = int(sys.argv[5]) if len(sys.argv) > 5 else 0
here = os.path.dirname(os.path.abspath(__file__))
seq = tempfile.mkdtemp()
n = 0
for p in prefixes:
    for f in sorted(glob.glob(os.path.join(here, 'out', p + '[0-9][0-9][0-9][0-9].png'))):
        shutil.copy(f, os.path.join(seq, '%04d.png' % n)); n += 1
for _ in range(hold):
    shutil.copy(os.path.join(seq, '%04d.png' % (n - 1)), os.path.join(seq, '%04d.png' % n)); n += 1
vf = ('scale=%s:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];'
      '[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle') % width
subprocess.run([os.environ.get('FFMPEG') or shutil.which('ffmpeg') or 'C:/ffmpeg/bin/ffmpeg', '-y', '-loglevel', 'error', '-framerate', fps, '-i', os.path.join(seq, '%04d.png'),
                '-vf', vf, '-loop', '0', dest], check=True)
shutil.rmtree(seq)
print(dest, n, 'frames', os.path.getsize(dest) // 1024, 'KB')
