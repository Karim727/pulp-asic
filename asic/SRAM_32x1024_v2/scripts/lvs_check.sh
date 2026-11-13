#!/bin/bash
# lvs_check.sh - re-run OpenRAM's own LVS (Magic extract + Netgen) on a modified GDS
#
# Uses the scripts OpenRAM wrote in its temp dir (same Magic/Netgen setup, same
# reference netlist <top>.sp), only the GDS is replaced. The gap-fill cell
# (drc_gap_fill: implant/nwell shapes only) is flattened into the top cell.
#
# Run inside the OpenRAM nix shell:
#   cd ~/OpenRAM && nix develop
#   cd <pulp-asic>/asic/SRAM_32x1024_v2
#   bash scripts/lvs_check.sh runs/sram_32x1024/openram_temp macro/sram_32x1024/sram_32x1024_final.gds sram_32x1024 runs/lvs_final
set -e
TMP=$(readlink -f "$1"); GDS=$(readlink -f "$2"); TOP="$3"; OUT="$4"
[ -f "$TMP/run_ext.sh" ] && [ -f "$TMP/run_lvs.sh" ] && [ -f "$GDS" ] && [ -n "$TOP" ] && [ -n "$OUT" ] || {
  echo "usage: $0 <openram_temp dir> <file.gds> <top_cell> <out_dir>"; exit 1; }
[ -f "$TMP/$TOP.sp" ] || { echo "reference netlist $TMP/$TOP.sp not found"; exit 1; }
export PDK_ROOT=${OPENRAM_PDK_ROOT:-$HOME/openram_pdk}   # .magicrc reads it

rm -rf "$OUT"; mkdir -p "$OUT"; OUT=$(readlink -f "$OUT")
# only what extraction + LVS need (no old .mag/.ext/.spice results)
cp "$TMP/.magicrc" "$TMP/setup.tcl" "$TMP/$TOP.sp" "$TMP/run_ext.sh" "$TMP/run_lvs.sh" "$OUT/"
cp "$GDS" "$OUT/$TOP.gds"
cd "$OUT"
sed -i 's/^gds flatten true$/gds flatglob drc_gap_fill\ngds flatten true/' run_ext.sh
chmod +x run_ext.sh run_lvs.sh

echo "gds : $GDS"
echo "pdk : $PDK_ROOT"
echo ">> extract (Magic) ..."
./run_ext.sh > ext.log 2>&1 || echo "   extract returned non-zero, see $OUT/ext.log"
[ -f "$TOP.spice" ] || { echo "no extracted netlist $TOP.spice, see $OUT/ext.log"; exit 1; }
echo ">> LVS (Netgen) ..."
./run_lvs.sh > lvs.log 2>&1 || true

echo
echo "================ LVS result ================"
grep -E "Final result|Circuits match|Netlists do not match|Cell pin lists are equivalent|mismatch" "$TOP.lvs.report" | tail -5 || true
echo "full report: $OUT/$TOP.lvs.report"
