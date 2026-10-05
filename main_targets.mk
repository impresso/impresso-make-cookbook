$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/main_targets.mk)
###############################################################################
# MAIN PROCESSING TARGETS
# Core targets for newspaper processing pipeline
###############################################################################
  
  $(call log.info,MAKEFLAGS)

# Cross-platform CPU detection
ifndef NPROC
ifeq ($(OS),Darwin)
# macOS - use sysctl
NPROC := $(shell sysctl -n hw.ncpu 2>/dev/null || echo 1)
else ifeq ($(OS),Linux)
# Linux - use nproc
NPROC := $(shell nproc --all 2>/dev/null || echo 1)
else
# Fallback for other systems
NPROC := 1
  $(call log.warn, "NPROC not set, defaulting to 1. Please set NPROC for better performance.")
endif
endif
  $(call log.info, NPROC)

# USER-VARIABLE: MAX_LOAD
# Maximum load average for the machine to allow processing
#
# This variable sets the maximum load average for the machine in parallelization. No new
# jobs are started if the load average exceeds this value.
MAX_LOAD ?= $(NPROC)
  $(call log.info, MAX_LOAD)

# USER-VARIABLE: COLLECTION_JOBS
# Maximum number of parallel newspaper processes
#
# This variable sets the maximum number of different newspapers to process in parallel.
# Default: Half of available CPU cores
COLLECTION_JOBS_DEFAULT := $(shell v=$$(expr $(NPROC) / 2); [ "$$v" -lt 1 ] && v=1; echo $$v)
COLLECTION_JOBS_RAW := $(value COLLECTION_JOBS)
override COLLECTION_JOBS := $(or $(strip $(COLLECTION_JOBS_RAW)),$(COLLECTION_JOBS_DEFAULT))
  $(call log.info, COLLECTION_JOBS)

# USER-VARIABLE: NEWSPAPER_JOBS
# Maximum number of parallel jobs per newspaper
#
# This variable sets the maximum number of parallel jobs to run when processing a
# single newspaper. Auto-calculated to balance with COLLECTION_JOBS.
# If COLLECTION_JOBS exceeds NPROC, this is clamped to 1 to avoid -j 0 (unlimited jobs).
NEWSPAPER_JOBS_DEFAULT := $(shell if [ "$(COLLECTION_JOBS)" -gt 0 ]; then v=$$(expr $(NPROC) / $(COLLECTION_JOBS)); [ "$$v" -lt 1 ] && v=1; echo $$v; else echo 1; fi)
NEWSPAPER_JOBS_RAW := $(value NEWSPAPER_JOBS)
override NEWSPAPER_JOBS := $(or $(strip $(NEWSPAPER_JOBS_RAW)),$(NEWSPAPER_JOBS_DEFAULT))
  $(call log.info, NEWSPAPER_JOBS)

# PARALLEL_DELAY: Delay in seconds between starting parallel jobs
PARALLEL_DELAY ?= 3
  $(call log.debug, PARALLEL_DELAY)

# USER-VARIABLE: COLLECTION_LOAD
# Maximum load average passed to GNU parallel for collection scheduling.
# Set empty to disable load-based throttling when exact concurrency is required.
COLLECTION_LOAD ?= $(MAX_LOAD)
  $(call log.debug, COLLECTION_LOAD)

# USER-VARIABLE: COLLECTION_MEMFREE
# Minimum free memory passed to GNU parallel for collection scheduling.
# Set empty to disable memory-based throttling when exact concurrency is required.
COLLECTION_MEMFREE ?= 1G
  $(call log.debug, COLLECTION_MEMFREE)

COLLECTION_LOAD_OPTION := $(if $(strip $(COLLECTION_LOAD)),--load $(COLLECTION_LOAD))
COLLECTION_MEMFREE_OPTION := $(if $(strip $(COLLECTION_MEMFREE)),--memfree $(COLLECTION_MEMFREE))

# USER-VARIABLE: NEWSPAPER_LOAD
# Maximum load average passed to child make newspaper workers.
# Set empty to disable child make load throttling when exact outer concurrency
# is required.
NEWSPAPER_LOAD ?= $(MAX_LOAD)
  $(call log.debug, NEWSPAPER_LOAD)

