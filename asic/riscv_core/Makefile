include ../Makefile

CLUSTER_DIR := $(abspath $(CURDIR)/../../.bender/git/checkouts/pulp_cluster-48721e3ce381c984)
PULP_RTL_INCLUDES := $(abspath $(CURDIR)/../../rtl/includes)
CORE_REGION_SV := $(abspath $(CURDIR)/../rtl/core_region.sv)

flist: $(OUT_DIR)
	@echo "Generating structured YAML filelist for core_region -> $(OUT_DIR)/flist.yaml"
	@$(BENDER) script flist-plus $(BENDER_TARGET_ARGS) -p cv32e40p | awk ' \
	  /^\+incdir\+/ { sub(/^\+incdir\+/, ""); incs[inc_count++] = $$0; next } \
	  /^\+/         { next } \
	  NF            { v_files[v_count++] = $$0 } \
	  END { \
	    print "VERILOG_INCLUDE_DIRS:"; \
	    if (inc_count == 0) print "  []"; \
	    else for (i = 0; i < inc_count; i++) print "  - " incs[i]; \
	    print "  - $(PULP_RTL_INCLUDES)"; \
	    print "\nVERILOG_FILES:"; \
	    for (i = 0; i < v_count; i++) print "  - " v_files[i]; \
	    print "  - $(CLUSTER_DIR)/rtl/core_demux.sv"; \
	    print "  - $(CLUSTER_DIR)/rtl/periph_demux.sv"; \
	    print "  - $(CLUSTER_DIR)/rtl/periph_FIFO.sv"; \
	    print "  - $(CORE_REGION_SV)"; \
	  }' > $(OUT_DIR)/flist.yaml
