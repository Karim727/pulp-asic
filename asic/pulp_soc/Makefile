PACKAGE = pulp_soc

# extra include dir (pulp_soc_defines.sv, periph_bus_defines.sv, soc_mem_map.svh)
EXTRA_INCDIR = $(abspath ../../rtl/includes)

# Directory holding my modified/new RTL (overrides files in .bender checkouts)
OVERRIDE_DIR = $(abspath rtl)

.DEFAULT_GOAL := flist

flist:
	$(MAKE) -f ../Makefile flist PACKAGE=$(PACKAGE)
	grep -q "$(EXTRA_INCDIR)" flist.yaml || sed -i '/^VERILOG_INCLUDE_DIRS:/a\  - $(EXTRA_INCDIR)' flist.yaml
	for f in $(OVERRIDE_DIR)/*.sv; do \
	  b=$$(basename $$f); \
	  sed -i "s|^\( *- \).*/$$b\$$|\1$$f|" flist.yaml; \
	  awk -v p="$$f" '$$0 ~ "^ *- "p"$$" { if (seen++) next } { print }' flist.yaml > flist.tmp \
	    && mv flist.tmp flist.yaml; \
	done
	for f in $(OVERRIDE_DIR)/*.sv; do \
	  grep -qF -- "- $$f" flist.yaml || echo "  - $$f" >> flist.yaml; \
	done
	grep -q "jtag_tap_top.sv" flist.yaml || echo "  - $(abspath ../../rtl/pulp/jtag_tap_top.sv)" >> flist.yaml

# forward every other target to the parent Makefile
Makefile: ;
%:
	$(MAKE) -f ../Makefile $@ PACKAGE=$(PACKAGE)
