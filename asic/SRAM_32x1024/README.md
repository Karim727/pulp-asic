# SRAM_32x1024: DRC/LVS-clean OpenRAM macro (sky130)

The `sram_32x1024` macro (1024 x 32 bit, 4 KB, 1RW, byte write) for the pulp_soc L2 and the cluster TCDM. This folder holds everything needed to rebuild it: config, scripts, and the pinned OpenRAM version.

This is the v2 macro. The previous one was generated with DRC/LVS disabled (never checked) and has been removed.

## Status: done (Nov 2026)

| Check | Result | Report |
|---|---|---|
| KLayout DRC (`sky130A_mr.drc`), raw OpenRAM GDS | 1300 (nsdm.1 1270, psdm.1 26, nwell.6 4) | `reports/drc_klayout_raw_per_rule.txt` |
| KLayout DRC after `gap_fill` | **0**, no manual edits | `reports/drc_klayout_final.lyrdb` |
| LVS (Magic + Netgen) on the final GDS | **Circuits match uniquely** (270248 devices, 68589 nets) | `reports/lvs_final_summary.txt` |

Final views are in `macro/sram_32x1024/`:
- `sram_32x1024_fill.gds`: the final GDS, use this one
- `sram_32x1024.lef` and `sram_32x1024.v`
- `sram_32x1024_{TT_1p8V_25C,SS_1p6V_100C,FF_1p95V_-40C}.lib`

Compared to `../SRAM_32x1024`, the size is 809.115 x 351.29 um (0.27 um wider), with the same 87 pins and pin names, so it is a drop-in replacement.

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
git -C OpenRAM_dev checkout $(cat <pulp-asic>/asic/SRAM_32x1024/OPENRAM_COMMIT)

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
| 1 | Generate | `bash scripts/run.sh` (or `OPENRAM_CHECK=0 bash scripts/run.sh` for views only) | `macro/sram_32x1024/` (3 libs: TT/SS/FF), `logs/`, `runs/sram_32x1024/` |
| 2 | Gap fill + KLayout DRC | `bash scripts/gap_fill.sh macro/sram_32x1024/sram_32x1024.gds sram_32x1024` | `sram_32x1024_fill.gds`, `runs/klayout_fill_sram_32x1024/` |
| 3 | LVS on the final GDS (see the memory note below) | `bash scripts/lvs_check.sh runs/sram_32x1024/openram_temp macro/sram_32x1024/sram_32x1024_fill.gds sram_32x1024 runs/lvs_final` | must be **Circuits match uniquely** |

`gap_fill.sh` runs the KLayout DRC itself, and the result must be **0**. To check any GDS separately: `bash scripts/drc_klayout.sh <gds> sram_32x1024 ~/.ciel/sky130A <out_dir>`.

**LVS memory:** Netgen flattens the bank (270k devices) and needs about 13 GB. On a machine with less RAM:
- add swap (`sudo fallocate -l 16G /swapfile_lvs && sudo chmod 600 /swapfile_lvs && sudo mkswap /swapfile_lvs && sudo swapon /swapfile_lvs`)
- stop `systemd-oomd` for the run (`sudo systemctl stop systemd-oomd.service systemd-oomd.socket`), otherwise it kills netgen as soon as swap is used
- the run takes about 30 min; afterwards `sudo systemctl start systemd-oomd.service`

The LVS needs the OpenRAM temp scripts, so generate once with DRC/LVS on (`bash scripts/run.sh`; its internal LVS may run out of memory, but the scripts are written first). Keep that `runs/<name>` folder, then generate the views with `OPENRAM_CHECK=0 bash scripts/run.sh`.

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
| nsdm.2 / psdm.2 (width 0.38) | Where a fill bridge forms a thin Z-shaped joint, extrude one edge by the missing width | Only shapes created by the fill; the side that stays out of the keepout |

## Manual fixes

None. The last corner case (a Z-shaped psdm joint in control_logic) is now handled by the min-width step of `gap_fill.py`. If a new macro still shows errors after `gap_fill`, list each manual fix here (rule, top-cell location, shape added), so it can be repeated after regeneration.

## Folder

| Path | Content |
|---|---|
| `OPENRAM_COMMIT` | pinned OpenRAM dev commit |
| `config/` | OpenRAM config |
| `scripts/` | flow scripts |
| `macro/sram_32x1024/` | generated views (gds/lef/lib/v/sp) and final GDS |
| `reports/` | DRC/LVS evidence (raw and final KLayout DRC, LVS summary) |
| `runs/`, `logs/` | temporary, not in git |
