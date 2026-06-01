$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_reocr.mk)
###############################################################################
# reocr TARGETS
###############################################################################

sync-output :: sync-reocr sync-reocr-collected
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

LOCAL_reocr_COLLECTED_YEAR_FILES := \
    $(foreach dir,$(REOCR_COLLECT_YEAR_DIRS),$(LOCAL_PATH_reocr_COLLECTED_PAGES)/$(dir).jsonl.bz2)
  $(call log.debug, LOCAL_reocr_COLLECTED_YEAR_FILES)

LOCAL_reocr_COLLECTED_STATS_FILES := \
    $(foreach dir,$(REOCR_COLLECT_YEAR_DIRS),$(LOCAL_PATH_reocr_COLLECTED_STATS)/$(dir).stats.json)
  $(call log.debug, LOCAL_reocr_COLLECTED_STATS_FILES)

reocr-target: sync-reocr-input
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) reocr-files-target

.PHONY: reocr-target

help-processing::
	@echo ""
	@echo "RE-OCR PROCESSING TARGETS:"
	@echo "  reocr-target       # Sync input state, then process all missing re-OCR issue archives"
	@echo "  reocr-files-target # Process local re-OCR input stamps into page outputs and done markers"
	@echo "                     # Set REOCR_YEARS=1814 to process only selected canonical page years"
	@echo "  collect-reocr-year # Collect page-level re-OCR JSON into newspaper-year JSONL.bz2 files"
	@echo "                     # Set REOCR_COLLECT_YEARS=1814, or reuse REOCR_YEARS"
	@echo "  collect-reocr-stats # Report page integration counts without writing collected page archives"

reocr-files-target: $(LOCAL_reocr_DONE_FILES)

.PHONY: reocr-files-target

collect-reocr-year: sync-reocr-input
	@if [ -z "$(strip $(REOCR_COLLECT_YEAR_DIRS))" ]; then \
	  echo "ERROR: Set REOCR_COLLECT_YEARS or REOCR_YEARS before running collect-reocr-year"; \
	  exit 1; \
	fi
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) reocr-collect-files-target

.PHONY: collect-reocr-year

collect-reocr: collect-reocr-year

.PHONY: collect-reocr

reocr-collect-files-target: $(LOCAL_reocr_COLLECTED_YEAR_FILES)

.PHONY: reocr-collect-files-target

collect-reocr-stats: sync-reocr-input
	@if [ -z "$(strip $(REOCR_COLLECT_YEAR_DIRS))" ]; then \
	  echo "ERROR: Set REOCR_COLLECT_YEARS or REOCR_YEARS before running collect-reocr-stats"; \
	  exit 1; \
	fi
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) reocr-collect-stats-target

.PHONY: collect-reocr-stats

reocr-collect-stats-target: $(LOCAL_reocr_COLLECTED_STATS_FILES)

.PHONY: reocr-collect-stats-target

$(LOCAL_PATH_reocr_STAMPS)/%.done: $(LOCAL_PATH_REOCR_INPUT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) $(dir $(LOCAL_PATH_reocr_LOGS)/$*.log.gz) $(LOCAL_PATH_reocr_WORK) && \
	set +e; \
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
	  --sleep-after $(REOCR_SLEEP_AFTER) \
	  --fallback-confidence $(REOCR_FALLBACK_CONFIDENCE) \
	  --fallback-diff-ratio $(REOCR_FALLBACK_DIFF_RATIO) \
	  --skew-threshold $(REOCR_SKEW_THRESHOLD) \
	  --line-margin-extend $(REOCR_LINE_MARGIN_EXTEND) \
	  --vertical-margin-reduce $(REOCR_VERTICAL_MARGIN_REDUCE) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_NO_SKEW)),--no-skew) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_NO_PSM)),--no-psm) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_MASK_TOKENS)),--mask-tokens) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_DEBUG)),--debug) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_LOGS)/$*.log.gz ; \
	status=$$?; \
	set -e; \
	if [ $$status -eq 2 ]; then \
	  echo "No new re-OCR pages computed for $*; keeping local done marker and skipping log/done S3 sync"; \
	elif [ $$status -eq 0 ]; then \
	  $(PYTHON) -m impresso_cookbook.local_to_s3 \
	    $(LOCAL_PATH_reocr_LOGS)/$*.log.gz $(S3_PATH_reocr_LOGS)/$*.log.gz \
	    $@ $(S3_PATH_reocr_STAMPS)/$*.done ; \
	else \
	  rm -vf $@ ; \
	  exit $$status ; \
	fi

