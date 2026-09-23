# ==============================================================================
# Bender Module & Filelist Automation Makefile
# ==============================================================================
PACKAGE      ?= cv32e40p
BENDER       ?= ../../bender
OUT_DIR      ?= .
TARGETS      ?= synthesis rtl verilator

# Packages to generate filelists for.
PACKAGES     ?= $(shell $(BENDER) packages 2>/dev/null)

.PHONY: all help list-modules clean flist

all: flist

help:
	@echo "Bender Filelist Generator"
	@echo ""
	@echo "Usage:"
	@echo "  make <package_name>.yaml   Generate structured YAML filelist for any package"
	@echo "  make flist                 Generate structured YAML for default PACKAGE ($(PACKAGE)) -> flist.yaml"
	@echo "  make list-modules          Show all available packages/dependencies"
	@echo "  make clean                 Remove generated YAML files"

list-modules:
	@echo "=== Root Package & Direct Dependencies (from Bender.yml) ==="
	@$(BENDER) packages
	@echo ""

$(OUT_DIR):
	@mkdir -p $(OUT_DIR)

# Target-flag argument string builder (no -n so full dependency tree is included)
BENDER_TARGET_ARGS = $(foreach t,$(TARGETS),-t $(t))

# Default target creates flist.yaml using $(PACKAGE)
flist: $(OUT_DIR)
	@echo "Generating structured YAML filelist for package: $(PACKAGE) -> $(OUT_DIR)/flist.yaml"
	@$(BENDER) script flist-plus $(BENDER_TARGET_ARGS) -p $(PACKAGE) | awk ' \
	  /^\+incdir\+/ { sub(/^\+incdir\+/, ""); incs[inc_count++] = $$0; next } \
	  /^\+/         { next } \
	  NF            { v_files[v_count++] = $$0 } \
	  END { \
	    print "VERILOG_INCLUDE_DIRS:"; \
	    if (inc_count == 0) print "  []"; \
	    else for (i = 0; i < inc_count; i++) print "  - " incs[i]; \
	    print "\nVERILOG_FILES:"; \
	    for (i = 0; i < v_count; i++) print "  - " v_files[i]; \
	  }' > $(OUT_DIR)/flist.yaml

# Pattern rule for generating a package-specific YAML filelist on demand:
# e.g.: make cv32e40p.yaml
%.yaml: $(OUT_DIR)
	@echo "Generating structured YAML filelist for package: $* -> $@"
	@$(BENDER) script flist-plus $(BENDER_TARGET_ARGS) -p $* | awk ' \
	  /^\+incdir\+/ { sub(/^\+incdir\+/, ""); incs[inc_count++] = $$0; next } \
	  /^\+/         { next } \
	  NF            { v_files[v_count++] = $$0 } \
	  END { \
	    print "VERILOG_INCLUDE_DIRS:"; \
	    if (inc_count == 0) print "  []"; \
	    else for (i = 0; i < inc_count; i++) print "  - " incs[i]; \
	    print "\nVERILOG_FILES:"; \
	    for (i = 0; i < v_count; i++) print "  - " v_files[i]; \
	  }' > $@

clean:
	@rm -f flist.yaml
	@echo "Cleaned generated YAML filelists in '$(OUT_DIR)'."