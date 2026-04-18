$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_reocr.mk)
###############################################################################
# SYNC reocr processing TARGETS
###############################################################################

LOCAL_REOCR_INPUT_SYNC_STAMP_FILE := $(LOCAL_PATH_REOCR_INPUT).last_synced
  $(call log.debug, LOCAL_REOCR_INPUT_SYNC_STAMP_FILE)

LOCAL_reocr_SYNC_STAMP_FILE := $(LOCAL_PATH_reocr_STAMPS).last_synced
  $(call log.debug, LOCAL_reocr_SYNC_STAMP_FILE)

LOCAL_reocr_PAGES_SYNC_STAMP_FILE := $(LOCAL_PATH_reocr_PAGES).last_synced
  $(call log.debug, LOCAL_reocr_PAGES_SYNC_STAMP_FILE)

$(LOCAL_PATH_REOCR_INPUT).last_synced:
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_REOCR_INPUT) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

$(LOCAL_PATH_reocr_STAMPS).last_synced:
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_reocr_STAMPS) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

$(LOCAL_PATH_reocr_PAGES).last_synced:
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_reocr_PAGES) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

sync-reocr-input: $(LOCAL_REOCR_INPUT_SYNC_STAMP_FILE)

.PHONY: sync-reocr-input

sync-reocr: $(LOCAL_reocr_SYNC_STAMP_FILE)

.PHONY: sync-reocr

sync-reocr-pages: $(LOCAL_reocr_PAGES_SYNC_STAMP_FILE)

.PHONY: sync-reocr-pages

clean-sync:: clean-sync-reocr

clean-sync-reocr:
	rm -vrf $(LOCAL_REOCR_INPUT_SYNC_STAMP_FILE) $(LOCAL_reocr_SYNC_STAMP_FILE) $(LOCAL_reocr_PAGES_SYNC_STAMP_FILE) $(LOCAL_PATH_REOCR_INPUT) $(LOCAL_PATH_reocr) || true

.PHONY: clean-sync-reocr

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_reocr.mk)
