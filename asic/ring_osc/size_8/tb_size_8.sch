v {xschem version=3.4.4 file_version=1.2
}
G {}
K {}
V {}
S {}
E {}
N -50 20 -50 40 {
lab=0}
N -160 40 -50 40 {
lab=0}
N -160 -30 -160 -20 {
lab=vccd1}
N -50 -30 -50 -20 {
lab=vccd1}
N -160 -30 -50 -30 {
lab=vccd1}
N -30 10 -15 10 {
lab=osc_out}
N -15 10 -15 110 {
lab=osc_out}
C {ring_osc.sym} 40 20 0 0 {name=X1}
C {vsource.sym} -160 10 0 0 {name=V1 value="PULSE(0 1.8 0 100p 100p 100n 200n)" savecurrent=false}
C {gnd.sym} -50 40 0 0 {name=l1 lab=0}
C {code_shown.sym} 5 -20 0 0 {name=SPICE_INCLUDE
only_toplevel=true
value="
.include /home/karim/pulp-asic/asic/ring_osc/size_8/ring_osc.spice
"

}
C {code_shown.sym} 10 60 0 0 {name=SKY130_MODELS
only_toplevel=true
format="tcleval( @value )"
value="
.lib $::SKYWATER_MODELS/sky130.lib.spice tt
"}
C {code_shown.sym} 5 130 0 0 {name=TRAN_SIM
only_toplevel=true
value="
.control
set noaskquit
save all
tran 1p 20n 0 1p uic
remzerovec
write tb_size_8.raw
plot v(\\"x1._0_/a\\") v(osc_out)
.endc
"}
C {lab_pin.sym} -15 110 0 0 {name=out sig_type=std_logic lab=osc_out}
