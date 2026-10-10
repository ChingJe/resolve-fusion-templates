#!/bin/bash
# Render every preview GIF from the procedural test picture. Sizes are larger than the defaults so that
# text stays readable at 480 pixels wide. Run in scripts/ with Resolve open on the lab timeline.
# ./previews.sh            all of them
# ./previews.sh photo-stack comic-intro      only these
FU="${FUSCRIPT:-/c/Program Files/Blackmagic Design/DaVinci Resolve/fuscript.exe}"
cd "$(dirname "$0")"
HERE="$(pwd -W 2>/dev/null || pwd)"
T="$HERE/../templates"; X="$HERE/fixtures"
export FX_WIDTH=480 FX_STEPS=4
want() { [ ${#ONLY[@]} -eq 0 ] && return 0; for o in "${ONLY[@]}"; do [ "$o" = "$1" ] && return 0; done; return 1; }
shot() { # name, script, then environment assignments
  local name=$1 script=$2; shift 2
  want "$name" || return 0
  [ -f "build/$script" ] && script="build/$script"
  rm -f out/gif_[0-9]*.png
  env FX_PREFIX=gif_ "$@" timeout 500 "$FU" -l lua "$script" > "out/gif_$name.log" 2>&1
  python gif.py gif_ "../previews/$name.gif" 12 480
}
ONLY=("$@")
shot comic-intro     comicintro.lua FX_SRC=scenes
shot photo-stack     photostack.lua FX_SRC=scenes
shot time-slice      timeslice.lua  FX_SRC=scenes
shot punch-zoom      punchzoom.lua
shot video-wall      videowall.lua  FX_SRC=scenes
shot paper-tear      papertear.lua
shot chapter-bar     chapterbar.lua FX_TEXTFILE=$X/chapters.txt FX_SET="BarH=0.025,LabelSize=0.07"
shot number-counter  counter.lua
shot bar-chart       barchart.lua   FX_SET="BcTextSize=0.06"
shot kinetic-lines   kinetic.lua    FX_TEXTFILE=$X/lines.txt
shot variety-caption variety.lua    FX_TEXTFILE=$X/captions.txt FX_CUE="4=1,80=2,160=3" FX_SET="CapSize=0.13"
shot side-note       sidenote.lua   FX_SET="NoteSize=0.09,NoteThick=0.012"
shot text-label      compose.lua "FX_TEMPLATE=$T/Titles/Text Label.setting" FX_SPEC=$X/shapes.txt
shot text-label-combined compose.lua "FX_TEMPLATE=$T/Titles/Text Label.setting" FX_SPEC=$X/labels.txt
shot reaction-mark   compose.lua    "FX_TEMPLATE=$T/Titles/Reaction Mark.setting" FX_SPEC=$X/marks.txt
shot whip-pan        whippan.lua
shot zoom-through    zoomthrough.lua
shot stripe-wipe     stripewipe.lua FX_SET="BwRows=1"
shot glitch-cut      glitchcut.lua
shot glitch-hits     glitchhits.lua
shot sub-window      subwindow.lua
shot spotlight       spotlight.lua  FX_SET="SpZoom=1.8,SpRing=0.008,SpBlur=6"
shot freeze-frame    freezeframe.lua
shot echo            echo.lua
shot handmade        handmade.lua
shot countdown       countdown.lua  FX_SET="CdSize=0.14,CdRingSize=0.6"
shot karaoke-caption karaoke.lua    FX_TEXTFILE=$X/karaoke.txt FX_SET="KaSize=0.14"
shot hidden-word     hiddenword.lua FX_TEXTFILE=$X/hidden.txt FX_SET="HidSize=0.12"
shot pen-mark        compose.lua "FX_TEMPLATE=$T/Titles/Pen Mark.setting" FX_SPEC=$X/pens.txt
shot censor-patch    censor.lua     FX_SET="CzW=0.6,CzH=0.4,CzCell=0.06"
shot zoom-callout    zoomcallout.lua FX_PT="CoSrc=0.5:0.2" FX_SET="CoBorder=0.012,CoLineW=0.006"
shot click-ripple    clickripple.lua FX_TEXTFILE=$X/clicks.txt FX_SET="RipSize=0.35,RipThick=0.02,RipDot=0.05"
shot step-badge      compose.lua "FX_TEMPLATE=$T/Titles/Step Badge.setting" FX_SPEC=$X/badges.txt
shot dimension-line  dimension.lua  FX_SET="DimSize=0.09,DimThick=0.01,DimEndSize=0.07,DimOffset=0.09,DimEdge=0.005"
shot letterbox       letterbox.lua
shot split-screen    compose.lua "FX_TEMPLATE=$T/Effects/Split Screen.setting" FX_SPEC=$X/panes.txt FX_INPUTS=1
shot rec-frame       recframe.lua   FX_SET="RecSize=0.055,RecThick=0.007,RecCorners=0.12"
