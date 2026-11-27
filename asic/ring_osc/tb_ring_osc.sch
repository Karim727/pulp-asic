v {xschem version=3.4.4 file_version=1.2
}
G {}
K {}
V {}
S {}
E {}
B 2 660 -420 1240 -80 {flags=graph,unlocked
y1=-2.01764
y2=3.7943
ypos1=0
ypos2=2
divy=5
subdivy=1
unity=1
x1=-3.82393e-08
x2=1.55307e-07
divx=5
subdivx=1
unitx=1
logx=0
logy=0
hilight_wave=0
color="4 7 9"
node="osc_out
x1.u_nand_en.y
rst_ni"
digital=0
dataset=0}
T {Ring Oscillator (div16_v1) Testbench} 60 -420 0 0 0.45 0.45 {layer=4}
N 120 -240 300 -240 {lab=en_i}
N 120 -200 300 -200 {lab=rst_ni}
N 120 -160 300 -160 {lab=vccd1}
N 240 -140 300 -140 {lab=0}
N 240 -140 240 -100 {lab=0}
N 120 -100 240 -100 {lab=0}
N 500 -200 580 -200 {lab=osc_out}
N 40 -200 120 -200 {lab=rst_ni}
N 40 -300 120 -300 {lab=en_i}
N 120 -300 120 -240 {lab=en_i}
C {ring_osc.sym} 400 -200 0 0 {name=X1}
C {devices/vsource.sym} 120 -130 0 0 {name=V_VDD value="PULSE(0 1.8 0 100p 100p 1u 2u)" savecurrent=false}
C {devices/vsource.sym} 40 -170 0 0 {name=V_RST value="PULSE(0 1.8 2n 100p 100p 1u 2u)" savecurrent=false}
C {devices/vsource.sym} 40 -270 0 0 {name=V_EN value="1.8" savecurrent=false}
C {devices/gnd.sym} 240 -100 0 0 {name=l1 lab=0}
C {devices/gnd.sym} 40 -140 0 0 {name=l2 lab=0}
C {devices/gnd.sym} 40 -240 0 0 {name=l3 lab=0}
C {devices/capa.sym} 540 -170 0 0 {name=C1 m=1 value=10f}
C {devices/gnd.sym} 540 -140 0 0 {name=l4 lab=0}
C {devices/lab_pin.sym} 580 -200 0 1 {name=p1 sig_type=std_logic lab=osc_out}
C {devices/lab_pin.sym} 200 -200 0 0 {name=p2 sig_type=std_logic lab=rst_ni}
C {devices/lab_pin.sym} 200 -240 0 0 {name=p3 sig_type=std_logic lab=en_i}
C {devices/lab_pin.sym} 200 -160 0 0 {name=p4 sig_type=std_logic lab=vccd1}
C {devices/code.sym} 60 -60 0 0 {name=TT_MODELS
only_toplevel=true
format="tcleval( @value )"
value="
.lib $::SKYWATER_MODELS/sky130.lib.spice tt
"
spice_ignore=false}
C {devices/code_shown.sym} 60 20 0 0 {name=SIM
only_toplevel=true
value="
.include /home/karim/pulp-asic/asic/ring_osc/runs/PEX/final/spice_rcx/ring_osc.rcx.spice
.control
set noaskquit
save all
tran 20p 250n uic
remzerovec
write tb_ring_osc.raw
plot v(osc_out) v(\\"x1.u_nand_en.y\\") v(rst_ni)
.endc
"}
C {devices/launcher.sym} 660 -450 0 0 {name=h1
descr="Ctrl-Click to load tb_ring_osc.raw into graph"
tclcommand="xschem raw_read [file dirname [xschem get schname 0]]/simulation/tb_ring_osc.raw tran"
}