NEWSPAPER_LOAD_OPTION := $(if $(strip $(NEWSPAPER_LOAD)),--max-load $(NEWSPAPER_LOAD))

# Internal dry-run propagation. GNU make records short options such as -n in
# a compact option word such as "nrRw"; ignore long options like
# --warn-undefined-variables, which also contain the letter "n".
MAKEFLAGS_SHORT_OPTIONS := $(firstword $(filter-out --%,$(MAKEFLAGS)))
MAKE_DRY_RUN_OPTION := $(if $(findstring n,$(MAKEFLAGS_SHORT_OPTIONS)),-n)
PARALLEL_DRY_RUN_OPTION := $(if $(MAKE_DRY_RUN_OPTION),--dry-run)

#: Show the main orchestration targets; use help-orchestration-settings for tuning
help-orchestration::
	@echo "ORCHESTRATION TARGETS:"
	@echo "  make newspaper                   # Sync normally, then process one newspaper"
	@echo "  make collection                  # Process the newspaper list with GNU parallel; runs COLLECTION_TARGET for each item"
	@echo "  make collection-xargs            # Process the list with xargs when GNU parallel is unavailable"
	@echo "  make all                         # Force input/output resync, then process one newspaper"
	@echo "  make refresh-newspaper-list      # Replace the collection list from S3 before a collection run"
	@echo ""
	@echo "  make collection COLLECTION_JOBS=8 NEWSPAPER_JOBS=2 # Example with eight newspapers and two jobs each"
	@echo "  make help-orchestration-settings # Variable meanings, defaults, tuning, and more examples"

.PHONY: help-orchestration help-orchestration-settings

#: Explain orchestration variables and resource controls
help-orchestration-settings::
	@echo "ORCHESTRATION SETTINGS (current values in parentheses):"
	@printf '  %-32s %s\n' 'COLLECTION_TARGET ($(COLLECTION_TARGET))' 'Target run for each list item: newspaper by default; all forces input/output resync'
	@printf '  %-32s %s\n' 'COLLECTION_JOBS ($(COLLECTION_JOBS))' 'Maximum concurrent newspaper workers; defaults to half of NPROC, at least one'
	@printf '  %-32s %s\n' 'NEWSPAPER_JOBS ($(NEWSPAPER_JOBS))' 'Make jobs within each newspaper; defaults to NPROC / COLLECTION_JOBS, at least one'
	@printf '  %-32s %s\n' 'NPROC ($(NPROC))' 'Detected CPU count used to calculate job defaults; override when detection is wrong'
	@printf '  %-32s %s\n' 'MAX_LOAD ($(MAX_LOAD))' 'Default load limit for both collection and newspaper workers; defaults to NPROC'
	@printf '  %-32s %s\n' 'COLLECTION_LOAD ($(COLLECTION_LOAD))' 'GNU parallel load limit; empty disables this throttle'
	@printf '  %-32s %s\n' 'COLLECTION_MEMFREE ($(COLLECTION_MEMFREE))' 'GNU parallel minimum free memory; empty disables this throttle'
	@printf '  %-32s %s\n' 'NEWSPAPER_LOAD ($(NEWSPAPER_LOAD))' 'Child Make load limit; empty disables this throttle'
	@printf '  %-32s %s\n' 'PARALLEL_DELAY ($(PARALLEL_DELAY))' 'Seconds between starts of GNU parallel collection jobs; default 3'
	@printf '  %-32s %s\n' 'COLLECTION_LOG ($(COLLECTION_LOG))' 'Copy of all collection output; empty disables; see collection-latest.log'
	@printf '  %-32s %s\n' 'HALT_ON_ERROR ($(HALT_ON_ERROR))' 'Set to 1 to stop GNU parallel on the first failing job; default 0'
	@echo ""
	@echo "TUNING:"
	@echo "  CPU work: set COLLECTION_JOBS and NEWSPAPER_JOBS together; keep load limits enabled"
	@echo "  GPU work: set COLLECTION_JOBS to desired workers; clear load/memory limits for exact concurrency"
	@echo "  Memory pressure: reduce COLLECTION_JOBS or raise COLLECTION_MEMFREE; system lag: lower load limits"
	@echo "  make -n collection  # Pass dry-run mode to GNU parallel and child Make processes"
	@echo ""
	@echo "EXAMPLES:"
	@echo "  make collection COLLECTION_JOBS=8 NEWSPAPER_JOBS=2 MAX_LOAD=12"
	@echo "  make collection COLLECTION_JOBS=6 NEWSPAPER_JOBS=1 COLLECTION_LOAD= COLLECTION_MEMFREE= NEWSPAPER_LOAD= PARALLEL_DELAY=0"
	@echo "  tail -f build.d/collection.joblog  # Monitor collection progress"
	@echo "  less -R build.d/logs/collection-latest.log  # Inspect output and errors of the last collection run"
