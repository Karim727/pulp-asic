#!/bin/bash
# drc_why.sh - re-run OpenRAM's own DRC script and list the errors per rule and per cell
#
# Usage: ./drc_why.sh <openram_temp dir> [report dir]
#
# Uses run_drc.sh that OpenRAM wrote in the temp dir (same .magicrc, same
# blackboxed bitcells, same magic), so the total is the same number OpenRAM reports.
# Needs PDK_ROOT set the same way as in run.sh (the .magicrc reads it).
set -e
T=$(readlink -f "$1"); OUT=$(readlink -f "${2:-$T}")
cd "$T"
[ -f run_drc.sh ] || { echo "no run_drc.sh in $T (DRC did not run: check_lvsdrc = True?)"; exit 1; }
[ -n "$PDK_ROOT" ] || { echo "PDK_ROOT is not set"; exit 1; }

cat > drc_why.tcl << 'EOF'
puts "tech file: [tech filename]"
set fo [open drc_why_raw.txt w]
foreach {why boxes} [drc listall why] { puts $fo "[llength $boxes]\t$why" }
close $fo
set fc [open drc_cells_raw.txt w]
foreach p [drc listall count] { puts $fc "[lindex $p 1]\t[lindex $p 0]" }
close $fc
EOF

# same script as OpenRAM, plus "source drc_why.tcl" before the final count
# (stable: commands are inside run_drc.sh; dev: in a separate <cell>.drc.tcl)
TCL=$(ls *.drc.tcl 2>/dev/null | grep -v '_why' | head -1)
if [ -n "$TCL" ]; then
  sed 's/^drc count total$/source drc_why.tcl\ndrc count total/' "$TCL" > "${TCL%.drc.tcl}.drc_why.tcl"
  sed "s|$TCL|${TCL%.drc.tcl}.drc_why.tcl|" run_drc.sh > run_drc_why.sh
else
  sed 's/^drc count total$/source drc_why.tcl\ndrc count total/' run_drc.sh > run_drc_why.sh
fi
chmod +x run_drc_why.sh
./run_drc_why.sh > drc_why.log 2>&1 || true

sort -t$'\t' -k1,1nr drc_why_raw.txt   > "$OUT/drc_why.txt"   2>/dev/null || true
sort -t$'\t' -k1,1nr drc_cells_raw.txt > "$OUT/drc_cells.txt" 2>/dev/null || true

grep -E "tech file|Total DRC errors" drc_why.log || true
echo "--- per rule (count  rule) ---";  head -20 "$OUT/drc_why.txt"
echo "--- per cell (count  cell) ---";  head -20 "$OUT/drc_cells.txt"
echo "full: $OUT/drc_why.txt  $OUT/drc_cells.txt  $T/drc_why.log"
