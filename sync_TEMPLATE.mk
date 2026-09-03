$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_TEMPLATE.mk)

###############################################################################
# SYNC TEMPLATE processing TARGETS
# Targets for synchronizing processed TEMPLATE processing data between S3 and local storage
###############################################################################


# VARIABLE: LOCAL_TEMPLATE_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed TEMPLATE processing data
LOCAL_TEMPLATE_SYNC_STAMP_FILE := $(call newspaper_sync_stamp_targets,$(LOCAL_PATH_TEMPLATE))
$(call expand_newspaper_year_sync_targets,$(LOCAL_PATH_TEMPLATE))
  $(call log.debug, LOCAL_TEMPLATE_SYNC_STAMP_FILE)

# STAMPED-FILE-RULE: $(LOCAL_PATH_TEMPLATE).last_synced
#: Synchronizes data from S3 to the local directory
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_TEMPLATE_SYNC_STAMP_FILE):
	$(call sync_year_aware_per_file_stamps,$(S3_PATH_TEMPLATE),$@,)

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
	rm -vrf $(call newspaper_sync_clean_files,$(LOCAL_PATH_TEMPLATE)) $(if $(strip $(NEWSPAPER_YEARS)),,$(LOCAL_PATH_TEMPLATE)) || true

.PHONY: clean-sync-TEMPLATE

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_TEMPLATE.mk)