$(LOCAL_PATH_reocr_COLLECTED_PAGES)/%.jsonl.bz2: $(LOCAL_PATH_REOCR_INPUT)/%.last_synced
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) $(LOCAL_PATH_reocr_COLLECTED_STATS) $(LOCAL_PATH_reocr_COLLECTED_LOGS) $(LOCAL_PATH_reocr_COLLECTED_STAMPS) && \
	$(PYTHON) lib/cli_reocr_collect_year.py \
	  --canonical-input-prefix $(S3_PATH_REOCR_INPUT)/$* \
	  --reocr-prefix $(S3_PATH_reocr) \
	  --output $@ \
	  --stats-output $(LOCAL_PATH_reocr_COLLECTED_STATS)/$*.stats.json \
	  --done-marker $(LOCAL_PATH_reocr_COLLECTED_STAMPS)/$*.done \
	  --year-segment $* \
	  --run-id $(RUN_ID_reocr) \
	  --normalization-profile $(REOCR_NORMALIZATION_PROFILE) \
	  $(if $(filter 0 false FALSE no NO,$(REOCR_SYNTHESIZE_FALLBACK_LINES)),--no-synthesize-fallback-lines) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_COLLECTED_LOGS)/$*.log.gz \
	&& \
	$(PYTHON) -m impresso_cookbook.local_to_s3 \
	  --set-timestamp --log-level $(LOGGING_LEVEL) \
	  $@ $(S3_PATH_reocr_COLLECTED_PAGES)/$*.jsonl.bz2 \
	  $(LOCAL_PATH_reocr_COLLECTED_STATS)/$*.stats.json $(S3_PATH_reocr_COLLECTED_STATS)/$*.stats.json \
	  $(LOCAL_PATH_reocr_COLLECTED_LOGS)/$*.log.gz $(S3_PATH_reocr_COLLECTED_LOGS)/$*.log.gz \
	  $(LOCAL_PATH_reocr_COLLECTED_STAMPS)/$*.done $(S3_PATH_reocr_COLLECTED_STAMPS)/$*.done \
	|| { rm -vf $@ $(LOCAL_PATH_reocr_COLLECTED_STATS)/$*.stats.json $(LOCAL_PATH_reocr_COLLECTED_STAMPS)/$*.done ; exit 1; }

$(LOCAL_PATH_reocr_COLLECTED_STATS)/%.stats.json: $(LOCAL_PATH_REOCR_INPUT)/%.last_synced
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) $(LOCAL_PATH_reocr_COLLECTED_LOGS) && \
	$(PYTHON) lib/cli_reocr_collect_year.py \
	  --canonical-input-prefix $(S3_PATH_REOCR_INPUT)/$* \
	  --reocr-prefix $(S3_PATH_reocr) \
	  --stats-only \
	  --stats-output $@ \
	  --year-segment $* \
	  --run-id $(RUN_ID_reocr) \
	  --normalization-profile $(REOCR_NORMALIZATION_PROFILE) \
	  $(if $(filter 0 false FALSE no NO,$(REOCR_SYNTHESIZE_FALLBACK_LINES)),--no-synthesize-fallback-lines) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_COLLECTED_LOGS)/$*.stats.log.gz \
	&& \
	$(PYTHON) -m impresso_cookbook.local_to_s3 \
	  --set-timestamp --log-level $(LOGGING_LEVEL) \
	  $@ $(S3_PATH_reocr_COLLECTED_STATS)/$*.stats.json \
	  $(LOCAL_PATH_reocr_COLLECTED_LOGS)/$*.stats.log.gz $(S3_PATH_reocr_COLLECTED_LOGS)/$*.stats.log.gz \
	|| { rm -vf $@ ; exit 1; }

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_reocr.mk)
