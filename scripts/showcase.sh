#!/bin/bash
# Builds previews/showcase.gif, the picture at the top of the README: nine of the preview GIFs playing side by side.
# Run in scripts/ after the previews it uses have been rendered. Needs ffmpeg.
FFMPEG="${FFMPEG:-ffmpeg}"
LIST="comic-intro photo-stack paper-tear video-wall freeze-frame variety-caption pen-mark zoom-callout split-screen"
cd "$(dirname "$0")/../previews" || exit 1
inputs=(); filter=""; i=0
for n in $LIST; do
  inputs+=(-i "$n.gif")
  filter="$filter[$i:v]fps=12,scale=280:158:flags=lanczos,pad=284:162:2:2:color=0x101014[v$i];"
  i=$((i + 1))
done
"$FFMPEG" -y -loglevel error "${inputs[@]}" -filter_complex \
  "${filter}[v0][v1][v2][v3][v4][v5][v6][v7][v8]xstack=inputs=9:layout=0_0|w0_0|w0+w1_0|0_h0|w0_h0|w0+w1_h0|0_h0+h1|w0_h0+h1|w0+w1_h0+h1,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
  -loop 0 showcase.gif
ls -la showcase.gif
