#!/bin/bash
# Quick test render, run in scripts/: ./t.sh <script.lua in build/> <prefix> <steps> "<frames for the sheet>" [ENV=value ...]
FU="${FUSCRIPT:-/c/Program Files/Blackmagic Design/DaVinci Resolve/fuscript.exe}"
script=$1; prefix=$2; steps=$3; frames=$4; shift 4
[ -f "build/$script" ] && script="build/$script"
rm -f out/${prefix}[0-9][0-9][0-9][0-9].png
env FX_PREFIX=$prefix FX_STEPS=$steps "$@" timeout 280 "$FU" -l lua "$script" 2>&1 | tail -n +3
python sheet.py $prefix "$frames" 5 out/${prefix}_sheet.png 300
