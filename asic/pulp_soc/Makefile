PACKAGE = pulp_soc

# extra include dir (pulp_soc_defines.sv, periph_bus_defines.sv, soc_mem_map.svh)
EXTRA_INCDIR = $(abspath ../../rtl/includes)

.DEFAULT_GOAL := flist

# run the original flist target, then append the extra include dir
flist:
	$(MAKE) -f ../Makefile flist PACKAGE=$(PACKAGE)
	grep -q "$(EXTRA_INCDIR)" flist.yaml || sed -i '/^VERILOG_INCLUDE_DIRS:/a\  - $(EXTRA_INCDIR)' flist.yaml
	grep -q "lint_stubs.sv" flist.yaml || echo "  - $(abspath lint_stubs.sv)" >> flist.yaml
	grep -q "jtag_tap_top.sv" flist.yaml || echo "  - $(abspath ../../rtl/pulp/jtag_tap_top.sv)" >> flist.yaml
	sed -i 's|^\( *- \).*/udma_subsystem/udma_subsystem\.sv$$|\1$(abspath rtl/udma_subsystem.sv)|' flist.yaml

# forward every other target to the parent Makefile
Makefile: ;
%:
	$(MAKE) -f ../Makefile $@ PACKAGE=$(PACKAGE)
	
	
	
