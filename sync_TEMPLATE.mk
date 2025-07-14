$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_TEMPLATE.mk)

###############################################################################
# SYNC TEMPLATE processing TARGETS
# Targets for synchronizing processed TEMPLATE processing data between S3 and local storage
###############################################################################


# VARIABLE: LOCAL_TEMPLATE_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed TEMPLATE processing data
LOCAL_TEMPLATE_SYNC_STAMP_FILE := $(LOCAL_PATH_TEMPLATE).last_synced
  $(call log.debug, LOCAL_TEMPLATE_SYNC_STAMP_FILE)

# USER-VARIABLE: LOCAL_TEMPLATE_STAMP_SUFFIX
# Suffix for local stamp files (used to track S3 synchronization status)
LOCAL_TEMPLATE_STAMP_SUFFIX ?= $(LOCAL_STAMP_SUFFIX)
  $(call log.debug, LOCAL_TEMPLATE_STAMP_SUFFIX)

# STAMPED-FILE-RULE: $(LOCAL_PATH_TEMPLATE).last_synced
#: Synchronizes data from S3 to the local directory
$(LOCAL_PATH_TEMPLATE).last_synced:
	mkdir -p $(@D) && \
	python  -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_TEMPLATE) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_TEMPLATE_STAMP_SUFFIX) \
	   --logfile $@.log.gz && \
	touch $@

# TARGET: sync-TEMPLATE
#: Synchronizes TEMPLATE processing data from/to S3
sync-TEMPLATE: $(LOCAL_TEMPLATE_SYNC_STAMP_FILE)

.PHONY: sync-TEMPLATE

# TARGET: clean-sync
#: Cleans up synchronized TEMPLATE processing data
clean-sync:: clean-sync-TEMPLATE

# TARGET: clean-sync-TEMPLATE
#: Removes local synchronization stamp files for TEMPLATE processing
clean-sync-TEMPLATE:
	rm -vrf $(LOCAL_TEMPLATE_SYNC_STAMP_FILE) $(LOCAL_PATH_TEMPLATE) || true

.PHONY: clean-sync-TEMPLATE

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_TEMPLATE.mk)
