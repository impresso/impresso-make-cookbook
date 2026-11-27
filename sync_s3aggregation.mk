$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_s3aggregation.mk)

###############################################################################
# SYNC s3aggregation processing TARGETS
# Targets for synchronizing processed s3aggregation processing data between S3 and local storage
###############################################################################


# VARIABLE: LOCAL_s3aggregation_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed s3aggregation processing data
LOCAL_s3aggregation_SYNC_STAMP_FILE := $(LOCAL_PATH_s3aggregation).last_synced
  $(call log.debug, LOCAL_s3aggregation_SYNC_STAMP_FILE)

# STAMPED-FILE-RULE: $(LOCAL_PATH_s3aggregation).last_synced
#: Synchronizes data from S3 to the local directory
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_PATH_s3aggregation).last_synced:
	mkdir -p $(@D) && \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_s3aggregation) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz && \
	touch $@

# TARGET: sync-s3aggregation
#: Synchronizes s3aggregation processing data from/to S3
sync-s3aggregation: $(LOCAL_s3aggregation_SYNC_STAMP_FILE)

.PHONY: sync-s3aggregation

# TARGET: clean-sync
#: Cleans up synchronized s3aggregation processing data
clean-sync:: clean-sync-s3aggregation

# TARGET: clean-sync-s3aggregation
#: Removes local synchronization stamp files for s3aggregation processing
clean-sync-s3aggregation:
	rm -vrf $(LOCAL_s3aggregation_SYNC_STAMP_FILE) $(LOCAL_PATH_s3aggregation) || true

.PHONY: clean-sync-s3aggregation

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_s3aggregation.mk)
