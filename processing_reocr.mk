$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_reocr.mk)
###############################################################################
# reocr TARGETS
###############################################################################

sync-output :: sync-reocr
sync-input :: sync-reocr-input
processing-target :: reocr-target

LOCAL_REOCR_INPUT_STAMP_FILES := \
    $(shell ls $(REOCR_INPUT_FILE_GLOBS) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REOCR_INPUT_STAMP_FILES)

define LocalReocrInputToDoneFile
$(patsubst $(LOCAL_PATH_REOCR_INPUT)/%.jsonl.bz2,$(LOCAL_PATH_reocr_STAMPS)/%.done,$(1))
endef

LOCAL_reocr_DONE_FILES := \
    $(call LocalReocrInputToDoneFile,$(LOCAL_REOCR_INPUT_STAMP_FILES))
  $(call log.debug, LOCAL_reocr_DONE_FILES)

reocr-target: sync-reocr-input
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) reocr-files-target

.PHONY: reocr-target

help-processing::
	@echo ""
	@echo "RE-OCR PROCESSING TARGETS:"
	@echo "  reocr-target       # Sync input state, then process all missing re-OCR issue archives"
	@echo "  reocr-files-target # Process local re-OCR input stamps into page outputs and done markers"
	@echo "                     # Set REOCR_YEARS=1814 to process only selected canonical page years"

reocr-files-target: $(LOCAL_reocr_DONE_FILES)

.PHONY: reocr-files-target

$(LOCAL_PATH_reocr_STAMPS)/%.done: $(LOCAL_PATH_REOCR_INPUT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) $(dir $(LOCAL_PATH_reocr_LOGS)/$*.log.gz) $(LOCAL_PATH_reocr_WORK) && \
	$(PYTHON) lib/cli_reocr.py \
	  --input $(call LocalToS3,$<) \
	  --output-prefix $(S3_PATH_reocr) \
	  --work-root $(LOCAL_PATH_reocr_WORK) \
	  --done-marker $@ \
	  --tesseract-repo $(HF_TESSERACT_REPO_reocr) \
	  --tesseract-model $(HF_TESSERACT_MODEL_reocr) \
	  $(if $(TESSERACT_MODEL_URL_reocr),--tesseract-model-url $(TESSERACT_MODEL_URL_reocr)) \
	  $(if $(HF_FONT_REPO_reocr),--font-repo $(HF_FONT_REPO_reocr)) \
	  $(if $(HF_FONT_MODEL_reocr),--font-model $(HF_FONT_MODEL_reocr)) \
	  --run-id $(RUN_ID_reocr) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_LOGS)/$*.log.gz \
	    && \
	    $(PYTHON) -m impresso_cookbook.local_to_s3 \
	      $(LOCAL_PATH_reocr_LOGS)/$*.log.gz $(S3_PATH_reocr_LOGS)/$*.log.gz \
	      $@ $(S3_PATH_reocr_STAMPS)/$*.done \
	    || { rm -vf $@ ; exit 1 ; }

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_reocr.mk)
