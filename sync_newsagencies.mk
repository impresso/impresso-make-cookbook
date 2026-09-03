$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_newsagencies.mk)

###############################################################################
# SYNC newsagencies processing TARGETS
# Targets for synchronizing processed newsagencies processing data between S3 and local storage
###############################################################################



# VARIABLE: LOCAL_NEWSAGENCIES_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed newsagencies processing data
LOCAL_NEWSAGENCIES_SYNC_STAMP_FILE := $(call newspaper_sync_stamp_targets,$(LOCAL_PATH_NEWSAGENCIES))
$(call expand_newspaper_year_sync_targets,$(LOCAL_PATH_NEWSAGENCIES))
  $(call log.debug, LOCAL_NEWSAGENCIES_SYNC_STAMP_FILE)

# STAMPED-FILE-RULE: $(LOCAL_PATH_NEWSAGENCIES).last_synced
#: Synchronizes data from S3 to the local directory
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_NEWSAGENCIES_SYNC_STAMP_FILE):
	$(call sync_year_aware_per_file_stamps,$(S3_PATH_NEWSAGENCIES),$@,)

# TARGET: sync-newsagencies
#: Synchronizes newsagencies processing data from/to S3
sync-newsagencies: $(LOCAL_NEWSAGENCIES_SYNC_STAMP_FILE)

.PHONY: sync-newsagencies

# TARGET: clean-sync
#: Cleans up synchronized newsagencies processing data
clean-sync:: clean-sync-newsagencies

# TARGET: clean-sync-newsagencies
#: Removes local synchronization stamp files for newsagencies processing
clean-sync-newsagencies:
	rm -vrf $(call newspaper_sync_clean_files,$(LOCAL_PATH_NEWSAGENCIES)) $(if $(strip $(NEWSPAPER_YEARS)),,$(LOCAL_PATH_NEWSAGENCIES)) || true

.PHONY: clean-sync-newsagencies

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_newsagencies.mk)
