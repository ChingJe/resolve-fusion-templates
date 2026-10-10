#!/bin/bash
# Quick test render: ./t.sh <script.lua> <prefix> <steps> "<frames for the sheet>" [ENV=value ...]
FU="${FUSCRIPT:-/c/Program Files/Blackmagic Design/DaVinci Resolve/fuscript.exe}"
script=$1; prefix=$2; steps=$3; frames=$4; shift 4
rm -f out/${prefix}[0-9][0-9][0-9][0-9].png
env FX_PREFIX=$prefix FX_STEPS=$steps "$@" timeout 280 "$FU" -l lua "$script" 2>&1 | tail -n +3
python sheet.py $prefix "$frames" 5 out/${prefix}_sheet.png 300
