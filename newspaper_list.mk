$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/newspaper_list.mk)

###############################################################################
# NEWSPAPER LIST MANAGEMENT
# Configuration and generation of newspaper processing lists
#
# This Makefile sets up the configuration and processing order of newspaper
# lists retrieved from an S3 bucket. The list is either shuffled or kept in
# chronological order, based on user settings.
###############################################################################


# USER-VARIABLE: PROVIDER
# Data provider organization (e.g., BL, SWA, NZZ)
# Required for canonical data which is organized as PROVIDER/NEWSPAPER/
#PROVIDER ?= BL
PROVIDER ?=
  $(call log.info, PROVIDER)


# USER-VARIABLE: NEWSPAPER
# Default newspaper selection if none is specified
NEWSPAPER ?= BNL/actionfem
  $(call log.info, NEWSPAPER)


# USER-VARIABLE: NEWSPAPERS_TO_PROCESS_FILE
# Configuration file containing space-separated newspapers to process
NEWSPAPERS_TO_PROCESS_FILE ?= $(BUILD_DIR)/newspapers.txt
  $(call log.debug, NEWSPAPERS_TO_PROCESS_FILE)


# USER-VARIABLE: NEWSPAPERS_TO_PROCESS_LOG_FILE
# Log file capturing the newspaper list generation process
NEWSPAPERS_TO_PROCESS_LOG_FILE ?= $(NEWSPAPERS_TO_PROCESS_FILE).log.gz
  $(call log.debug, NEWSPAPERS_TO_PROCESS_LOG_FILE)


# USER-VARIABLE: NEWSPAPER_YEAR_SORTING
# Determines the order of newspaper processing
# - 'shuf' for random order
# - 'cat' for chronological order
NEWSPAPER_YEAR_SORTING ?= shuf
  $(call log.debug, NEWSPAPER_YEAR_SORTING)

# USER-VARIABLE: NEWSPAPER_YEARS
# Optional space-separated list of years to process for the current newspaper.
# Collection entries in PROVIDER/NEWSPAPER/YEAR form set this automatically.
NEWSPAPER_YEARS ?=
  $(call log.debug, NEWSPAPER_YEARS)

# INTERNAL VARIABLE: NEWSPAPER_YEAR
# Sync work-unit year set by Make target-specific variable assignments.
# Users should set NEWSPAPER_YEARS instead.
NEWSPAPER_YEAR ?=
  $(call log.debug, NEWSPAPER_YEAR)

# USER-VARIABLE: NEWSPAPER_LIST_INCLUDE_YEARS
# If set to 1, generate collection items as PROVIDER/NEWSPAPER/YEAR instead of
# newspaper-only identifiers.
NEWSPAPER_LIST_INCLUDE_YEARS ?= 0
  $(call log.debug, NEWSPAPER_LIST_INCLUDE_YEARS)

# USER-VARIABLE: NEWSPAPER_LIST_YEAR_STEP
# When generating year-aware collection items, select the first available year,
# then the earliest available year at least this many years after the previous
# selected year.
NEWSPAPER_LIST_YEAR_STEP ?=
  $(call log.debug, NEWSPAPER_LIST_YEAR_STEP)

# USER-VARIABLE: NEWSPAPER_LIST_YEARS
# Optional explicit years to include when generating year-aware collection items.
NEWSPAPER_LIST_YEARS ?=
  $(call log.debug, NEWSPAPER_LIST_YEARS)


# USER-VARIABLE: NEWSPAPER_HAS_PROVIDER
# Flag to indicate if newspapers are organized with PROVIDER level in S3
# Set to 1 for PROVIDER/NEWSPAPER structure, 0 for NEWSPAPER only
NEWSPAPER_HAS_PROVIDER ?= 1
  $(call log.info, NEWSPAPER_HAS_PROVIDER)

# USER-VARIABLE: NEWSPAPER_PREFIX
# Additional prefix for newspaper paths to filter specific subsets (e.g. BL/ for processing only BL newspapers)
NEWSPAPER_PREFIX ?=
  $(call log.debug, NEWSPAPER_PREFIX)