# Log file that receives a copy of all collection output (stdout and stderr)
#
# The output is still shown on the terminal. Each run writes a new timestamped
# file, and collection-latest.log points to the most recent one. Set
# COLLECTION_LOG= to disable logging.
ifeq ($(origin COLLECTION_LOG),undefined)
COLLECTION_LOG := $(BUILD_DIR)/logs/collection-$(shell date +%Y%m%d-%H%M%S).log
endif
  $(call log.debug, COLLECTION_LOG)

# Internal: tee the parallel pipeline into COLLECTION_LOG and keep its exit
# status (dash has no pipefail, so the status goes through a side file).
ifneq ($(COLLECTION_LOG),)
COLLECTION_LOG_REDIRECT := 2>&1; echo $$? > $(COLLECTION_LOG).rc; } | tee -a $(COLLECTION_LOG); rc=$$(cat $(COLLECTION_LOG).rc); rm -f $(COLLECTION_LOG).rc; exit $$rc
else
COLLECTION_LOG_REDIRECT := ; }
endif

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
	$(MAKE) $(MAKE_DRY_RUN_OPTION) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) NEWSPAPER='$(NEWSPAPER)' NEWSPAPER_YEARS='$(NEWSPAPER_YEARS)' sync
	$(MAKE) $(MAKE_DRY_RUN_OPTION) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) NEWSPAPER='$(NEWSPAPER)' NEWSPAPER_YEARS='$(NEWSPAPER_YEARS)' -j $(NEWSPAPER_JOBS) $(NEWSPAPER_LOAD_OPTION) processing-target

.PHONY: newspaper

# USER-VARIABLE: S3_DELETE_NEWSPAPER_PREFIX
# Active processing fragments set this to their newspaper-level S3 output path.
# Override only when a Makefile has multiple processing outputs.

# USER-VARIABLE: S3_DELETE_NEWSPAPER_PREFIXES
# Newspaper-level S3 output paths to print deletion commands for.
# Defaults to the single processing output path; multi-stage pipelines can set a list.
S3_DELETE_NEWSPAPER_PREFIXES ?= $(if $(filter undefined,$(origin S3_DELETE_NEWSPAPER_PREFIX)),,$(S3_DELETE_NEWSPAPER_PREFIX))

# TARGET: show-delete-newspaper-s3
#: Print a dry-run AWS command for deleting one newspaper prefix from S3.
#: This target only prints the command; a human must run it separately.
show-delete-newspaper-s3:
	@test -n "$(strip $(S3_DELETE_NEWSPAPER_PREFIXES))" || { echo "ERROR: No processing S3 output path is configured; include a processing_*.mk fragment or set S3_DELETE_NEWSPAPER_PREFIXES."; exit 1; }
	@$(if $(filter aws.mk,$(notdir $(MAKEFILE_LIST))),:,echo 'WARNING: cookbook/aws.mk is not included; include it and set up AWS CLI credentials before running the printed command.')
	@for prefix in $(S3_DELETE_NEWSPAPER_PREFIXES); do \
		case "$$prefix" in s3://*/*) ;; *) echo "ERROR: Invalid newspaper-level S3 path: $$prefix"; exit 1 ;; esac; \
		printf 'AWS_CONFIG_FILE=.aws/config AWS_SHARED_CREDENTIALS_FILE=.aws/credentials aws s3 rm "%s/" --recursive --dryrun\n' "$${prefix%/}"; \
	done

.PHONY: show-delete-newspaper-s3

help-orchestration::
	@echo ""
	@echo "RELATED TARGETS:"
	@echo "  make newspaper-list-target       # Discover collection items into $(NEWSPAPERS_TO_PROCESS_FILE)"
	@echo "  make show-delete-newspaper-s3    # Print a manual, dry-run S3 deletion command for the active newspaper; does not call AWS"


