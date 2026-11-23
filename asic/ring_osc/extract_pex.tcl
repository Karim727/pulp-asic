# Magic RC PEX extraction script for Sky130A LibreLane GDS output.
# Usage (via run_pex.sh or inside LibreLane/nix shell):
#   GDS_FILE=runs/<run_tag>/final/gds/ring_osc.gds OUT_SPICE=ring_osc_pex.spice \
#     magic -dnull -noconsole -rcfile "$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc" extract_pex.tcl

set design_name "ring_osc"
if {[info exists ::env(DESIGN_NAME)] && $::env(DESIGN_NAME) ne ""} {
    set design_name $::env(DESIGN_NAME)
}

set gds_file ""
if {[info exists ::env(GDS_FILE)] && $::env(GDS_FILE) ne ""} {
    set gds_file $::env(GDS_FILE)
} else {
    set candidates [lsort [glob -nocomplain "runs/*/final/gds/${design_name}.gds"]]
    if {[llength $candidates] > 0} {
        set gds_file [lindex $candidates end]
    }
}

set out_spice "${design_name}_pex.spice"
if {[info exists ::env(OUT_SPICE)] && $::env(OUT_SPICE) ne ""} {
    set out_spice $::env(OUT_SPICE)
}

if {$gds_file eq "" || ![file exists $gds_file]} {
    puts stderr "ERROR: GDS file not found ('$gds_file'). Set GDS_FILE=..."
    quit -noprompt 1
}

puts stdout "Reading GDS: $gds_file"
gds read $gds_file
load $design_name
flatten ${design_name}_flat
load ${design_name}_flat
cellname delete $design_name
cellname rename ${design_name}_flat $design_name
select top cell

# Full RC parasitic extraction (ngspice() scale matches sky130.lib.spice .option scale=1.0u)
extract do local
extract all
ext2sim labels on
ext2sim
extresist tolerance 10
extresist

ext2spice lvs
ext2spice cthresh 0.01
ext2spice extresist on
ext2spice scale off
ext2spice -o $out_spice

puts stdout "PEX extraction complete -> $out_spice"
quit -noprompt
