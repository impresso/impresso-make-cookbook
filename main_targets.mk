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
	$(MAKE) -j 1 sync-input resync-output
	sleep 2
	$(MAKE) -j $(MAKE_PARALLEL_PROCESSING_NEWSPAPER_YEAR) --max-load $(MACHINE_MAX_LOAD) processing-target

PHONY_TARGETS += all


# TARGET: collection
# Process multiple newspapers with controlled parallelism
# Uses xargs for parallel execution with PARALLEL_NEWSPAPERS limit
collection-xargs: newspaper-list-target
	tr " " "\n" < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	xargs -n 1 -P $(PARALLEL_NEWSPAPERS) -I {} \
		$(MAKE) NEWSPAPER={} -k --max-load $(MACHINE_MAX_LOAD) all 

collection: newspaper-list-target
	tr " " "\n" < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	parallel --jobs $(PARALLEL_NEWSPAPERS) --load $(MACHINE_MAX_LOAD)  \
		"sleep 1 ; $(MAKE) NEWSPAPER={} -k --max-load $(MACHINE_MAX_LOAD) all"

# Alternative implementation using GNU parallel
# collection: newspaper-list-target
#	cat $(NEWSPAPERS_TO_PROCESS_FILE) | \
#	parallel -j $(PARALLEL_NEWSPAPERS) \
#		"$(MAKE) NEWSPAPER={} all"

PHONY_TARGETS += collection

$(call log.debug, COOKBOOK END INCLUDE: cookbook/main_targets.mk)