# TARGET: all
# Complete processing with fresh data sync
# Steps:
# 1. Resync data (serial)
# 2. Process data (parallel)
# Note: The two Make invocations are separate to ensure sync completes before processing starts
# Use this target when a forced local sync-state refresh is desired, for example
# before explicit single-newspaper multimachine coordination checks.
all:
	$(MAKE) $(MAKE_DRY_RUN_OPTION) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) NEWSPAPER='$(NEWSPAPER)' NEWSPAPER_YEARS='$(NEWSPAPER_YEARS)' -j 1 resync-input resync-output
	$(MAKE) $(MAKE_DRY_RUN_OPTION) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) NEWSPAPER='$(NEWSPAPER)' NEWSPAPER_YEARS='$(NEWSPAPER_YEARS)' -j $(NEWSPAPER_JOBS) $(NEWSPAPER_LOAD_OPTION) processing-target

.PHONY: all


# USER-VARIABLE: COLLECTION_TARGET
# Target executed by collection runners for each newspaper item (default: newspaper)
# Can be overridden to 'all' to enforce input/output resync, or other targets like 'sync-input'.
COLLECTION_TARGET ?= newspaper
  $(call log.info, COLLECTION_TARGET)

# TARGET: collection
#: Process multiple newspapers with specified parallel processing
# Uses xargs for parallel execution with COLLECTION_JOBS limit.
# Runs COLLECTION_TARGET (default: newspaper) for each item.
collection-xargs: newspaper-list-target | $(BUILD_DIR)
	@printf '%s\n' 'INFO: Collection worker target: $(COLLECTION_TARGET). List: $(NEWSPAPERS_TO_PROCESS_FILE).'
	+tr " " "\n" < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	xargs -n 1 -P $(COLLECTION_JOBS) -I {} \
		sh -c 'item="$$1"; year=""; newspaper="$$item"; candidate="$${item##*/}"; case "$$item" in */*/*) if expr "$$candidate" : "[0-9][0-9][0-9][0-9]$$" >/dev/null; then newspaper="$${item%/*}"; year="$$candidate"; fi ;; esac; $(MAKE) $(MAKE_DRY_RUN_OPTION) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) NEWSPAPER="$$newspaper" NEWSPAPER_YEARS="$$year" NEWSPAPER_LOAD='"'"'$(NEWSPAPER_LOAD)'"'"' -k -j $(NEWSPAPER_JOBS) $(NEWSPAPER_LOAD_OPTION) $(COLLECTION_TARGET)' sh {}


check-parallel:
	@parallel --version | grep -q 'GNU parallel' || \
	( echo "ERROR: GNU parallel not installed or a wrong variant"; exit 1 )
.PHONY: check-parallel

