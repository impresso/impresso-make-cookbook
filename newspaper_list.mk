$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/newspaper_list.mk)

###############################################################################
# NEWSPAPER LIST MANAGEMENT
# Configuration and generation of newspaper processing lists
#
# This Makefile sets up the configuration and processing order of newspaper
# lists retrieved from an S3 bucket. The list is either shuffled or kept in
# chronological order, based on user settings.
###############################################################################


help::
	@echo "  newspaper-list-target  # Generate newspaper list to process from the S3 bucket content: '$(NEWSPAPERS_TO_PROCESS_FILE)'"


sync:: newspaper-list-target

# USER-VARIABLE: NEWSPAPER
# Default newspaper selection if none is specified
NEWSPAPER ?= actionfem
  $(call log.debug, NEWSPAPER)


# USER-VARIABLE: NEWSPAPERS_TO_PROCESS_FILE
# Configuration file containing space-separated newspapers to process
NEWSPAPERS_TO_PROCESS_FILE ?= $(BUILD_DIR)/newspapers.txt
  $(call log.debug, NEWSPAPERS_TO_PROCESS_FILE)


# USER-VARIABLE: NEWSPAPER_YEAR_SORTING
# Determines the order of newspaper processing
# - 'shuf' for random order
# - 'cat' for chronological order
NEWSPAPER_YEAR_SORTING ?= shuf
  $(call log.debug, NEWSPAPER_YEAR_SORTING)


# USER-VARIABLE: S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET
# S3 bucket prefix containing newspapers for processing
S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET ?= 22-rebuilt-final
  $(call log.debug, S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET)


# TARGET: newspaper-list-target
#: Generates a list of newspapers to process from the S3 bucket
newspaper-list-target: $(NEWSPAPERS_TO_PROCESS_FILE)
.PHONY: newspaper-list-target


# FILE-RULE: $(NEWSPAPERS_TO_PROCESS_FILE)
#: Generates the file containing the newspapers to process
#
# This rule retrieves the list of available newspapers from an S3 bucket,
# shuffles them to distribute processing evenly, and writes them to a file.
$(NEWSPAPERS_TO_PROCESS_FILE): | $(BUILD_DIR)
	python cookbook/lib/list_newspapers.py \
		--bucket $(S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET) \
		--log-level WARNING --large-first --num-groups 5\
		> $@


# VARIABLE: ALL_NEWSPAPERS
# List all available newspapers for parallel processing using newspaper list definitions
#
# Reads the canonical list of newspaper identifiers using make's file function
# and newspaper_list.mk definitions to determine which newspapers should be processed.
ALL_NEWSPAPERS := $(file < $(NEWSPAPERS_TO_PROCESS_FILE))
  $(call log.info, ALL_NEWSPAPERS)

$(call log.debug, COOKBOOK END INCLUDE: cookbook/newspaper_list.mk)
