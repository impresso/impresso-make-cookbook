$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_ocrqa.mk)

###############################################################################
# SYNC OCR QUALITY ASSESSMENT TARGETS
# Targets for synchronizing processed OCR quality assessment data between S3 and local storage
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes OCR quality assessment output data
sync-output :: sync-ocrqa

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes OCR quality assessment input data
sync-input :: sync-ocrqa

# VARIABLE: LOCAL_OCRQA_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed OCR quality assessment data
LOCAL_OCRQA_SYNC_STAMP_FILE := $(LOCAL_PATH_OCRQA).last_synced
  $(call log.debug, LOCAL_OCRQA_SYNC_STAMP_FILE)

# USER-VARIABLE: LOCAL_OCRQA_STAMP_SUFFIX
# Suffix for local stamp files (used to track S3 synchronization status)
LOCAL_OCRQA_STAMP_SUFFIX ?= $(LOCAL_STAMP_SUFFIX)
  $(call log.debug, LOCAL_OCRQA_STAMP_SUFFIX)

# STAMPED-FILE-RULE: $(LOCAL_PATH_OCRQA).last_synced
#: Synchronizes data from S3 to the local directory
$(LOCAL_PATH_OCRQA).last_synced:
	mkdir -p $(@D) && \
	python lib/s3_to_local_stamps.py \
	   $(S3_PATH_OCRQA) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_OCRQA_STAMP_SUFFIX) \
	   --logfile $@.log.gz && \
	touch $@

# TARGET: sync-ocrqa
#: Synchronizes OCR quality assessment data from/to S3
sync-ocrqa: $(LOCAL_OCRQA_SYNC_STAMP_FILE)

PHONY_TARGETS += sync-ocrqa

# TARGET: clean-sync
#: Cleans up synchronized OCR quality assessment data
clean-sync:: clean-sync-ocrqa

# TARGET: clean-sync-ocrqa
#: Removes local synchronization stamp files for OCR quality assessment
clean-sync-ocrqa:
	rm -vrf $(LOCAL_OCRQA_SYNC_STAMP_FILE) $(LOCAL_PATH_OCRQA) || true

PHONY_TARGETS += clean-sync-ocrqa

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_ocrqa.mk)
