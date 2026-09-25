current_design riscv_core

# -----------------------------------------------------------------------------
# 1. Clock Definition
# -----------------------------------------------------------------------------
set clock_period $::env(CLOCK_PERIOD)
create_clock -name clk_i -period $clock_period [get_ports clk_i]
set_clock_uncertainty 0.25 [get_clocks clk_i]
set_clock_transition 0.15 [get_clocks clk_i]
set_propagated_clock [all_clocks]

# -----------------------------------------------------------------------------
# 2. Design Rules & Derating
# -----------------------------------------------------------------------------
set_timing_derate -early 0.95
set_timing_derate -late  1.05
set_max_fanout 10 [current_design]
set_max_transition 0.75 [current_design]
set_max_capacitance 0.20 [current_design]

# -----------------------------------------------------------------------------
# 3. False Paths (Asynchronous Reset & Quasi-Static Cluster Config)
# -----------------------------------------------------------------------------
# Asynchronous active-low reset
set_false_path -from [get_ports rst_ni]

# Quasi-static configuration signals tied off or rarely switched in cluster
set_false_path -from [get_ports {boot_addr_i* core_id_i* cluster_id_i* fetch_enable_i clock_en_i test_en_i fregfile_disable_i ext_perf_counters_i*}]

# Status outputs to cluster controller
set_false_path -to [get_ports {core_busy_o sec_lvl_o}]

# -----------------------------------------------------------------------------
# 4. Bus & Functional Interface Delays (10-15% on-chip macro budget)
# -----------------------------------------------------------------------------
set in_delay_early   [expr $clock_period * 0.10]
set in_delay_bus     [expr $clock_period * 0.15]
set out_delay_bus    [expr $clock_period * 0.15]

# Functional Inputs (Instruction/Data OBI, APU, IRQ, Debug)
set func_inputs [get_ports {instr_gnt_i instr_rvalid_i instr_rdata_i* data_gnt_i data_rvalid_i data_rdata_i* apu_master_gnt_i apu_master_valid_i apu_master_result_i* apu_master_flags_i* irq_i irq_id_i* irq_sec_i debug_req_i}]
set_input_delay $in_delay_bus -clock [get_clocks clk_i] $func_inputs
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y $func_inputs

# Functional Outputs (Instruction/Data OBI, APU, IRQ)
set func_outputs [get_ports {instr_req_o instr_addr_o* data_req_o data_we_o data_be_o* data_addr_o* data_wdata_o* apu_master_req_o apu_master_ready_o apu_master_operands_o* apu_master_op_o* apu_master_type_o* apu_master_flags_o* irq_ack_o irq_id_o*}]
set_output_delay $out_delay_bus -clock [get_clocks clk_i] $func_outputs
set_load -pin_load 0.015 $func_outputs