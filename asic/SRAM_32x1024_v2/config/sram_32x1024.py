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

check_lvsdrc = True
output_name = "sram_32x1024"
output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "macro", output_name)
