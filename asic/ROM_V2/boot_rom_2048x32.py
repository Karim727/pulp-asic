# OpenRAM ROM configuration - PULP boot ROM
#
#    2048 words x 32 bits (8 kbytes) - matches generic_rom blackbox:
#        ADDR_WIDTH = 11  (2^11 = 2048 words), DATA_WIDTH = 32
#    ROM contents packed from ~/pulp-asic/sim/boot/boot_code.cde
#    (2048 lines x 32 binary digits, MSB first) into boot_rom_data.bin
#
# Run from the OpenRAM root directory:
#     python3 rom_compiler.py macros/rom_configs/boot_rom_2048x32.py
#
# Outputs land in macros/rom_configs/boot_rom_2048x32/ as
#     boot_rom_2048x32.{sp,v,lef,gds}
# (note: like the ROM compiler examples, no .lib is generated)

import os

_this_dir = os.path.dirname(os.path.abspath(__file__))

# ---- Memory organization -----------------------------------------------------
# NOTE: word_size is in BYTES for the ROM compiler (word_bits = word_size * 8)
word_size = 4                # 4 bytes = 32-bit words
words_per_row = 8            # 8 words/row -> 256 rows x 256 cols
                             # addr width = log2(256 rows) + log2(8 mux) = 11 bits
                             # -> addr0[10:0], same as the generic_rom stub

scramble_bits = True         # default; internal bit scrambling for a cleaner layout

# ---- Data --------------------------------------------------------------------
rom_data = os.path.join(_this_dir, "boot_rom_data.bin")
data_type = "bin"            # raw binary file; each byte is read MSB first

# ---- Outputs -----------------------------------------------------------------
output_name = "boot_rom_2048x32"
output_path = os.path.join(_this_dir, output_name) + os.sep

# ---- Reuse this OpenRAM's sky130 build (same technology dir as your SRAMs) ----
exec(open(os.path.join(_this_dir, 'sky130_rom_common.py')).read())

check_lvsdrc = True
