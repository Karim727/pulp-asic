# SRAM_32x1024_v2: DRC/LVS-clean OpenRAM macro (sky130)

The `sram_32x1024` macro (1024 x 32 bit, 4 KB, 1RW, byte write) for the pulp_soc L2 and the cluster TCDM. This folder holds everything needed to rebuild it: config, scripts, and the pinned OpenRAM version.

The previous macro (`../SRAM_32x1024`) was generated with DRC/LVS disabled, so it was never checked. **Status: work in progress.** The flow below was validated on a 16x128 test macro (KLayout DRC = 0, LVS match). Running it on 32x1024 is next.

## Why this flow

| Finding | Consequence |
|---|---|
| Magic reports 10^5 to 10^6 errors inside the foundry SRAM bitcells, even on the silicon-proven PDK macro `sky130_sram_2kbyte_1rw1r_32x512_8`, where KLayout reports 0 | Magic does not support the foundry SRAM layers. **Signoff DRC uses KLayout (`sky130A_mr.drc`).** |
| OpenRAM stable (1.2.49): 533 KLayout errors, LVS fails | OpenRAM **dev** is used, pinned in `OPENRAM_COMMIT`: 337 errors, LVS matches |
| The remaining errors are implant/well spacing in the periphery (column_mux, delay_chain, control_logic) and the dnwell ring | They are fixed after generation by `scripts/gap_fill.py`. The PDK SRAM macros were also cleaned after generation (VLSIDA/sky130_sram_macros PR #2) |

## Setup (once)

```bash
# OpenRAM dev at the pinned commit
cd ~/projects
git clone -b dev https://github.com/VLSIDA/OpenRAM.git OpenRAM_dev
git -C OpenRAM_dev checkout $(cat <pulp-asic>/asic/SRAM_32x1024_v2/OPENRAM_COMMIT)

# tools (magic/netgen/klayout/python) from the OpenRAM nix shell
cd ~/OpenRAM && nix develop
# SRAM foundry cells for the dev branch
cd ~/projects/OpenRAM_dev
make sky130-install PDK_ROOT=$HOME/openram_pdk SRAM_LIB_DIR=$HOME/projects/sky130_fd_bd_sram_dev
```

`OPENRAM_DIR` (default `~/projects/OpenRAM_dev`) selects the OpenRAM code, and `OPENRAM_PDK_ROOT` (default `~/openram_pdk`) selects the PDK used by OpenRAM. Run all commands below inside `nix develop`, from this folder.

## Flow

| # | Step | Command | Output |
|---|---|---|---|
| 1 | Generate (OpenRAM DRC/LVS on) | `bash scripts/run.sh` | `macro/sram_32x1024/` (3 libs: TT/SS/FF), `logs/`, `runs/sram_32x1024/` |
| 2 | Gap fill + KLayout DRC | `bash scripts/gap_fill.sh macro/sram_32x1024/sram_32x1024.gds sram_32x1024` | `sram_32x1024_fill.gds`, `runs/klayout_fill_sram_32x1024/` |
| 3 | Fix any remaining errors | see "Manual fixes" | `sram_32x1024_final.gds` |
| 4 | KLayout DRC (signoff deck) | `bash scripts/drc_klayout.sh macro/sram_32x1024/sram_32x1024_final.gds sram_32x1024 ~/.ciel/sky130A runs/klayout_final` | must be **0** |
| 5 | LVS on the final GDS | `bash scripts/lvs_check.sh runs/sram_32x1024/openram_temp macro/sram_32x1024/sram_32x1024_final.gds sram_32x1024 runs/lvs_final` | must be **Circuits match uniquely** |

## Timing corners

`config/sram_32x1024.py` builds one `.lib` per corner, matching the LibreLane STA corners:

| Corner | Process | VDD | Temp | Use |
|---|---|---|---|---|
| `TT_1p8V_25C` | TT | 1.80 V | 25 C | typical |
| `SS_1p6V_100C` | SS | 1.60 V | 100 C | setup |
| `FF_1p95V_-40C` | FF | 1.95 V | -40 C | hold |

The libs use OpenRAM's analytical delay model (`analytical_delay = True`), which is approximate. For SPICE-characterized libs, set `analytical_delay = False`. This takes hours per corner on 32x1024.

## What `gap_fill.py` changes

All new shapes go into one new cell, `drc_gap_fill`, placed in the top cell. The original cells are not modified. The script adds only implant and well shapes, never metal, poly or diffusion, so connectivity does not change (LVS confirms this).

| Rule | Fix | Safety |
|---|---|---|
| nsdm.1 / psdm.1 (spacing 0.38) | Fill gaps between shapes of the same implant: closing, plus the bounding box of each violation (whole edges, 5 nm grid) | psdm stays >= 0.125 um from N-diff/N-tap; nsdm never on psdm |
| nwell.6 (dnwell ring) | Widen the nwell ring to 1.03 um inside dnwell | >= 0.34 um from N-diff, >= 0.13 um from P-diff/P-tap |

## Manual fixes

Corner cases not handled by the script. List each one here (rule, location in top-cell um, shape added), so the fix can be repeated after regeneration.

On the 16x128 test macro there was one: psdm.2, a Z-shaped psdm joint in control_logic. Fixed by adding psdm (94/20) at (32.265, 72.49) to (32.765, 72.61).

| Macro | Rule | Shape added (layer, x1 y1 x2 y2) |
|---|---|---|
| sram_32x1024 | (to be filled) | |

## Folder

| Path | Content |
|---|---|
| `OPENRAM_COMMIT` | pinned OpenRAM dev commit |
| `config/` | OpenRAM config |
| `scripts/` | flow scripts |
| `macro/sram_32x1024/` | generated views (gds/lef/lib/v/sp) and final GDS |
| `reports/` | final DRC/LVS reports (to be added) |
| `runs/`, `logs/` | temporary, not in git |
