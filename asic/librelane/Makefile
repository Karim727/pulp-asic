# ==============================================================================
# Bender Module & Filelist Automation Makefile
# ==============================================================================

BENDER       ?= ../../bender
OUT_DIR      ?= .
TARGETS      ?= simulation test

# Packages to generate filelists for.
# Defaults to all resolved packages found by bender if not specified.
PACKAGES     ?= $(shell $(BENDER) packages 2>/dev/null)


.PHONY: all help list-modules filelists clean

all: filelists

help:
	@echo "Bender Filelist Generator"
	@echo ""
	@echo "Usage:"
	@echo "  make list-modules           Show all available packages/dependencies"
	@echo "  make filelists              Generate filelists for all packages"
	@echo "  make filelists PACKAGES=\"common_cells pulp_soc pulp\""
	@echo "                              Generate filelists only for specified packages"
	@echo "  make <package_name>.flist   Generate a filelist for a single package"
	@echo "  make clean                  Remove generated filelists"
	@echo ""
	@echo "Options:"
	@echo "  TARGETS=\"<targets>\"         Bender target flags (default: \"$(TARGETS)\")"
	@echo "  OUT_DIR=\"<path>\"            Output directory (default: \"$(OUT_DIR)\")"

# ------------------------------------------------------------------------------
# Module Inspection
# ------------------------------------------------------------------------------
list-modules:
	@echo "=== Root Package & Direct Dependencies (from Bender.yml) ==="
	@$(BENDER) packages
	@echo ""

# ------------------------------------------------------------------------------
# Filelist Generation Rules
# ------------------------------------------------------------------------------
$(OUT_DIR):
	@mkdir -p $(OUT_DIR)

# Target-flag argument string builder
BENDER_TARGET_ARGS = $(foreach t,$(TARGETS),-t $(t))

# Batch rule to generate filelists for all entries in $(PACKAGES)
filelists: $(OUT_DIR)
	@if [ -z "$(strip $(PACKAGES))" ]; then \
		echo "Error: No packages found. Run 'bender update' or check your Bender.yml."; \
		exit 1; \
	fi
	@for pkg in $(PACKAGES); do \
		echo "Generating filelist for package: $$pkg -> $(OUT_DIR)/$$pkg.f"; \
		$(BENDER) script flist $(BENDER_TARGET_ARGS) -p $$pkg > $(OUT_DIR)/$$pkg.f || exit 1; \
	done
	@echo "All filelists successfully generated in '$(OUT_DIR)/'."

# Pattern rule for generating a single module filelist on demand:
# e.g.: make common_cells.flist or make pulp.flist
%.flist: $(OUT_DIR)
	@echo "Generating filelist for package: $* -> $(OUT_DIR)/$*.f"
	@$(BENDER) script flist $(BENDER_TARGET_ARGS) -p $* > $(OUT_DIR)/$*.f

# ------------------------------------------------------------------------------
# Clean
# ------------------------------------------------------------------------------
clean:
	@rm -rf $(OUT_DIR)
	@echo "Cleaned generated filelists directory '$(OUT_DIR)'."