# TARGET: collection
#: Process full impresso collection with specified parallel processing
# Uses GNU parallel for better control over job execution
# Note: Requires GNU parallel installed
# Dependencies: newspaper-list-target
# Runs COLLECTION_TARGET (default: newspaper) for each item.
collection: check-parallel newspaper-list-target | $(BUILD_DIR)
	@printf '%s\n' 'INFO: Collection worker target: $(COLLECTION_TARGET). List: $(NEWSPAPERS_TO_PROCESS_FILE).'
	# tail -f $(BUILD_DIR)/collection.joblog to monitor per newspaper progress summary
	$(if $(COLLECTION_LOG),@mkdir -p $(dir $(COLLECTION_LOG)) && ln -sfn $(notdir $(COLLECTION_LOG)) $(dir $(COLLECTION_LOG))collection-latest.log && printf '%s\n' 'INFO: Logging collection output to $(COLLECTION_LOG)')
	+{ tr -s '[:space:]' '\n'  < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	parallel  --tag -v \
	   --progress \
	   --joblog $(BUILD_DIR)/collection.joblog \
	   $(PARALLEL_DRY_RUN_OPTION) \
	   --jobs $(COLLECTION_JOBS) \
	   --delay $(PARALLEL_DELAY) \
	   $(COLLECTION_MEMFREE_OPTION) \
	   $(COLLECTION_LOAD_OPTION) \
	   $(PARALLEL_HALT) \
	   'item={}; year=""; newspaper="$$item"; candidate="$${item##*/}"; case "$$item" in */*/*) if expr "$$candidate" : "[0-9][0-9][0-9][0-9]$$" >/dev/null; then newspaper="$${item%/*}"; year="$$candidate"; fi ;; esac; $(MAKE) $(MAKE_DRY_RUN_OPTION) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) NEWSPAPER="$$newspaper" NEWSPAPER_YEARS="$$year" NEWSPAPER_LOAD='"'"'$(NEWSPAPER_LOAD)'"'"' -k -j $(NEWSPAPER_JOBS) $(NEWSPAPER_LOAD_OPTION) $(COLLECTION_TARGET)' \
	   $(COLLECTION_LOG_REDIRECT)

define collection_newspaper_scope_target
	+tr -s '[:space:]' '\n' < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	parallel --tag -v \
	   --joblog $(BUILD_DIR)/$(1).joblog \
	   $(PARALLEL_DRY_RUN_OPTION) \
	   --jobs $(COLLECTION_JOBS) \
	   --delay $(PARALLEL_DELAY) \
	   $(COLLECTION_MEMFREE_OPTION) \
	   $(COLLECTION_LOAD_OPTION) \
	   $(PARALLEL_HALT) \
	   'item={}; newspaper="$$item"; candidate="$${item##*/}"; case "$$item" in */*/*) if expr "$$candidate" : "[0-9][0-9][0-9][0-9]$$" >/dev/null; then newspaper="$${item%/*}"; fi ;; esac; $(MAKE) $(MAKE_DRY_RUN_OPTION) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) NEWSPAPER="$$newspaper" NEWSPAPER_YEARS= NEWSPAPER_LOAD='"'"'$(NEWSPAPER_LOAD)'"'"' -k -j 1 $(NEWSPAPER_LOAD_OPTION) $(2)'
endef

# TARGET: clean-collection-input
#: Remove local input sync state for every newspaper represented in the collection list
clean-collection-input: check-parallel newspaper-list-target | $(BUILD_DIR)
	$(call collection_newspaper_scope_target,clean-collection-input,clean-sync-input)

.PHONY: clean-collection-input

# TARGET: clean-collection-output
#: Remove local output sync state for every newspaper represented in the collection list
clean-collection-output: check-parallel newspaper-list-target | $(BUILD_DIR)
	$(call collection_newspaper_scope_target,clean-collection-output,clean-sync-output)

.PHONY: clean-collection-output

# TARGET: clean-collection-sync
#: Remove local input and output sync state for every newspaper represented in the collection list
clean-collection-sync: clean-collection-input clean-collection-output

.PHONY: clean-collection-sync

# TARGET: sync-collection-input
#: Synchronize input state for every newspaper represented in the collection list
sync-collection-input: check-parallel newspaper-list-target | $(BUILD_DIR)
	$(call collection_newspaper_scope_target,sync-collection-input,sync-input)

.PHONY: sync-collection-input

# TARGET: sync-collection-output
#: Synchronize output state for every newspaper represented in the collection list
sync-collection-output: check-parallel newspaper-list-target | $(BUILD_DIR)
	$(call collection_newspaper_scope_target,sync-collection-output,sync-output)

.PHONY: sync-collection-output

# TARGET: resync-collection-input
#: Clean then synchronize input state for every newspaper represented in the collection list
resync-collection-input: clean-collection-input sync-collection-input

.PHONY: resync-collection-input

# TARGET: resync-collection-output
#: Clean then synchronize output state for every newspaper represented in the collection list
resync-collection-output: clean-collection-output sync-collection-output

.PHONY: resync-collection-output

# TARGET: resync-collection
#: Clean then synchronize input and output state for every newspaper represented in the collection list
resync-collection: resync-collection-input resync-collection-output

.PHONY: resync-collection

help-orchestration::
	@echo "  make clean-collection-input      # Remove local input sync state for listed newspapers (GNU parallel)"
	@echo "  make clean-collection-output     # Remove local output sync state for listed newspapers (GNU parallel)"
	@echo "  make resync-collection-output    # Refresh local output sync state for listed newspapers (GNU parallel)"
	@echo "  make help-newspaper-list         # Show list generation modes, filters, and file settings"


.PHONY: collection

$(call log.debug, COOKBOOK END INCLUDE: cookbook/main_targets.mk)
