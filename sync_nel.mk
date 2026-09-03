$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_nel.mk)

###############################################################################
# SYNC nel processing TARGETS
# Targets for synchronizing processed nel processing data between S3 and local storage
###############################################################################



# VARIABLE: LOCAL_NEL_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed nel processing data
LOCAL_NEL_SYNC_STAMP_FILE := $(call newspaper_sync_stamp_targets,$(LOCAL_PATH_NEL))
$(call expand_newspaper_year_sync_targets,$(LOCAL_PATH_NEL))
  $(call log.debug, LOCAL_NEL_SYNC_STAMP_FILE)

# STAMPED-FILE-RULE: $(LOCAL_PATH_NEL).last_synced
#: Synchronizes data from S3 to the local directory
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_NEL_SYNC_STAMP_FILE):
	$(call sync_year_aware_per_file_stamps,$(S3_PATH_NEL),$@,)

# TARGET: sync-nel
#: Synchronizes nel processing data from/to S3
sync-nel: $(LOCAL_NEL_SYNC_STAMP_FILE)

.PHONY: sync-nel

# TARGET: clean-sync
#: Cleans up synchronized nel processing data
clean-sync:: clean-sync-nel

# TARGET: clean-sync-nel
#: Removes local synchronization stamp files for nel processing
clean-sync-nel:
	rm -vrf $(call newspaper_sync_clean_files,$(LOCAL_PATH_NEL)) $(if $(strip $(NEWSPAPER_YEARS)),,$(LOCAL_PATH_NEL)) || true

.PHONY: clean-sync-nel

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_nel.mk)
