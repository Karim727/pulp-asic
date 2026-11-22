# probe_clocks.tcl - read-only STA probe on the sta_00 netlist (OpenSTA)
#
#   cd ~/pulp_project/pulp-asic/asic/pulp_soc
#   sta -no_init -exit scripts/probe_clocks.tcl | tee scripts/probe_clocks.log
#
# Finds the HyperBus clock-generator nets (clk0 / clk90) and the cells that
# drive them, for create_generated_clock in pulp_soc.sdc.

set HERE [file normalize [file dirname [info script]]/..]
set R    $HERE/runs/sta_00
set A    [file normalize $HERE/..]
set LIB  $::env(HOME)/.ciel/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

read_liberty $LIB
read_liberty $A/SRAM_32x1024/macro/sram_32x1024/sram_32x1024_TT_1p8V_25C.lib
read_liberty $A/ROM/rom_2048x32_TT_1p8V_25C.lib
read_verilog $R/06-yosys-synthesis/pulp_soc.nl.v
link_design pulp_soc

proc show_nets {pattern {max 30}} {
  set nets [get_nets -quiet $pattern]
  puts "---- pattern '$pattern' : [llength $nets] nets"
  set i 0
  foreach n $nets {
    if {[incr i] > $max} { puts "   ... (more)"; break }
    set drv [get_pins -quiet -of_objects $n -filter {direction == output}]
    set d [expr {[llength $drv] ? [get_full_name $drv] : "(port/none)"}]
    puts "   [get_full_name $n]  <-  $d"
  }
}

puts "==== HyperBus clock nets ===="
show_nets *clk_gen*
show_nets *hyper*clk0*
show_nets *hyper*clk90*
show_nets *r_clk0*
show_nets *r_clk90*
