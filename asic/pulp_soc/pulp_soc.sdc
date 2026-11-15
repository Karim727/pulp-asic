# =============================================================================
# pulp_soc.sdc - timing constraints for the pulp_soc block (SKY130, LibreLane)
#
# Clocking (see gf22_FLL.sv): the 3 FLLs are pass-through stubs, so the SoC,
# peripheral and cluster clocks all come from ref_clk_i.
#
#   ref_clk_i   main clock          period = CLOCK_PERIOD from config.yaml
#   jtag_tck_i  JTAG / debug clock  slow, asynchronous to ref_clk
#   cam_clk_i   camera pixel clock  asynchronous (uDMA camera interface)
#   i2s_slave_sck_i  I2S bit clock  asynchronous (uDMA I2S)
#
# Not clocks for timing: slow_clk_i (32 kHz, sampled by synchronizers),
# test_clk_i (unused). Both are false paths.
# =============================================================================

set CLK_PER   $::env(CLOCK_PERIOD)
set JTAG_PER  100.0
set CAM_PER   50.0
set I2S_PER   100.0

# I/O budget: 20% of the clock period outside this block
set IO_DLY    [expr 0.2 * $CLK_PER]

# -----------------------------------------------------------------------------
# 1. Clocks
# -----------------------------------------------------------------------------
create_clock -name ref_clk  -period $CLK_PER  [get_ports ref_clk_i]
create_clock -name jtag_tck -period $JTAG_PER [get_ports jtag_tck_i]
create_clock -name cam_clk  -period $CAM_PER  [get_ports cam_clk_i]
create_clock -name i2s_sck  -period $I2S_PER  [get_ports i2s_slave_sck_i]

# no timing between these domains (CDC is handled by synchronizers in the RTL)
set_clock_groups -asynchronous \
  -group {ref_clk} -group {jtag_tck} -group {cam_clk} -group {i2s_sck}

set_clock_uncertainty 0.25 [all_clocks]
set_clock_transition  0.15 [all_clocks]

# -----------------------------------------------------------------------------
# 2. False paths: resets, static config pins, non-timed clocks
# -----------------------------------------------------------------------------
# asynchronous resets (synchronized inside soc_clk_rst_gen / jtag)
set_false_path -from [get_ports {rstn_glob_i jtag_trst_ni}]
# slow / unused clocks
set_false_path -from [get_ports {slow_clk_i test_clk_i}]
# quasi-static mode / boot / DFT pins (set once at power-up)
set_false_path -from [get_ports {dft_test_mode_i dft_cg_enable_i mode_select_i boot_l2_i bootsel_i[*]}]
# cluster interface: async FIFO pointers/data (gray-coded, synchronized in the CDC FIFOs)
set_false_path -from [get_ports async_*]
set_false_path -to   [get_ports async_*]

# -----------------------------------------------------------------------------
# 3. I/O delays (everything else is synchronous to ref_clk)
# -----------------------------------------------------------------------------
# ports that are clocks, async or already constrained above
set SKIP_PORTS {ref_clk_i jtag_* cam_clk_i i2s_slave_sck_i slow_clk_i test_clk_i
                rstn_glob_i dft_* mode_select_i boot_l2_i bootsel_i* async_*
                cluster_clk_o cluster_rtc_o}

proc ports_without {ports patterns} {
  set out {}
  foreach p $ports {
    set name [get_full_name $p]
    set skip 0
    foreach pat $patterns {
      if {[string match $pat $name]} { set skip 1; break }
    }
    if {!$skip} { lappend out $p }
  }
  return $out
}

set sync_inputs  [ports_without [all_inputs]  $SKIP_PORTS]
set sync_outputs [ports_without [all_outputs] $SKIP_PORTS]

set_input_delay  $IO_DLY -clock ref_clk $sync_inputs
set_output_delay $IO_DLY -clock ref_clk $sync_outputs

# JTAG data pins are timed against jtag_tck
set_input_delay  [expr 0.2 * $JTAG_PER] -clock jtag_tck [get_ports {jtag_tms_i jtag_tdi_i}]
set_output_delay [expr 0.2 * $JTAG_PER] -clock jtag_tck [get_ports jtag_tdo_o]

# -----------------------------------------------------------------------------
# 4. Port environment
# -----------------------------------------------------------------------------
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y [all_inputs]
set_load 0.05 [all_outputs]

# derating (same as riscv_core)
set_timing_derate -early 0.95
set_timing_derate -late  1.05
