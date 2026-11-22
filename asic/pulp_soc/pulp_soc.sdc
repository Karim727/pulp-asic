# =============================================================================
# pulp_soc.sdc - timing constraints for the pulp_soc block (SKY130, LibreLane)
#
# Clocking (see gf22_FLL.sv): the 3 FLLs are pass-through stubs, so the SoC,
# peripheral and cluster clocks all come from ref_clk_i.
#
#   ref_clk_i        main clock          period = CLOCK_PERIOD from config.yaml
#   jtag_tck_i       JTAG / debug clock  slow, asynchronous to ref_clk
#   cam_clk_i        camera pixel clock  asynchronous (uDMA camera interface)
#   i2s_slave_sck_i  I2S bit clock       asynchronous (uDMA I2S)
#
# Not clocks for timing: slow_clk_i (32 kHz, sampled by synchronizers),
# test_clk_i (unused). Both are false paths.
#
# The uDMA peripheral clock mux defaults to the un-divided input clock
# (r_clockout_mux = 1 at reset), so the gated peripheral output clocks below
# are constrained as divide-by-1 of ref_clk. Programmed divider modes are not
# covered by this static SDC.
# =============================================================================

# -----------------------------------------------------------------------------
# 0. Periods
# -----------------------------------------------------------------------------
set CLK_PER   $::env(CLOCK_PERIOD)
set JTAG_PER  100.0
set CAM_PER   50.0
set I2S_PER   100.0

# I/O budget: 20% of the main clock period outside this block
set IO_DLY [expr 0.2 * $CLK_PER]

# -----------------------------------------------------------------------------
# 1. Primary clocks
# -----------------------------------------------------------------------------
create_clock -name ref_clk  -period $CLK_PER  [get_ports ref_clk_i]
create_clock -name jtag_tck -period $JTAG_PER [get_ports jtag_tck_i]
create_clock -name cam_clk  -period $CAM_PER  [get_ports cam_clk_i]
create_clock -name i2s_sck  -period $I2S_PER  [get_ports i2s_slave_sck_i]

# -----------------------------------------------------------------------------
# 2. Generated clocks
#
# After synthesis, clock muxes/ICGs/gates are ordinary cells, so OpenSTA does
# not know that their outputs are clocks unless we say so. LibreLane also
# unpropagates all clocks for STAPrePNR. These definitions prevent the clock
# outputs from being timed as ordinary data paths.
# -----------------------------------------------------------------------------

# SPI clock: muxed peripheral clock -> ICG -> CPHA mux -> CPOL XOR
create_generated_clock -name spi_clk \
    -source [get_ports ref_clk_i] \
    -divide_by 1 \
    [get_ports spi_clk_o]

# SDIO clock: muxed peripheral clock -> ICG
create_generated_clock -name sdio_clk \
    -source [get_ports ref_clk_i] \
    -divide_by 1 \
    [get_ports sdio_clk_o]

# I2S bit clock output: muxed/clock-gated peripheral clock
create_generated_clock -name i2s_sck_out \
    -source [get_ports ref_clk_i] \
    -divide_by 1 \
    [get_ports i2s_slave_sck_o]

# HyperBus PHY clocks (clk_gen_hyper): flop dividers, invisible to STA without these
create_generated_clock -name hyper_clk0 \
    -source [get_ports ref_clk_i] -divide_by 2 \
    [get_pins -of_objects [get_nets soc_peripherals_i.i_udma.i_hyper.udma_hyperbus_i.clk0]  -filter {direction == output}]
    #[get_pins  _404568_/Q]

# clk90: negedge flop samples clk0 -> rises at ref edge 2, falls at 4, period 2x
create_generated_clock -name hyper_clk90 \
    -source [get_ports ref_clk_i] -edges {2 4 6} \
    [get_pins -of_objects [get_nets soc_peripherals_i.i_udma.i_hyper.udma_hyperbus_i.clk90] -filter {direction == output}]
   # [get_pins  _404569_/Q]





# Keep ref_clk-derived generated clocks in the ref_clk group. jtag/cam/i2s
set_clock_groups -asynchronous \
    -group {ref_clk spi_clk sdio_clk i2s_sck_out hyper_clk0 hyper_clk90} \
    -group {jtag_tck} \
    -group {cam_clk} \
    -group {i2s_sck}

set_clock_uncertainty 0.25 [all_clocks]
set_clock_transition  0.15 [all_clocks]

# -----------------------------------------------------------------------------
# 3. False paths
# -----------------------------------------------------------------------------
# Primary asynchronous resets (synchronized inside soc_clk_rst_gen / jtag)
set_false_path -from [get_ports {rstn_glob_i jtag_trst_ni}]

# Slow / unused clocks
set_false_path -from [get_ports {slow_clk_i test_clk_i}]

# Quasi-static mode / boot / DFT pins (set once at power-up)
set_false_path -from [get_ports {dft_test_mode_i dft_cg_enable_i mode_select_i boot_l2_i bootsel_i[*]}]

# Temporary pre-PnR waiver for the unbuffered global HyperBus reset net.
# This net fans out to ~45k loads and will be buffered during PnR.
#set_ideal_network [get_nets hyper_reset_no]
set_false_path -through [get_nets hyper_reset_no]

# Cluster interface: async FIFO pointers/data (gray-coded, synchronized in the CDC FIFOs).
# Split by direction: async_* contains both inputs and outputs.
set_false_path -from [get_ports async_*_i]
set_false_path -to   [get_ports async_*_o]



# -----------------------------------------------------------------------------
# 4. I/O delays
# -----------------------------------------------------------------------------
# Ports that are clocks, async or already constrained above.
set SKIP_PORTS {
    ref_clk_i jtag_* cam_clk_i i2s_slave_sck_i slow_clk_i test_clk_i
    rstn_glob_i dft_* mode_select_i boot_l2_i bootsel_i* async_*
    cluster_clk_o cluster_rtc_o
    spi_clk_o sdio_clk_o hyper_ck_o hyper_ck_no i2s_slave_sck_o cam_data_i* cam_hsync_i cam_vsync_i
    i2s_slave_sd0_i i2s_slave_sd1_i i2s_slave_ws_i
}

proc ports_without {ports patterns} {
    set out {}
    foreach p $ports {
        set name [get_full_name $p]
        set skip 0
        foreach pat $patterns {
            if {[string match $pat $name]} {
                set skip 1
                break
            }
        }
        if {!$skip} {
            lappend out $p
        }
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

# Camera interface: data launched by the external camera on cam_clk
set_input_delay [expr 0.2 * $CAM_PER] -clock cam_clk \
    [get_ports {cam_data_i[*] cam_hsync_i cam_vsync_i}]

# I2S slave interface: data/word-select launched by the external master on sck
set_input_delay [expr 0.2 * $I2S_PER] -clock i2s_sck \
    [get_ports {i2s_slave_sd0_i i2s_slave_sd1_i i2s_slave_ws_i}]
# -----------------------------------------------------------------------------
# 5. Port environment
# -----------------------------------------------------------------------------
# Do not model clock inputs with a data-cell driver; their transition is set
# by set_clock_transition above.
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y [all_inputs -no_clocks]
set_load 0.05 [all_outputs]

# -----------------------------------------------------------------------------
# 6. Derating (same as riscv_core)
# -----------------------------------------------------------------------------
set_timing_derate -early 0.95
set_timing_derate -late  1.05