# USER-VARIABLE: NEWSPAPER_FNMATCH
# Additional pattern for newspaper paths to filter specific subsets (e.g. BL/ for processing only BL newspapers)
NEWSPAPER_FNMATCH ?=
  $(call log.info, NEWSPAPER_FNMATCH)

help-orchestration::
	@echo ""
	@echo "NEWSPAPER LIST TARGETS:"
	@echo "  newspaper-list-target # Discover collection items into $(NEWSPAPERS_TO_PROCESS_FILE)"
	@echo "  help-newspaper-list   # Show newspaper list generation modes and variables"

help-newspaper-list:
	@echo ""
	@echo "NEWSPAPER LIST GENERATION:"
	@echo "  newspaper-list-target       # Discover collection items into NEWSPAPERS_TO_PROCESS_FILE"
	@echo "  clean-newspaper-list-target # Remove generated list and log files"
	@echo ""
	@echo "OUTPUT FILES:"
	@echo "  NEWSPAPERS_TO_PROCESS_FILE=$(NEWSPAPERS_TO_PROCESS_FILE)"
	@echo "  NEWSPAPERS_TO_PROCESS_LOG_FILE=$(NEWSPAPERS_TO_PROCESS_LOG_FILE)"
	@echo ""
	@echo "SUPPORTED LIST ENTRY FORMATS:"
	@echo "  NEWSPAPER"
	@echo "  PROVIDER/NEWSPAPER"
	@echo "  PROVIDER/NEWSPAPER/YEAR"
	@echo ""
	@echo "DISCOVERY FILTERS:"
	@echo "  S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET=$(S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET)"
	@echo "  NEWSPAPER_HAS_PROVIDER=$(NEWSPAPER_HAS_PROVIDER)"
	@echo "  NEWSPAPER_PREFIX=$(NEWSPAPER_PREFIX)"
	@echo "  NEWSPAPER_FNMATCH=$(NEWSPAPER_FNMATCH)"
	@echo ""
	@echo "YEAR-AWARE GENERATION:"
	@echo "  NEWSPAPER_LIST_INCLUDE_YEARS=$(NEWSPAPER_LIST_INCLUDE_YEARS)"
	@echo "  NEWSPAPER_LIST_YEAR_STEP=$(NEWSPAPER_LIST_YEAR_STEP)"
	@echo "  NEWSPAPER_LIST_YEARS=$(NEWSPAPER_LIST_YEARS)"
	@echo ""
	@echo "EXAMPLES:"
	@echo "  make newspaper-list-target"
	@echo "  make clean-newspaper-list-target newspaper-list-target"
	@echo "  make newspaper-list-target NEWSPAPER_LIST_INCLUDE_YEARS=1 NEWSPAPER_LIST_YEAR_STEP=25"

.PHONY: help-newspaper-list


# USER-VARIABLE: S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET
# S3 bucket prefix containing newspapers for processing
# For consolidated canonical processing, use the canonical bucket.
# If it is not defined in the current include set, fall back to rebuilt.
S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET ?= $(or $(value S3_BUCKET_CANONICAL),$(value S3_BUCKET_REBUILT))
  $(call log.debug, S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET)


# TARGET: newspaper-list-target
#: Generates a list of newspapers to process from the S3 bucket
newspaper-list-target: | $(NEWSPAPERS_TO_PROCESS_FILE)
.PHONY: newspaper-list-target


