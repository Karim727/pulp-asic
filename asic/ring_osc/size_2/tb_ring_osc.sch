v {xschem version=3.4.4 file_version=1.2 }
G {}
K {}
V {}
S {}
E {}
B 2 660 -420 1240 -80 {flags=graph,unlocked
y1=-0.2
y2=2.0
ypos1=0
ypos2=2
divy=5
subdivy=1
unity=1
x1=0
x2=2e-09
divx=5
subdivx=1
unitx=1
logx=0
logy=0
hilight_wave=-1
color="4 7 8"
node="x1._0_/a
osc_out
vccd1"
digital=0
dataset=0}
T {Ring Oscillator Testbench (size_2)} 60 -420 0 0 0.45 0.45 {layer=4}
N 160 -220 160 -180 {lab=vccd1}
N 160 -220 300 -220 {lab=vccd1}
N 240 -180 300 -180 {lab=0}
N 240 -180 240 -120 {lab=0}
N 500 -200 580 -200 {lab=osc_out}
C {ring_osc.sym} 400 -200 0 0 {name=x1}
C {devices/vsource.sym} 160 -150 0 0 {name=V1 value="PULSE(0 1.8 0 100p 100p 100n 200n)" savecurrent=false}
C {devices/gnd.sym} 160 -120 0 0 {name=l1 lab=0}
C {devices/gnd.sym} 240 -120 0 0 {name=l2 lab=0}
C {devices/capa.sym} 540 -170 0 0 {name=C1 m=1 value=10f}
C {devices/gnd.sym} 540 -140 0 0 {name=l3 lab=0}
C {devices/lab_pin.sym} 580 -200 0 1 {name=p1 sig_type=std_logic lab=osc_out}
C {devices/lab_pin.sym} 230 -220 0 0 {name=p2 sig_type=std_logic lab=vccd1}
C {devices/code.sym} 60 -100 0 0 {name=TT_MODELS
only_toplevel=true
format="tcleval( @value )"
value="
.lib $::SKYWATER_MODELS/sky130.lib.spice tt
"
spice_ignore=false}
C {devices/code_shown.sym} 60 -30 0 0 {name=SIM
only_toplevel=true
value="
.include /home/karim/pulp-asic/asic/ring_osc/size_2/ring_osc.spice
.control
save all
tran 5p 10n uic
remzerovec
write tb_ring_osc.raw
plot v(\\"x1._0_/a\\") v(osc_out)
.endc
"}
C {devices/launcher.sym} 660 -450 0 0 {name=h1
descr="Ctrl-Click to load tb_ring_osc.raw into graph"
tclcommand="xschem raw_read $netlist_dir/tb_ring_osc.raw tran"
}
