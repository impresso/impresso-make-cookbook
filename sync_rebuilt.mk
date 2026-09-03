$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_rebuilt.mk)

###############################################################################
# SYNC REBUILT DATA TARGETS
# Targets for synchronizing rebuilt data from S3 to local storage
###############################################################################


# Local synchronization stamp file for rebuilt input data
LOCAL_REBUILT_SYNC_STAMP_FILE := $(LOCAL_PATH_REBUILT).last_synced
  $(call log.debug, LOCAL_REBUILT_SYNC_STAMP_FILE)

# TARGET: sync-rebuilt
# Synchronizes rebuilt input data from S3 to local directory
sync-rebuilt: $(LOCAL_REBUILT_SYNC_STAMP_FILE)

.PHONY: sync-rebuilt

help-sync::
	@echo ""
	@echo "REBUILT INPUT SYNC:"
	@echo "  sync-rebuilt    # Synchronize rebuilt input data from S3 to local stamp files"
	@echo "                  # Set NEWSPAPER_YEARS='1850 1875' to limit sync/processing to selected years"


# Rule to sync the input data from the S3 bucket to the local directory
# Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_PATH_REBUILT).last_synced:
	$(call sync_year_aware_per_file_stamps,$(S3_PATH_REBUILT),$@,)



$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_rebuilt.mk)
