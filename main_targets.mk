$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/main_targets.mk)
###############################################################################
# MAIN PROCESSING TARGETS
# Core targets for newspaper processing pipeline
###############################################################################



# TARGET: newspaper
# Process a single newspaper through the linguistic processing pipeline
# Dependencies: 
# - sync: Ensures data is synchronized
# - processing-target: Performs the actual processing
newspaper: | $(BUILD_DIR)
	$(MAKE) sync
	$(MAKE) processing-target

PHONY_TARGETS += newspaper

# TARGET: all
# Complete processing with fresh data sync
# Steps:
# 1. Resync data (serial)
# 2. Process data (parallel)
all:
	$(MAKE) sync-input resync-output 
	$(MAKE) -j $(MAKE_PARALLEL_PROCESSING_NEWSPAPER_YEAR) processing-target

PHONY_TARGETS += all

# Maximum number of parallel newspaper processes
# Can be overridden via command line: make PARALLEL_NEWSPAPERS=4 collection
PARALLEL_NEWSPAPERS ?= 2

# TARGET: collection
# Process multiple newspapers with controlled parallelism
# Uses xargs for parallel execution with PARALLEL_NEWSPAPERS limit
collection: newspaper-list-target
	tr " " "\n" < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	xargs -n 1 -P $(PARALLEL_NEWSPAPERS) -I {} \
		$(MAKE) NEWSPAPER={} -k all 

# Alternative implementation using GNU parallel
# collection: newspaper-list-target
#	cat $(NEWSPAPERS_TO_PROCESS_FILE) | \
#	parallel -j $(PARALLEL_NEWSPAPERS) \
#		"$(MAKE) NEWSPAPER={} all"

PHONY_TARGETS += collection

$(call log.debug, COOKBOOK END INCLUDE: cookbook/main_targets.mk)
