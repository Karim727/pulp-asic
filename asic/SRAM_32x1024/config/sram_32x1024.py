# sram_32x1024: 1024 words x 32 bit (4 KB), 1 RW port, byte write.
# Used for the pulp_soc L2 (16 instances) and the cluster TCDM.
# Same settings as the previous macro (asic/SRAM_32x1024), but built with the
# pinned OpenRAM dev commit (OPENRAM_COMMIT) and with DRC/LVS ON.
word_size = 32
num_words = 1024
human_byte_size = "{:.1f}kbytes".format((word_size * num_words)/1024/8)

write_size = 8

num_rw_ports = 1
num_r_ports = 0
num_w_ports = 0
ports_human = '1rw'

num_spare_cols = 1
num_spare_rows = 1

import os
exec(open(os.path.join(os.path.dirname(__file__), 'sky130_sram_common.py')).read())

# OpenRAM's own DRC/LVS. OPENRAM_CHECK=0 skips them (views only): the LVS of
# the full 32x1024 needs > 11 GB RAM in netgen; we run it with scripts/lvs_check.sh.
check_lvsdrc = os.environ.get("OPENRAM_CHECK", "1") != "0"

# Timing corners: one .lib per corner, same PVT as the LibreLane STA corners
# of sky130_fd_sc_hd (tt_025C_1v80, ss_100C_1v60, ff_n40C_1v95).
# This replaces nominal_corner_only (TT 1.8V 25C only) from sky130_sram_common.py.
nominal_corner_only = False
use_specified_corners = [("TT", 1.80,  25),
                         ("SS", 1.60, 100),
                         ("FF", 1.95, -40)]
# The PVT lists must be given too: with nominal_corner_only = False, OpenRAM dev
# otherwise reads tech.spice["fet_models"], which sky130 does not define
# (KeyError: 'fet_models'). TT / 1.80 / 25 first = nominal.
process_corners = ["TT", "SS", "FF"]
supply_voltages = [1.80, 1.60, 1.95]
temperatures    = [25, 100, -40]
# The .lib numbers come from OpenRAM's analytical delay model (fast).
# For SPICE-characterized libs set this to False (ngspice, hours per corner).
analytical_delay = True
output_name = "sram_32x1024"
output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "macro", output_name)
