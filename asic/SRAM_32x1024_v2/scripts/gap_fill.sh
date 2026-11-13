#!/bin/bash
# gap_fill.sh - add implant / nwell gap fill to a macro GDS, then re-run KLayout DRC
#
# Run inside the OpenRAM nix shell (needs klayout):
#   cd ~/OpenRAM && nix develop
#   cd <pulp-asic>/asic/SRAM_32x1024_v2
#   bash scripts/gap_fill.sh macro/sram_32x1024/sram_32x1024.gds sram_32x1024
#
# Writes <name>_fill.gds next to the input (the original GDS is not touched),
# then runs drc_klayout.sh on it -> runs/klayout_fill_<name>/
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
IN=$(readlink -f "$1"); TOP="$2"; PDK=${3:-$HOME/.ciel/sky130A}
[ -f "$IN" ] && [ -n "$TOP" ] || { echo "usage: $0 <file.gds> <top_cell> [sky130A dir]"; exit 1; }
OUT="${IN%.gds}_fill.gds"

export GDS_IN="$IN" GDS_OUT="$OUT" TOP="$TOP"
klayout -b -r "$HERE/gap_fill.py" -rd gds_in="$IN" -rd gds_out="$OUT" -rd top="$TOP"

echo
echo "================ KLayout DRC on the filled GDS ================"
bash "$HERE/drc_klayout.sh" "$OUT" "$TOP" "$PDK" "$ROOT/runs/klayout_fill_$TOP"
