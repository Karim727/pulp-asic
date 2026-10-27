# pulp_soc (ASIC flow)

## Local modifications

Bender checkouts in `.bender/git/checkouts` get overwritten on re-checkout, so my edits live in `rtl/` and the generated `flist.yaml` points to them.

| File (`rtl/`) | Status | What changed |
|---|---|---|
| `generic_rom.sv` | Modified | Added `(* blackbox *)` before the module |
| `lint_stubs.sv` | New | Lint-only black-box stubs (`gf22_FLL`, `generic_memory`, `generic_rom`) |
| `riscv_core.sv` | Modified | Added `(* blackbox *)` before the import |
| `riscv_register_file.sv` | Modified | FP register file condition is now `FPU == 1 && Zfinx == 0` |
| `soc_interconnect.sv` | Modified | `LatencyMode` cast to `axi_pkg::xbar_latency_e'(...)` |
| `tc_sram.sv` | Modified | Replaced behavioral model with a blackbox stub so the L2 SRAM is treated as a macro |
| `udma_subsystem.sv` | Modified | Hyper read logic: `else if(!is_hyper_read_q)` changed to `else` |

## Makefile / flist

- Any `rtl/*.sv` with the same name as a flist entry replaces it in place (compile order kept) and duplicates are removed.
- Files in `rtl/` not in the flist are appended at the end.
- The extra include dir (`rtl/includes`) and `jtag_tap_top.sv` are still added.

## Usage

```bash
make flist
# each override must appear exactly once
grep -c "/<file>.sv$" flist.yaml
```
