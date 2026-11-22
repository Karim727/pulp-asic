# ROM — boot ROM macro `rom_2048x32` (OpenRAM, SKY130)

2048 words × 32 bits, read-only, holding the PULP boot code
(`sim/boot/boot_code.cde`, md5 `dfea26978804ab4af5049293cdbbd04e`).
Generated with the OpenRAM ROM compiler plus our fixes (project `~/projects/rom_fix`).
Used by `asic/pulp_soc/rtl/generic_rom.sv` (boot ROM of `boot_rom.sv`).

## Files

| File | Use in the flow |
|---|---|
| `rom_2048x32.gds` | Layout (PnR / signoff), DRC-clean version with gap fill |
| `rom_2048x32.lef` | Abstract for PnR — 442.62 × 333.88 µm |
| `rom_2048x32_TT_1p8V_25C.lib` | Timing for synthesis / STA (estimated, TT 1.8 V 25 °C) |
| `rom_2048x32.v` | Behavioral model (RTL / gate-level simulation) and netlist view |
| `rom_2048x32.lvs.sp` | Transistor netlist for LVS |

## Status

| Check | Result |
|---|---|
| Content (layout vs boot code) | OK, same bit order as the Verilog model |
| KLayout DRC (`sky130A_mr.drc`) | **0 errors** |
| LVS (Magic + Netgen, sky130A) | **Circuits match uniquely** |
| OpenSTA (`.lib` + STA on the macro) | Loads; setup / hold met; no slew / cap violations |
| RTL regression (Questa, PULP testbench) | **Passed** with `generic_rom` = this macro (hello test boots from it and returns status 0) |
| `.lib` | Estimated, TT only (see below) |
| Silicon function | Known issue: row decoder race (see below) |

## Pins

| Pin | Dir | Description |
|---|---|---|
| `clk0` | in | Clock. Low = precharge, high = evaluate |
| `cs0` | in | Chip select, active high |
| `addr0[10:0]` | in | Word address |
| `dout0[31:0]` | out | Data |
| `vccd1`, `vssd1` | power | 1.8 V / ground |

## Timing

```
clk0      ____/‾‾‾‾‾‾‾‾\________/‾‾‾‾
addr0/cs0 ==X  valid   X============     setup to the clk0 RISE, hold to the clk0 FALL
dout0     ======X  valid  X------------  valid from rise + ~7 ns until the clk0 FALL
                          ^ captured here (clk0 falling edge)
```

* `dout0` is only valid while `clk0` is high; `generic_rom.sv` captures it on the
  falling edge, so the boot ROM keeps the original `generic_rom` interface
  (CEN active low, 1-cycle latency).
* From the `.lib` (TT): clk0 → dout0 ≈ 6.8–7.7 ns, min period **15.6 ns (~64 MHz)**,
  each clock phase ≥ 7.8 ns.
* The model drives `X` on `dout0` after the clk0 fall (precharge); define
  `ROM_MODEL_NO_X` to disable. `+define+ROM_MODEL_DELAY=<ns>` changes the access time.

## The `.lib` is estimated

Built from the SPICE characterization of the 256×32 version (TT), scaled for the
2048×32: clk0→dout0 fall +4.0 ns (256-cell bitline chain instead of 32), rise
+1.0 ns, fall transition ×0.5 (stronger output buffer), leakage ×7, setup / hold
and pin caps as in the 256×32, +10 % margin. SPICE of the 2048×32 at SS
(1.6 V, 100 °C) gave ~9.6 ns access, so the TT numbers are in the right range.

## Known issue — row decoder race (silicon only)

In SPICE this macro reads wrong words: OpenRAM's decoder address rails are
precharged high, and with 256 rows the 0-bit rails fall too slowly at the clock
rise, so extra wordlines are selected. Layout (DRC / LVS), regression and STA are
not affected. A fix (rails precharged low) is in `~/projects/rom_fix`
(`ROM_RAIL=1`) but not finished (LVS).

## OpenRAM ROM compiler fixes inside this macro

1. Data bit order reversed by OpenRAM → data written bit-reversed.
2. Bitline footer turned on before the wordline → 72 delay stages on precharge.
3. DRC fixes in the ROM layout generators + implant / met1 gap fill.
4. Slow output fall at SS → stronger output inverters (size 12, beta 1).
