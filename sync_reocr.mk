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
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_REOCR_INPUT) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

$(LOCAL_PATH_reocr_STAMPS).last_synced:
	mkdir -p $(@D) && \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_reocr_STAMPS) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

$(LOCAL_PATH_reocr_PAGES).last_synced:
	mkdir -p $(@D) && \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_reocr_PAGES) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

sync-reocr-input: $(LOCAL_REOCR_INPUT_SYNC_STAMP_FILE)

.PHONY: sync-reocr-input

help-sync::
	@echo ""
	@echo "RE-OCR INPUT SYNC:"
	@echo "  sync-reocr-input # Synchronize re-OCR input issue archives from S3 to local stamp files"

sync-reocr: $(LOCAL_reocr_SYNC_STAMP_FILE)

.PHONY: sync-reocr

help-sync::
	@echo ""
	@echo "RE-OCR OUTPUT STATE SYNC:"
	@echo "  sync-reocr       # Synchronize remote re-OCR done markers to local stamp files"

sync-reocr-pages: $(LOCAL_reocr_PAGES_SYNC_STAMP_FILE)

.PHONY: sync-reocr-pages

help-sync::
	@echo "  sync-reocr-pages # Synchronize remote re-OCR page outputs to local stamp files"

clean-sync:: clean-sync-reocr-input clean-sync-reocr-output

clean-sync-input:: clean-sync-reocr-input

clean-sync-output:: clean-sync-reocr-output

clean-sync-reocr-input:
	rm -vrf $(LOCAL_REOCR_INPUT_SYNC_STAMP_FILE) $(LOCAL_PATH_REOCR_INPUT) || true

clean-sync-reocr-output:
	rm -vrf $(LOCAL_reocr_SYNC_STAMP_FILE) $(LOCAL_reocr_PAGES_SYNC_STAMP_FILE) $(LOCAL_PATH_reocr) || true

.PHONY: clean-sync-reocr-input clean-sync-reocr-output

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_reocr.mk)
