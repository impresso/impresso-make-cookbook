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


# TARGET: all
# Complete processing with fresh data sync
# Steps:
# 1. Resync data (serial)
# 2. Process data (parallel)
all:
	$(MAKE) -j 1 sync-input resync-output
	$(MAKE) -j $(MAKE_PARALLEL_PROCESSING_NEWSPAPER_YEAR) --max-load $(MACHINE_MAX_LOAD) processing-target
	sleep 3

.PHONY: all


# TARGET: collection
#: Process multiple newspapers with specified parallel processing
# Uses xargs for parallel execution with PARALLEL_NEWSPAPERS limit
collection-xargs: newspaper-list-target
	tr " " "\n" < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	xargs -n 1 -P $(PARALLEL_NEWSPAPERS) -I {} \
		$(MAKE) NEWSPAPER={} -k --max-load $(MACHINE_MAX_LOAD) all 

collection: newspaper-list-target
	tr " " "\n" < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	parallel --jobs $(PARALLEL_NEWSPAPERS) --load $(MACHINE_MAX_LOAD)  \
		"$(MAKE) NEWSPAPER={} -k --max-load $(MACHINE_MAX_LOAD) all; sleep 3"

help::
	@echo "  collection        #  Process multiple newspapers with specified parallel processing"

# Alternative implementation using GNU parallel
# collection: newspaper-list-target
#	cat $(NEWSPAPERS_TO_PROCESS_FILE) | \
#	parallel -j $(PARALLEL_NEWSPAPERS) \
#		"$(MAKE) NEWSPAPER={} all"

.PHONY: collection

$(call log.debug, COOKBOOK END INCLUDE: cookbook/main_targets.mk)
