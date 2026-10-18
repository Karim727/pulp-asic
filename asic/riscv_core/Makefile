include ../Makefile

CLUSTER_DIR := $(abspath $(CURDIR)/../../.bender/git/checkouts/pulp_cluster-48721e3ce381c984)
PULP_RTL_INCLUDES := $(abspath $(CURDIR)/../../rtl/includes)
CORE_REGION_SV := $(abspath $(CURDIR)/../rtl/core_region.sv)
CORE_REGION_WRAP_SV := $(abspath $(CURDIR)/../rtl/core_region_wrap.sv)
TC_CLK_SV := $(abspath $(CURDIR)/../rtl/tc_clk.sv)

flist: $(OUT_DIR)
	@echo "Generating structured YAML filelist for core_region_wrap -> $(OUT_DIR)/flist.yaml"
	@$(BENDER) script flist-plus $(BENDER_TARGET_ARGS) -p cv32e40p -p ibex -p hci -p pulp_soc | awk -v tc_clk="$(TC_CLK_SV)" ' \
	  /^\+incdir\+/ { \
	    sub(/^\+incdir\+/, ""); \
	    if (!seen_inc[$$0]++) incs[inc_count++] = $$0; \
	    next \
	  } \
	  /^\+/         { next } \
	  NF            { \
	    file = $$0; \
	    if (file ~ /\/tc_clk\.sv$$/) file = tc_clk; \
	    if (!seen_v[file]++) v_files[v_count++] = file; \
	  } \
	  END { \
	    print "VERILOG_INCLUDE_DIRS:"; \
	    if (inc_count == 0 && seen_inc["$(PULP_RTL_INCLUDES)"] == 0) print "  []"; \
	    for (i = 0; i < inc_count; i++) print "  - " incs[i]; \
	    if (!seen_inc["$(PULP_RTL_INCLUDES)"]++) print "  - $(PULP_RTL_INCLUDES)"; \
	    print "\nVERILOG_FILES:"; \
	    for (i = 0; i < v_count; i++) print "  - " v_files[i]; \
	    extra[0] = "$(CLUSTER_DIR)/rtl/cluster_clock_gate.sv"; \
	    extra[1] = "$(CLUSTER_DIR)/rtl/core_demux.sv"; \
	    extra[2] = "$(CLUSTER_DIR)/rtl/periph_demux.sv"; \
	    extra[3] = "$(CLUSTER_DIR)/rtl/periph_FIFO.sv"; \
	    extra[4] = "$(CORE_REGION_SV)"; \
	    extra[5] = "$(CORE_REGION_WRAP_SV)"; \
	    for (i = 0; i < 6; i++) { \
	      if (!seen_v[extra[i]]++) print "  - " extra[i]; \
	    } \
	  }' > $(OUT_DIR)/flist.yaml
