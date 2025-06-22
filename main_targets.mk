$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/main_targets.mk)
###############################################################################
# MAIN PROCESSING TARGETS
# Core targets for newspaper processing pipeline
###############################################################################



# TARGET: newspaper
#: Process a single newspaper run by the processing pipeline
# Dependencies: 
# - sync: Ensures data is synchronized
# - processing-target: Performs the actual processing
newspaper: | $(BUILD_DIR)
	$(MAKE) sync
	$(MAKE) processing-target

.PHONY: newspaper

help::
	@echo "  newspaper         #  Process a single newspaper run by the processing pipeline"

# Cross-platform CPU detection
ifndef NPROC
ifeq ($(OS),Darwin)
# macOS - use sysctl
NPROC := $(shell sysctl -n hw.ncpu)
else ifeq ($(OS),Linux)
# Linux - use nproc
NPROC := $(shell nproc)
else
# Fallback for other systems
NPROC := 1
  $(call log.warn, "NPROC not set, defaulting to 1. Please set NPROC for better performance.")
endif
endif
  $(call log.info, NPROC)

PARALLEL_JOBS ?= $(NPROC)
  $(call log.info, PARALLEL_JOBS)

COLLECTION_JOBS ?= 2
  $(call log.info, COLLECTION_JOBS)

NEWSPAPER_JOBS ?= $(shell expr $(PARALLEL_JOBS) / $(COLLECTION_JOBS))
  $(call log.info, NEWSPAPER_JOBS	)

MAX_LOAD ?= $(PARALLEL_JOBS)
  $(call log.info, MAX_LOAD)

# TARGET: all
# Complete processing with fresh data sync
# Steps:
# 1. Resync data (serial)
# 2. Process data (parallel)
all:
	$(MAKE) -j 1 sync-input resync-output
	$(MAKE) -j $(NEWSPAPER_JOBS) --max-load $(MAX_LOAD) processing-target

.PHONY: all


# TARGET: collection
#: Process multiple newspapers with specified parallel processing
# Uses xargs for parallel execution with COLLECTION_JOBS limit
collection-xargs: newspaper-list-target
	tr " " "\n" < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	xargs -n 1 -P $(COLLECTION_JOBS) -I {} \
		NEWSPAPER={} $(MAKE) -k --max-load $(MAX_LOAD) all 


check-parallel:
	@parallel --version | grep -q 'GNU parallel' || \
	( echo "ERROR: GNU parallel not installed or wrong version"; exit 1 )
.PHONY: check-parallel

# TARGET: collection
#: Process multiple newspapers with specified parallel processing
# Uses GNU parallel for better control over job execution
# Note: Requires GNU parallel installed
# Dependencies: newspaper-list-target
collection: check-parallel newspaper-list-target
	tr " " "\n" < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	parallel  --tag -v --progress  \
	   --jobs $(COLLECTION_JOBS) \
	   --delay 3 --memfree 1G --load $(MAX_LOAD) \
		"NEWSPAPER={} $(MAKE) -k --max-load $(MAX_LOAD) all"

help::
	@echo "  collection        #  Process multiple newspapers with specified parallel processing"

# Alternative implementation using GNU parallel
# collection: newspaper-list-target
#	cat $(NEWSPAPERS_TO_PROCESS_FILE) | \
#	parallel -j $(COLLECTION_JOBS) \
#		"$(MAKE) NEWSPAPER={} all"

.PHONY: collection

$(call log.debug, COOKBOOK END INCLUDE: cookbook/main_targets.mk)
