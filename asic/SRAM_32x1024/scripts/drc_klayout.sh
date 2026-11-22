#!/bin/bash
# drc_klayout.sh - KLayout DRC (the sky130A_mr.drc deck LibreLane uses for signoff)
#                  on the final macro GDS, with a per-rule count
#
# Usage: bash drc_klayout.sh <file.gds> <top_cell> <sky130A dir> <out_dir>
#   bash scripts/drc_klayout.sh macro/sram_32x1024/sram_32x1024_final.gds sram_32x1024 ~/.ciel/sky130A runs/klayout_final
#
# Output in <out_dir>: report.lyrdb (open in KLayout: Tools > Marker Browser),
#                      drc_why.txt (count per rule), klayout.log
set -e
GDS=$(readlink -f "$1"); TOP="$2"; PDK=$(readlink -f "$3"); OUT="$4"
[ -f "$GDS" ] && [ -n "$TOP" ] && [ -d "$PDK" ] && [ -n "$OUT" ] || { echo "usage: $0 <gds> <top_cell> <sky130A dir> <out_dir>"; exit 1; }
DECK="$PDK/libs.tech/klayout/drc/sky130A_mr.drc"
[ -f "$DECK" ] || { echo "deck not found: $DECK"; exit 1; }
command -v klayout > /dev/null || { echo "klayout not in PATH (run inside 'nix develop' of ~/OpenRAM)"; exit 1; }
rm -rf "$OUT"; mkdir -p "$OUT"; OUT=$(readlink -f "$OUT")
{
  echo "klayout : $(command -v klayout) $(klayout -v 2>/dev/null)"
  echo "deck    : $DECK"
  echo "gds     : $GDS  top=$TOP"
} | tee "$OUT/info.txt"

klayout -b -zz -r "$DECK" \
  -rd input="$GDS" -rd topcell="$TOP" -rd top_cell="$TOP" \
  -rd report="$OUT/report.lyrdb" \
  -rd feol=true -rd beol=true -rd offgrid=true \
  -rd floating_met=false -rd seal=false -rd thr="$(nproc)" \
  > "$OUT/klayout.log" 2>&1 || echo "klayout returned non-zero, see $OUT/klayout.log"

python3 - "$OUT/report.lyrdb" "$OUT/drc_why.txt" << 'EOF'
import sys, collections, xml.etree.ElementTree as ET
rdb, out = sys.argv[1], sys.argv[2]
root = ET.parse(rdb).getroot()
desc = {}
def walk(cats, prefix=""):
    for c in cats.findall("category"):
        name = prefix + c.findtext("name", "").strip("'")
        desc[name] = c.findtext("description", "")
        sub = c.find("categories")
        if sub is not None: walk(sub, name + ".")
walk(root.find("categories"))
cnt = collections.Counter(i.findtext("category", "").strip("'") for i in root.find("items").findall("item"))
with open(out, "w") as f:
    for name, n in cnt.most_common():
        f.write(f"{n}\t{name}\t{desc.get(name, '')}\n")
print(f"Total KLayout DRC errors: {sum(cnt.values())}")
EOF
echo "--- per rule (count  rule  description) ---"; head -40 "$OUT/drc_why.txt"
