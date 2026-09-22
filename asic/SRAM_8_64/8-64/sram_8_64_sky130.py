# my_sram.py -- OpenRAM SRAM Configuration

# ---- Memory dimensions ------------------------------------------------------

word_size = 8
num_words = 64
human_byte_size = "{:.0f}kbytes".format((word_size * num_words) / 1024 / 8)

num_banks = 1
words_per_row = 1
write_size = 2

ports_human = '1rw'

# No spare cells
num_spare_cols = 0
num_spare_rows = 0


# ---- Technology ------------------------------------------------------------

#tech_name = "sky130"

import os
exec(open(os.path.join(
    os.path.dirname(__file__),
    'sky130_sram_common.py'
)).read())


# ---- Output ----------------------------------------------------------------

output_name = "sram_{}_{}_{}".format(word_size, num_words, tech_name)
output_path = "output_files"


# ---- Port configuration ----------------------------------------------------

num_rw_ports = 1
num_r_ports = 0
num_w_ports = 0


# ---- Process corners and supply voltage ------------------------------------

# Use only nominal corner for faster generation
process_corners = ["TT"]
supply_voltages = [1.8]


# ---- Simulation / characterization ----------------------------------------

# Use analytical timing to avoid long SPICE characterization
analytical_delay = True

check_lvsdrc = False

# Do not hard-code /usr/bin/ngspice.
# The Nix environment provides ngspice.


# ---- Load / slew -----------------------------------------------------------

use_specified_load_slew = [
    (0.001, 0.01),
    (0.01, 0.05),
    (0.05, 0.1)
]


