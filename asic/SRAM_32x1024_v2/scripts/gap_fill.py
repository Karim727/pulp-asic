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

# min-width repair (nsdm.2 / psdm.2, 0.38um): a fill bridge between two
# diagonally offset shapes forms a Z whose joint is only as thick as the gap
# (0.26um). For each width violation, extrude one of the two facing edges
# outward by the missing amount, on whichever side does not enter the keepout.
def thicken(base, fill, keepout, width, max_iter=3):
    w = um(width)
    for _ in range(max_iter):
        eps = (base + fill).merged().width_check(w, True)   # whole edges
        if eps.is_empty():
            break
        added = False
        for ep in eps.each():
            # only width problems created by our own fill (the generated
            # layout is width-clean, and SRAM core cells use special rules)
            if (pya.Region(ep.bbox().enlarged(1, 1)) & fill).is_empty():
                continue
            for ea, eb in ((ep.first, ep.second), (ep.second, ep.first)):
                if ea.dy() == 0 and eb.dy() == 0:            # horizontal edges
                    deficit = w - abs(ea.p1.y - eb.p1.y)
                    x1, x2 = sorted((ea.p1.x, ea.p2.x))
                    y = ea.p1.y
                    box = pya.Box(x1, y, x2, y + deficit) if y > eb.p1.y else pya.Box(x1, y - deficit, x2, y)
                elif ea.dx() == 0 and eb.dx() == 0:          # vertical edges
                    deficit = w - abs(ea.p1.x - eb.p1.x)
                    y1, y2 = sorted((ea.p1.y, ea.p2.y))
                    x = ea.p1.x
                    box = pya.Box(x, y1, x + deficit, y2) if x > eb.p1.x else pya.Box(x - deficit, y1, x, y2)
                else:
                    continue
                if deficit <= 0 or box.empty():
                    continue
                cand = pya.Region(box)
                if (cand & keepout).is_empty():
                    fill = fill + cand
                    added = True
                    break
        if not added:
            break
    return fill

psdm_fill = thicken(psdm, psdm_fill, ndiff_all.sized(um(0.125)) + nsdm_fill, 0.38)
nsdm_fill = thicken(nsdm, nsdm_fill, pdiff_all.sized(um(0.125)) + psdm + psdm_fill, 0.38)

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
