# pulp_soc (ASIC flow, SKY130 / LibreLane)

The `pulp_soc` block (fabric controller, L2 memory, interconnect, peripherals) hardened as a macro.
Bender checkouts in `.bender/git/checkouts` get overwritten on re-checkout, so our edits live in `rtl/`, and `make flist` points `flist.yaml` to them.

## Quick start

```bash
make flist                                        # writes flist.yaml (see Makefile)
librelane config.yaml flist.yaml --run-tag <tag>  # same invocation as before, new tag
```

## Folder contents

| Path | What it is |
|---|---|
| `config.yaml` | LibreLane config: clock, SDC, L2 macros, floorplan |
| `pulp_soc.sdc` | Timing constraints |
| `Makefile` | Builds `flist.yaml` from bender plus the files in `rtl/` |
| `rtl/` | Modified and new RTL (see below) |
| `sram_32x1024/` | OpenRAM macro views (GDS/LEF/LIB/V). **GDS and LEF are git-ignored, so get them from the team** |
| `docs/` | Analysis reports (flip-flop breakdown, script) |

## RTL changes (`rtl/`)

The `Makefile` lists each file by name, with a one-line comment.

| File | Type | Change |
|---|---|---|
| `pulp_soc.sv` | replace | L2 resize: `L2_BANK_SIZE = 8192` (uDMA reach 128 KB), interleaved banks = 2048 words |
| `l2_ram_multi_bank.sv` | replace | Private banks = 4096 words; all L2 banks use `tc_sram_l2` |
| `soc_interconnect.sv` | replace | Slang fix: `LatencyMode` cast to `axi_pkg::xbar_latency_e` |
| `udma_subsystem.sv` | replace | Slang fix: hyper read logic `else if(!is_hyper_read_q)` → `else` |
| `riscv_register_file.sv` | replace | Slang fix: FP register file only when `FPU == 1 && Zfinx == 0` |
| `memory_models.sv` | **removed** | Old L2 models, unused; they need `generic_memory`, which has no model |
| `gf22_FLL.sv` | add | FLL stub: `FLLCLK = REFCLK`, `LOCK = 1`, `CFGACK = CFGREQ` |
| `generic_rom.sv` | add | Boot ROM as blackbox (hard macro later) |
| `tc_sram_l2.sv` | add | L2 cut built from N × `sram_32x1024` (N = NumWords / 1024); behavioral view in simulation |
| `rtl/pulp/jtag_tap_top.sv` | add | JTAG TAP from the PULP top (not part of package `pulp_soc`) |

## L2 memory: 576 KB → 64 KB

Start addresses are unchanged. Only the sizes changed.

| Region | Address | Size | Macros |
|---|---|---|---|
| Private 0 (FC data / stack) | `0x1C00_0000` – `0x1C00_4000` | 16 KB | 4 |
| Private 1 (FC code) | `0x1C00_8000` – `0x1C00_C000` | 16 KB | 4 |
| Interleaved (4 banks × 8 KB) | `0x1C01_0000` – `0x1C01_8000` | 32 KB | 8 |
| **Total** | | **64 KB** | **16 × sram_32x1024** (~4.5 mm²) |

Sizes come from the measured L2 usage of the regression tests (max 5.3 KB data, 13.4 KB code, 3.2 KB shared).

Matching changes outside this folder:
- `pulp-asic/rtl/includes/soc_mem_map.svh`: new end addresses (`PRIVATE_BANK0/1_END`, `TCDM_END`).
- `pulp-runtime`: `kernel/chips/pulp/link.ld` (3 L2 regions, so overflow is a link error), `include/archi/chips/pulp/memory_map.h` and `properties.h` (new sizes), and `include/implem/link.h` (L2 heap uses the real bank size).

## Clocking

The GF22 FLLs have no SKY130 equivalent. `gf22_FLL.sv` is a pass-through, so the SoC, peripheral and cluster clocks all come from **`ref_clk_i`**, whatever the JTAG `sel_fll_clk` setting. The ring oscillator can later drive `ref_clk_i` from chip top, with no change to `pulp_soc`.

`pulp_soc.sdc` defines:
- Clocks: `ref_clk` (`CLOCK_PERIOD`), plus `jtag_tck`, `cam_clk` and `i2s_sck`. All four are asynchronous to each other.
- False paths: resets, `slow_clk_i`, `test_clk_i`, static boot/mode/DFT pins, and the `async_*` cluster CDC ports.
- I/O delays: 20 % of the period on `ref_clk`; JTAG pins on `jtag_tck`.

## config.yaml highlights

- `CLOCK_PORT: ref_clk_i`, `PNR_SDC_FILE` / `SIGNOFF_SDC_FILE: pulp_soc.sdc`.
- `MACROS`: 16 × `sram_32x1024`, plus `PDN_MACRO_CONNECTIONS` for `vccd1`/`vssd1`. **Check the instance names against the netlist after the first synthesis run.**
- `VDD_PIN` / `GND_PIN` (`"power"` / `"ground"`) are commented out. These are the standard-cell pin names (sky130: `VPWR` / `VGND`).

## Simulation (QuestaSim) notes

- The RTL simulation (`sim/compile.tcl`, generated from `Bender.yml`) does **not** use `rtl/`. It reads `.bender` directly, so `.bender/.../pulp_soc.sv` and `l2_ram_multi_bank.sv` carry the same L2 edits locally. Plan: fork `pulp_soc` so these edits are versioned.
- `Bender.yml` must not list synthesis-only files for the simulation targets (missing include dirs and an empty `gf22_FLL` break the simulation). If they are needed, put them under `target: synthesis`.
- Regression with the 64 KB L2: `hello`, `fft2`, `fir`, `parMatrixMul8`, `conv16`, `mlDotp` and `testBitManipulation` pass.
- `tcdm_tests/L2_check` fails by design, because its address range is hard-coded for 512 KB. Use `tcdm_tests/L2_check_64k` instead (expected `0/256`).

## TODO

- [ ] First synthesis run: confirm macro instance names, check that `stat.rpt` shows `16 sram_32x1024`, with no `tc_sram` and no `gf22_FLL`
- [ ] Floorplan: macro placement
- [ ] Boot ROM macro / timing model
- [ ] Fork `pulp_soc` and point `Bender.yml` to it