# FILE-RULE: $(NEWSPAPERS_TO_PROCESS_FILE)
#: Generates the file containing the newspapers to process
#
# This rule retrieves the list of available newspapers from an S3 bucket,
# shuffles them to distribute processing evenly, and writes them to a file.
$(NEWSPAPERS_TO_PROCESS_FILE): | $(BUILD_DIR)
	@if [ ! -e $@ ]; then \
		python cookbook/lib/list_newspapers.py \
			--bucket $(S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET) \
			--output-file $@ \
			--log-file $(NEWSPAPERS_TO_PROCESS_LOG_FILE) \
			--prefix "$(NEWSPAPER_PREFIX)" \
			--log-level $(LOGGING_LEVEL) --large-first --num-groups 5 \
			$(if $(filter 1,$(NEWSPAPER_HAS_PROVIDER)),--has-provider) \
			$(if $(filter 1,$(NEWSPAPER_LIST_INCLUDE_YEARS)),--include-years) \
			$(if $(NEWSPAPER_LIST_YEAR_STEP),--year-step $(NEWSPAPER_LIST_YEAR_STEP)) \
			$(if $(NEWSPAPER_LIST_YEARS),--years $(NEWSPAPER_LIST_YEARS)) \
			$(if $(NEWSPAPER_FNMATCH),--fnmatch '$(NEWSPAPER_FNMATCH)'); \
	elif [ ! -s $@ ]; then \
		message="WARNING: $(NEWSPAPERS_TO_PROCESS_FILE) exists but is empty; removing it."; \
		echo "$$message" >&2; \
		printf '%s\n' "$$message" > $(NEWSPAPERS_TO_PROCESS_LOG_FILE); \
		rm -fv $@; \
	else \
		message="$(NEWSPAPERS_TO_PROCESS_FILE) exists; not regenerating. Call make clean-newspaper-list-target to remove it."; \
		echo "$$message"; \
		printf '%s\n' "$$message" > $(NEWSPAPERS_TO_PROCESS_LOG_FILE); \
	fi

# TARGET: clean-newspaper-list-target
#: Cleans the generated newspaper list file
clean-newspaper-list-target:
	rm -fv $(NEWSPAPERS_TO_PROCESS_FILE) $(NEWSPAPERS_TO_PROCESS_LOG_FILE)

.PHONY: clean-newspaper-list-target

# VARIABLE: ALL_NEWSPAPERS
# List all available newspapers for parallel processing using newspaper list definitions
#
# Reads the canonical list of newspaper identifiers from the newspapers file.
# Uses Make's file function to read the contents without spawning a shell.
ALL_NEWSPAPERS := $(file < $(NEWSPAPERS_TO_PROCESS_FILE))
ALL_NEWSPAPERS_COUNT := $(words $(ALL_NEWSPAPERS))
ALL_NEWSPAPERS_INFO_PREVIEW := $(if $(word 5,$(ALL_NEWSPAPERS)),$(wordlist 1,3,$(ALL_NEWSPAPERS)) ... $(lastword $(ALL_NEWSPAPERS)) ($(ALL_NEWSPAPERS_COUNT) newspapers),$(ALL_NEWSPAPERS))
  $(if $(LOGGING_SUPPRESSED_FOR_HELP),,$(if $(filter $(LOGGING_LEVEL),DEBUG),$(call log.debug, ALL_NEWSPAPERS),$(if $(filter $(LOGGING_LEVEL),INFO),$(info INFO:: ALL_NEWSPAPERS = "$(ALL_NEWSPAPERS_INFO_PREVIEW)"))))

# FUNCTION: filter_newspaper_year_files
# Filters a whitespace-separated file list to files matching NEWSPAPER_YEARS.
# GNU Make filter patterns support one operative %, so keep these as suffix
# patterns for the current per-year stamp conventions.
filter_newspaper_year_files = $(if $(strip $(NEWSPAPER_YEARS)),$(foreach year,$(strip $(NEWSPAPER_YEARS)),$(filter %-$(year).jsonl.bz2 %-$(year).stamp,$(1))),$(1))

STAMP_SYNC_PYTHON ?= $(or $(value PYTHON),python)
  $(call log.debug, STAMP_SYNC_PYTHON)

# FUNCTION: newspaper_sync_stamp_file
# Args:
#   $(1): base local path for the current newspaper sync scope
#   $(2): year
newspaper_sync_stamp_file = $(1).$(2).last_synced

