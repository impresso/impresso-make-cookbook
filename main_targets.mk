$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/main_targets.mk)
###############################################################################
# MAIN PROCESSING TARGETS
# Core targets for newspaper processing pipeline
###############################################################################
  
  $(call log.info,MAKEFLAGS)

#: Show detailed orchestration and parallelization help
help-orchestration:
	@echo "PARALLELIZATION CONFIGURATION:"
	@echo "  COLLECTION_JOBS   #  Number of different newspapers to process in parallel ($(COLLECTION_JOBS))"
	@echo "                    #  Low numbers might not use all system resources effectively if newspapers are small and many CPU cores are available"
	@echo ""
	@echo "  NEWSPAPER_JOBS    #  Number of parallel jobs per newspaper ($(NEWSPAPER_JOBS))"
	@echo "                    #  If COLLECTION_JOBS > NPROC, NEWSPAPER_JOBS may be zero; adjust accordingly"
	@echo "                    #  Controls fine-grained parallelism within each newspaper"
	@echo "                    #  Auto-calculated to balance with COLLECTION_JOBS"
	@echo ""
	@echo "  MAX_LOAD          #  Maximum system load average ($(MAX_LOAD))"
	@echo "                    #  Prevents system overload by limiting concurrent processes"
	@echo "                    #  Set lower if system becomes unresponsive"
	@echo ""
	@echo "  NPROC             #  Number of CPU cores ($(NPROC))"
	@echo "                    #  Override if auto-detection fails or for resource limiting"
	@echo ""
	@echo "PERFORMANCE TUNING:"
	@echo "  • For CPU-bound tasks: COLLECTION_JOBS ≤ NPROC"
	@echo "  • For I/O-bound tasks: COLLECTION_JOBS can exceed NPROC"
	@echo "  • High memory usage: Reduce COLLECTION_JOBS"
	@echo "  • System lag: Reduce MAX_LOAD to 70-80% of NPROC"
	@echo ""
	@echo "EXAMPLES:"
	@echo "  make newspaper PROVIDER=BL NEWSPAPER=WTCH"
	@echo "  make collection COLLECTION_JOBS=4 CFG=config.prod.mk"
	@echo "  make all PROVIDER=BL NEWSPAPER=WTCH MAX_LOAD=8"
	@echo "  make sync-input PROVIDER=SWA NEWSPAPER=actionfem"
	@echo ""
	@echo "MONITORING:"
	@echo "  tail -f build.d/collection.joblog          # Monitor collection progress"
	@echo "  htop -u $${USER}                           # Monitor system resources"
	@echo ""

.PHONY: help-orchestration
# If set to 1, GNU parallel stops on the first error
HALT_ON_ERROR ?= 0

# Internal option passed to GNU parallel
ifeq ($(HALT_ON_ERROR),1)
PARALLEL_HALT := --halt now,fail=1
else
PARALLEL_HALT :=
endif


# TARGET: newspaper
#: Process a single newspaper run by the processing pipeline
# Dependencies: 
# - sync: Ensures data is synchronized
# - processing-target: Performs the actual processing
newspaper: | $(BUILD_DIR)
	# MAKEFLAGS= $(MAKEFLAGS) 
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) sync
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) processing-target

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
NPROC := $(shell nproc --all)
else
# Fallback for other systems
NPROC := 1
  $(call log.warn, "NPROC not set, defaulting to 1. Please set NPROC for better performance.")
endif
endif
  $(call log.info, NPROC)

COLLECTION_JOBS ?= 2
  $(call log.info, COLLECTION_JOBS)

NEWSPAPER_JOBS ?= $(shell expr $(NPROC) / $(COLLECTION_JOBS))
  $(call log.info, NEWSPAPER_JOBS	)

MAX_LOAD ?= $(NPROC)
  $(call log.info, MAX_LOAD)

PARALLEL_DELAY ?= 3
  $(call log.debug, PARALLEL_DELAY)

# TARGET: all
# Complete processing with fresh data sync
# Steps:
# 1. Resync data (serial)
# 2. Process data (parallel)
# Note: The two Make invocations are separate to ensure sync completes before processing starts
all:
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) -j 1 sync-input resync-output
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) -j $(NEWSPAPER_JOBS) --max-load $(MAX_LOAD) processing-target

.PHONY: all


# TARGET: collection
#: Process multiple newspapers with specified parallel processing
# Uses xargs for parallel execution with COLLECTION_JOBS limit
collection-xargs: newspaper-list-target
	tr " " "\n" < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	xargs -n 1 -P $(COLLECTION_JOBS) -I {} \
		NEWSPAPER={} $(MAKE) -f $(firstword $(MAKEFILE_LIST)) -k --max-load $(MAX_LOAD) all 


check-parallel:
	@parallel --version | grep -q 'GNU parallel' || \
	( echo "ERROR: GNU parallel not installed or a wrong variant"; exit 1 )
.PHONY: check-parallel

# TARGET: collection
#: Process full impresso collection with specified parallel processing
# Uses GNU parallel for better control over job execution
# Note: Requires GNU parallel installed
# Dependencies: newspaper-list-target
collection: check-parallel newspaper-list-target
	# tail -f $(BUILD_DIR)/collection.joblog to monitor per newspaper progress summary
	tr -s '[:space:]' '\n'  < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	parallel  --tag -v --progress --joblog $(BUILD_DIR)/collection.joblog \
	   --jobs $(COLLECTION_JOBS) \
	   --delay $(PARALLEL_DELAY) --memfree 1G --load $(MAX_LOAD) \
	   $(PARALLEL_HALT) \
		"NEWSPAPER={} $(MAKE) -f $(firstword $(MAKEFILE_LIST)) -k --max-load $(MAX_LOAD) all"

help::
	@echo "  collection        #  Process fulll impresso collection with parallel processing"


.PHONY: collection

$(call log.debug, COOKBOOK END INCLUDE: cookbook/main_targets.mk)
