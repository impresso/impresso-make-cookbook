$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_bboxqa.mk)

###############################################################################
# SYNC BBOX QUALITY ASSESSMENT TARGETS
# Targets for synchronizing processed BBOX quality assessment data between S3 and local storage
###############################################################################



# VARIABLE: LOCAL_BBOXQA_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed BBOX quality assessment data
LOCAL_BBOXQA_SYNC_STAMP_FILE := $(call newspaper_sync_stamp_targets,$(LOCAL_PATH_BBOXQA))
$(call expand_newspaper_year_sync_targets,$(LOCAL_PATH_BBOXQA))
  $(call log.debug, LOCAL_BBOXQA_SYNC_STAMP_FILE)

# STAMPED-FILE-RULE: $(LOCAL_PATH_BBOXQA).last_synced
#: Synchronizes data from S3 to the local directory
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_BBOXQA_SYNC_STAMP_FILE):
	$(call sync_year_aware_per_file_stamps,$(S3_PATH_BBOXQA),$@,)

# TARGET: sync-bboxqa
#: Synchronizes BBOX quality assessment data from/to S3
sync-bboxqa: $(LOCAL_BBOXQA_SYNC_STAMP_FILE)

.PHONY: sync-bboxqa

help-sync::
	@echo ""
	@echo "BBOXQA SYNC:"
	@echo "  sync-bboxqa    # Synchronize BBOX quality assessment data from/to S3"

# TARGET: clean-sync
#: Cleans up synchronized BBOX quality assessment data
clean-sync:: clean-sync-bboxqa

# TARGET: clean-sync-bboxqa
#: Removes local synchronization stamp files for BBOX quality assessment
clean-sync-bboxqa:
	rm -vrf $(call newspaper_sync_clean_files,$(LOCAL_PATH_BBOXQA)) $(if $(strip $(NEWSPAPER_YEARS)),,$(LOCAL_PATH_BBOXQA)) || true

.PHONY: clean-sync-bboxqa

help-clean::
	@echo "  clean-sync-bboxqa # Remove local BBOXQA sync state for the selected scope"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_bboxqa.mk)
