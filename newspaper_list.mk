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

# USER-VARIABLE: PROVIDER
# Data provider organization (e.g., BL, SWA, NZZ)
# Required for canonical data which is organized as PROVIDER/NEWSPAPER/
P#ROVIDER ?= BL
  $(call log.info, PROVIDER)


# USER-VARIABLE: NEWSPAPER
# Default newspaper selection if none is specified
#NEWSPAPER ?= WTCH
  $(call log.info, NEWSPAPER)


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


# USER-VARIABLE: NEWSPAPER_HAS_PROVIDER
# Flag to indicate if newspapers are organized with PROVIDER level in S3
# Set to 1 for PROVIDER/NEWSPAPER structure, 0 for NEWSPAPER only
NEWSPAPER_HAS_PROVIDER ?= 1
  $(call log.info, NEWSPAPER_HAS_PROVIDER)

# USER-VARIABLE: NEWSPAPER_PREFIX
# Additional prefix for newspaper paths to filter specific subsets (e.g. BL/ for processing only BL newspapers)
NEWSPAPER_PREFIX ?= $(EMPTY)
  $(call log.debug, NEWSPAPER_PREFIX)

# USER-VARIABLE: NEWSPAPER_FNMATCH
# Additional pattern for newspaper paths to filter specific subsets (e.g. BL/ for processing only BL newspapers)
NEWSPAPER_FNMATCH ?= $(EMPTY)
  $(call log.info, NEWSPAPER_FNMATCH)


# USER-VARIABLE: S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET
# S3 bucket prefix containing newspapers for processing
# For consolidated canonical processing, use the canonical bucket
S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET ?= $(S3_BUCKET_CANONICAL)
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
			--prefix "$(NEWSPAPER_PREFIX)" \
			--log-level $(LOGGING_LEVEL) --large-first --num-groups 5 \
			$(if $(filter 1,$(NEWSPAPER_HAS_PROVIDER)),--has-provider) \
			$(if $(NEWSPAPER_FNMATCH),--fnmatch '$(NEWSPAPER_FNMATCH)') \
			> $@; \
	else \
		echo "$(NEWSPAPERS_TO_PROCESS_FILE) exists; not regenerating. Call `make clean-newspaper-list-target` to remove it."; \
	fi

# TARGET: clean-newspaper-list-target
#: Cleans the generated newspaper list file
clean-newspaper-list-target:
	rm -fv $(NEWSPAPERS_TO_PROCESS_FILE)

.PHONY: clean-newspaper-list-target

# VARIABLE: ALL_NEWSPAPERS
# List all available newspapers for parallel processing using newspaper list definitions
#
# Reads the canonical list of newspaper identifiers from the newspapers file.
# Uses Make's file function to read the contents without spawning a shell.
ALL_NEWSPAPERS := $(file < $(NEWSPAPERS_TO_PROCESS_FILE))
  $(call log.info, ALL_NEWSPAPERS)

$(call log.debug, COOKBOOK END INCLUDE: cookbook/newspaper_list.mk)
