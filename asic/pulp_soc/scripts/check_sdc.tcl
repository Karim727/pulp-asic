# check_sdc.tcl - read-only check of how OpenSTA interprets pulp_soc.sdc
#
#   cd ~/pulp_project/pulp-asic/asic/pulp_soc
#   sta -no_init -exit scripts/check_sdc.tcl | tee scripts/check_sdc.log
#
# 1. loads the sta_00 netlist + libs + pulp_soc.sdc (TT corner)
# 2. dumps the constraints as STA understood them -> scripts/pulp_soc_as_read.sdc
# 3. tests whether the hyper_reset_no false path is applied, and how the
#    worst-slack metrics / -unconstrained reports treat it

set HERE [file normalize [file dirname [info script]]/..]
set R    $HERE/runs/sta_00
set A    [file normalize $HERE/..]
set LIB  $::env(HOME)/.ciel/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
set ::env(CLOCK_PERIOD) 50.0

read_liberty $LIB
read_liberty $A/SRAM_32x1024/macro/sram_32x1024/sram_32x1024_TT_1p8V_25C.lib
read_liberty $A/ROM/rom_2048x32_TT_1p8V_25C.lib
read_verilog $R/06-yosys-synthesis/pulp_soc.nl.v
link_design pulp_soc
read_sdc $HERE/pulp_soc.sdc

puts "\n==== 1. constraints as read -> scripts/pulp_soc_as_read.sdc"
write_sdc $HERE/scripts/pulp_soc_as_read.sdc

set net [get_nets hyper_reset_no]
set drv [get_pins -of_objects $net -filter {direction == output}]
puts "\n==== 2. hyper_reset_no: net [get_full_name $net], driver [get_full_name $drv], loads [llength [get_pins -of_objects $net]]"
puts "     top-level port with the same name: [llength [get_ports -quiet hyper_reset_no]]"

puts "\n==== 3. worst recovery paths through hyper_reset_no (as read)"
report_checks -path_group asynchronous -through $net -format end

puts "\n==== 4. worst slack / TNS as LibreLane metrics see them (setup)"
report_worst_slack -max
report_tns
puts "\n==== 5. same recovery paths with -unconstrained (how checks.rpt reports)"
report_checks -path_group asynchronous -through $net -unconstrained -format end


report_checks -through [get_pins _197606_/Y] -fields {slew cap fanout input_pins} -digits 3
report_net -digits 3 [get_nets -of_objects [get_pins _197606_/A]]
report_net -digits 3 [get_nets -of_objects [get_pins _197606_/B]]
