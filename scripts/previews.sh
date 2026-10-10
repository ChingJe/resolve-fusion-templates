#!/bin/bash
# Render every preview GIF from the procedural test picture. Sizes are larger than the defaults so that
# text stays readable at 480 pixels wide. Run in scripts/ with Resolve open on the lab timeline.
# ./previews.sh            all of them
# ./previews.sh photo-stack comic-intro      only these
FU="/c/Program Files/Blackmagic Design/DaVinci Resolve/fuscript.exe"
T="D:/davinci/templates"; X="D:/davinci/scripts/fixtures"
export FX_WIDTH=480 FX_STEPS=4
want() { [ ${#ONLY[@]} -eq 0 ] && return 0; for o in "${ONLY[@]}"; do [ "$o" = "$1" ] && return 0; done; return 1; }
shot() { # name, script, then environment assignments
  local name=$1 script=$2; shift 2
  want "$name" || return 0
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
