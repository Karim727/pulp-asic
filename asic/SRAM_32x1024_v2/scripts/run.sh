#!/bin/bash
# run.sh - build a small SRAM with DRC/LVS ON and report the DRC result per rule
#
# Run it inside the OpenRAM nix shell (tools: magic, netgen, klayout, python):
#   cd ~/OpenRAM && nix develop
#   cd <pulp-asic>/asic/SRAM_32x1024_v2
#   bash scripts/run.sh                          # config/sram_32x1024.py
#   bash scripts/run.sh config/<other>.py        # any other config
#
# OpenRAM code: OPENRAM_DIR (default ~/projects/OpenRAM_dev), must be at the
# commit in OPENRAM_COMMIT (OpenRAM dev branch).
#
# Outputs:
#   logs/<name>.log                      full OpenRAM log
#   runs/<name>/env.txt                  magic/netgen versions + PDK actually used
#   runs/<name>/openram_temp/            OpenRAM temp files (kept with -k)
#   runs/<name>/drc_why.txt              DRC errors per rule
#   runs/<name>/drc_cells.txt            DRC errors per cell
#   macro/<name>/                        GDS/LEF/LIB/V
set -e
HERE=$(cd "$(dirname "$0")" && pwd)          # scripts/
ROOT=$(cd "$HERE/.." && pwd)                  # SRAM_32x1024_v2/
CFG=$(readlink -f "${1:-$ROOT/config/sram_32x1024.py}")
NAME=$(basename "$CFG" .py)
OPENRAM_DIR=${OPENRAM_DIR:-$HOME/projects/OpenRAM_dev}

# check the OpenRAM version against the pinned commit
WANT=$(cat "$ROOT/OPENRAM_COMMIT")
HAVE=$(git -C "$OPENRAM_DIR" rev-parse HEAD 2>/dev/null || echo unknown)
if [ "$HAVE" != "$WANT" ]; then
  echo "WARNING: $OPENRAM_DIR is at $HAVE, expected $WANT (see README)"
fi

export OPENRAM_HOME=$OPENRAM_DIR/compiler
export OPENRAM_TECH=$OPENRAM_DIR/technology
export PYTHONPATH=$OPENRAM_HOME
# PDK that OpenRAM was installed with (ciel e8294524, 2022.07.29).
# The .magicrc loads the DRC rules from $PDK_ROOT/sky130A, so this MUST be set.
export PDK_ROOT=${OPENRAM_PDK_ROOT:-$HOME/openram_pdk}
export OPENRAM_TMP=$ROOT/runs/$NAME/openram_temp

rm -rf "$ROOT/runs/$NAME"
mkdir -p "$OPENRAM_TMP" "$ROOT/logs" "$ROOT/macro"   # OpenRAM uses os.mkdir (no parents)
LOG=$ROOT/logs/$NAME.log

{
  echo "date     : $(date)"
  echo "config   : $CFG"
  echo "openram  : $OPENRAM_DIR ($(cat "$OPENRAM_DIR/VERSION"), git $(git -C "$OPENRAM_DIR" rev-parse --short HEAD 2>/dev/null))"
  echo "magic    : $(command -v magic) $(magic --version 2>/dev/null)"
  echo "netgen   : $(command -v netgen)"
  echo "PDK_ROOT : $PDK_ROOT"
  echo "sky130A  : $(readlink -f "$PDK_ROOT/sky130A")"
} | tee "$ROOT/runs/$NAME/env.txt"

# -k keep temp files (needed for the per-rule report), -v print "error tiles" lines
set +e
python3 "$OPENRAM_DIR/sram_compiler.py" -k -v "$CFG" 2>&1 | tee "$LOG"
set -e

echo
echo "================ OpenRAM verification result ================"
grep -E "DRC Errors|LVS Errors|error tiles|ERROR" "$LOG" || echo "(no DRC/LVS lines in log - did DRC run?)"

echo
echo "================ DRC per rule ================"
bash "$HERE/drc_why.sh" "$OPENRAM_TMP" "$ROOT/runs/$NAME"
