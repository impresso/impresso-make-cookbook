$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_bboxqa.mk)

###############################################################################
# SYNC BBOX QUALITY ASSESSMENT TARGETS
# Targets for synchronizing processed BBOX quality assessment data between S3 and local storage
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes BBOX quality assessment output data
sync-output :: sync-bboxqa

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes BBOX quality assessment input data
sync-input :: sync-bboxqa

# VARIABLE: LOCAL_BBOXQA_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed BBOX quality assessment data
LOCAL_BBOXQA_SYNC_STAMP_FILE := $(LOCAL_PATH_BBOXQA).last_synced
  $(call log.debug, LOCAL_BBOXQA_SYNC_STAMP_FILE)

# USER-VARIABLE: LOCAL_BBOXQA_STAMP_SUFFIX
# Suffix for local stamp files (used to track S3 synchronization status)
LOCAL_BBOXQA_STAMP_SUFFIX ?= $(LOCAL_STAMP_SUFFIX)
  $(call log.debug, LOCAL_BBOXQA_STAMP_SUFFIX)

# STAMPED-FILE-RULE: $(LOCAL_PATH_BBOXQA).last_synced
#: Synchronizes data from S3 to the local directory
$(LOCAL_PATH_BBOXQA).last_synced:
	mkdir -p $(@D) && \
	python lib/s3_to_local_stamps.py \
	   $(S3_PATH_BBOXQA) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_BBOXQA_STAMP_SUFFIX) \
	   --logfile $@.log.gz && \
	touch $@

# TARGET: sync-bboxqa
#: Synchronizes BBOX quality assessment data from/to S3
sync-bboxqa: $(LOCAL_BBOXQA_SYNC_STAMP_FILE)

PHONY_TARGETS += sync-bboxqa

# TARGET: clean-sync
#: Cleans up synchronized BBOX quality assessment data
clean-sync:: clean-sync-bboxqa

# TARGET: clean-sync-bboxqa
#: Removes local synchronization stamp files for BBOX quality assessment
clean-sync-bboxqa:
	rm -vrf $(LOCAL_BBOXQA_SYNC_STAMP_FILE) $(LOCAL_PATH_BBOXQA) || true

PHONY_TARGETS += clean-sync-bboxqa

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_bboxqa.mk)
