# gap_fill.py - close small implant / nwell gaps in an OpenRAM macro GDS (KLayout, Python)
#
# Run through gap_fill.sh (it passes the file names). What it does:
#   for each layer below:  closed = layer grown by space/2, then shrunk by space/2
#                          fill   = closed - original      (only the gaps that were closed)
#   the fill shapes are put in a new cell "drc_gap_fill", placed once in the top cell.
#   The original cells are NOT changed, so the fix is easy to see and to remove.
#
# Safety (fill must not change devices):
#   nsdm fill never goes on psdm; psdm fill stays 0.125um from N-diff/N-taps
#   nwell fill (only with FILL_NWELL=1) keeps 0.34um away from N-diffusion and 0.13um from P-taps
#   (nwell over an NMOS / P-tap would change the circuit)
import os
import pya

def var(name):
    v = globals().get(name) or os.environ.get(name.upper())
    if not v:
        raise SystemExit(f"missing variable {name}")
    return v

gds_in, gds_out, top_name = var("gds_in"), var("gds_out"), var("top")

ly = pya.Layout()
ly.read(gds_in)
top = ly.cell(top_name)
if top is None:
    raise SystemExit(f"top cell {top_name} not found")
dbu = ly.dbu

def um(x):
    return int(round(x / dbu))

def layer(l, d):
    return ly.layer(l, d)

def region(l, d):
    r = pya.Region(top.begin_shapes_rec(layer(l, d)))
    r.merge()
    return r

def close_fill(reg, space):
    # gaps strictly smaller than "space" get filled (1 dbu margin keeps legal gaps open)
    d = um(space / 2.0) - 1
    closed = reg.sized(d).sized(-d)
    # corner-to-corner gaps (shapes offset diagonally) are not fully closed by
    # sizing, so also fill the bounding box of every spacing violation
    # (box corners snapped outward to the 5nm manufacturing grid: x.1b)
    g = um(0.005)
    boxes = pya.Region()
    # whole_edges=True: use the full facing edges, so a corner-to-corner bridge
    # spans both shapes completely (a bridge only as wide as the gap leaves a
    # Z-shaped neck that fails the min-width rule)
    for ep in reg.space_check(um(space), True).each():
        b = ep.bbox()
        boxes.insert(pya.Box((b.left // g) * g, (b.bottom // g) * g,
                             -((-b.right) // g) * g, -((-b.top) // g) * g))
    return (closed + boxes) - reg

# sky130 GDS layers
NWELL, DIFF, TAP, NSDM, PSDM = (64, 20), (65, 20), (65, 44), (93, 44), (94, 20)

nwell = region(*NWELL)
diff  = region(*DIFF)
tap   = region(*TAP)
nsdm  = region(*NSDM)
psdm  = region(*PSDM)

# implants: nsdm.1 / psdm.1  min spacing 0.38um
ndiff = diff & nsdm          # NMOS diffusion + N-taps
pdiff = diff & psdm          # PMOS diffusion + P-taps
ndiff_all = ndiff + (tap & nsdm)
pdiff_all = pdiff + (tap & psdm)
nsdm_fill = close_fill(nsdm, 0.38) - psdm
# psdm gaps are often between two P-taps of mirrored cell rows, crossed by an
# nsdm strip with no diffusion under it (delay_chain). The fill may overlap
# that nsdm, but never comes closer than 0.125um to N-type diffusion/taps (nsdm
# must enclose N-diff by 0.125um, so this is the closest legal psdm edge).
psdm_fill = close_fill(psdm, 0.38) - ndiff_all.sized(um(0.125)) - nsdm_fill

# nwell: nwell.2a min spacing 1.27um (also removes the small pieces of nwell.1)
# OFF by default: on sram_16x128 it bridged the tiny 0.22x0.18um nwell pin
# rectangles of col_cap_array with thin 0.18um strips -> more nwell errors.
# Those rectangles are fixed in OpenRAM (sky130_col_cap_array.py) instead.
if os.environ.get("FILL_NWELL") == "1":
    ptap  = tap & psdm
    keepout = ndiff.sized(um(0.34)) + ptap.sized(um(0.13))
    nwell_fill = close_fill(nwell, 1.27) - keepout
else:
    nwell_fill = pya.Region()

# nwell.6: the nwell ring around the deep nwell must overlap it by >= 1.03um
# on the inside (OpenRAM draws 0.42um). Add nwell on the inner 1.03um band of
# dnwell, kept 0.34um away from N-diffusion and 0.13um from P-taps/P-diff.
DNWELL = (64, 18)
dnwell = region(*DNWELL)
band = dnwell - dnwell.sized(-um(1.03))
ring_fix = (band - nwell) - ndiff.sized(um(0.34)) - pdiff_all.sized(um(0.13))
ring_fix = ring_fix & nwell.sized(um(1.03))        # only next to the existing ring
nwell_fill = nwell_fill + ring_fix

fill_cell = ly.create_cell("drc_gap_fill")
for (l, d), reg, name in ((NSDM, nsdm_fill, "nsdm"), (PSDM, psdm_fill, "psdm"), (NWELL, nwell_fill, "nwell")):
    reg.merge()
    fill_cell.shapes(layer(l, d)).insert(reg)
    print(f"{name:6s}: {reg.count():6d} fill shapes, {reg.area() * dbu * dbu:10.3f} um^2")
top.insert(pya.CellInstArray(fill_cell.cell_index(), pya.Trans()))

ly.write(gds_out)
print(f"wrote {gds_out}")