# FUNCTION: newspaper_sync_stamp_targets
# Args:
#   $(1): base local path for the current newspaper sync scope
newspaper_sync_stamp_targets = $(if $(strip $(NEWSPAPER_YEARS)),$(foreach year,$(strip $(NEWSPAPER_YEARS)),$(call newspaper_sync_stamp_file,$(1),$(year))),$(1).last_synced)

# FUNCTION: expand_newspaper_year_sync_targets
# Args:
#   $(1): base local path used with newspaper_sync_stamp_targets
#
# Assigns the singular NEWSPAPER_YEAR to each per-year stamp target generated
# from NEWSPAPER_YEARS. This is the central Make mechanism that turns the
# plural caller selection into independent sync work units.
expand_newspaper_year_sync_targets = $(foreach year,$(strip $(NEWSPAPER_YEARS)),$(eval $(call newspaper_sync_stamp_file,$(1),$(year)): NEWSPAPER_YEAR := $(year)))

# FUNCTION: newspaper_sync_clean_files
# Args:
#   $(1): base local path for the current newspaper sync scope
#
# With NEWSPAPER_YEARS set, clean the selected year markers. Without a selected
# scope, clean the full-newspaper marker and all year markers for this scope.
newspaper_sync_clean_files = $(if $(strip $(NEWSPAPER_YEARS)),$(foreach year,$(strip $(NEWSPAPER_YEARS)),$(call newspaper_sync_stamp_file,$(1),$(year)) $(call newspaper_sync_stamp_file,$(1),$(year)).log.gz),$(1).last_synced $(1).last_synced.log.gz $(1).*.last_synced $(1).*.last_synced.log.gz)

# FUNCTION: sync_year_aware_per_file_stamps
# Args:
#   $(1): S3 path for the current newspaper
#   $(2): local sync stamp file for one S3 scope
#   $(3): optional extra impresso_cookbook.s3_to_local_stamps arguments
define sync_year_aware_per_file_stamps
mkdir -p $(dir $(2)) && \
if [ -n "$(strip $(NEWSPAPER_YEAR))" ]; then \
  $(STAMP_SYNC_PYTHON) -m impresso_cookbook.s3_to_local_stamps \
    $(1)/$(notdir $(NEWSPAPER))-$(strip $(NEWSPAPER_YEAR)) \
    --local-dir $(BUILD_DIR) \
    --stamp-mode per-file \
    --logfile $(2).log.gz \
    $(3); \
else \
  $(STAMP_SYNC_PYTHON) -m impresso_cookbook.s3_to_local_stamps \
    $(1) \
    --local-dir $(BUILD_DIR) \
    --stamp-mode per-file \
    --logfile $(2).log.gz \
    $(3); \
fi && \
touch $(2)
endef

# FUNCTION: sync_year_aware_per_directory_stamps
# Args:
#   $(1): S3 path for the current newspaper
#   $(2): local sync stamp file for one S3 scope
#   $(3): year directory title prefix, usually $(notdir $(NEWSPAPER))
#   $(4): optional extra impresso_cookbook.s3_to_local_stamps arguments
define sync_year_aware_per_directory_stamps
mkdir -p $(dir $(2)) && \
if [ -n "$(strip $(NEWSPAPER_YEAR))" ]; then \
  $(STAMP_SYNC_PYTHON) -m impresso_cookbook.s3_to_local_stamps \
    $(1)/$(3)-$(strip $(NEWSPAPER_YEAR)) \
    --local-dir $(BUILD_DIR) \
    --stamp-mode per-directory \
    --logfile $(2).log.gz \
    $(4); \
else \
  $(STAMP_SYNC_PYTHON) -m impresso_cookbook.s3_to_local_stamps \
    $(1) \
    --local-dir $(BUILD_DIR) \
    --stamp-mode per-directory \
    --logfile $(2).log.gz \
    $(4); \
fi && \
touch $(2)
endef

$(call log.debug, COOKBOOK END INCLUDE: cookbook/newspaper_list.mk)
