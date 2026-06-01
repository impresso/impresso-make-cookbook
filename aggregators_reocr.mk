$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/aggregators_reocr.mk)
###############################################################################
# RE-OCR AGGREGATORS
# Run-level summaries from existing re-OCR S3 outputs.
###############################################################################

S3_PATH_reocr_RUN_ROOT := s3://$(S3_BUCKET_reocr)/$(PROCESS_LABEL_reocr)$(PROCESS_SUBTYPE_LABEL_reocr)/$(RUN_ID_reocr)
  $(call log.debug, S3_PATH_reocr_RUN_ROOT)

S3_PATH_reocr_AGGREGATED_PREFIX ?= $(S3_PATH_reocr_RUN_ROOT)__AGGREGATED
  $(call log.debug, S3_PATH_reocr_AGGREGATED_PREFIX)

LOCAL_PATH_reocr_AGGREGATED := $(BUILD_DIR)/$(S3_BUCKET_reocr)/$(PROCESS_LABEL_reocr)$(PROCESS_SUBTYPE_LABEL_reocr)/$(RUN_ID_reocr)__AGGREGATED
  $(call log.debug, LOCAL_PATH_reocr_AGGREGATED)

REOCR_AGGREGATE_YEARS ?= $(REOCR_YEARS)
  $(call log.debug, REOCR_AGGREGATE_YEARS)

REOCR_AGGREGATE_NEWSPAPER ?=
  $(call log.debug, REOCR_AGGREGATE_NEWSPAPER)

REOCR_AGGREGATE_PROGRESS_EVERY ?= 10000
  $(call log.debug, REOCR_AGGREGATE_PROGRESS_EVERY)

REOCR_AGGREGATE_SKIP_DONE_MARKERS ?= 0
  $(call log.debug, REOCR_AGGREGATE_SKIP_DONE_MARKERS)

# TARGET: aggregate-reocr-stats
#: Traverse existing re-OCR output on S3 and aggregate run coverage statistics.
aggregate-reocr-stats:
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(LOCAL_PATH_reocr_AGGREGATED) && \
	$(PYTHON) lib/aggregate_reocr_s3_stats.py \
	  --s3-prefix $(S3_PATH_reocr_RUN_ROOT) \
	  --output $(LOCAL_PATH_reocr_AGGREGATED)/stats.jsonl.gz \
	  --run-id $(RUN_ID_reocr) \
	  $(if $(REOCR_AGGREGATE_NEWSPAPER),--newspaper $(REOCR_AGGREGATE_NEWSPAPER)) \
	  $(if $(REOCR_AGGREGATE_YEARS),--years $(REOCR_AGGREGATE_YEARS)) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_AGGREGATE_SKIP_DONE_MARKERS)),--skip-done-markers) \
	  --progress-every $(REOCR_AGGREGATE_PROGRESS_EVERY) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_AGGREGATED)/stats.log.gz \
	&& \
	$(PYTHON) -m impresso_cookbook.local_to_s3 \
	  --set-timestamp --log-level $(LOGGING_LEVEL) \
	  $(LOCAL_PATH_reocr_AGGREGATED)/stats.jsonl.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_stats.jsonl.gz \
	  $(LOCAL_PATH_reocr_AGGREGATED)/stats.log.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_stats.log.gz

# TARGET: aggregate
#: Conventional cookbook aggregation entry point for re-OCR outputs.
aggregate: aggregate-reocr-stats

.PHONY: aggregate aggregate-reocr-stats

help-aggregation::
	@echo "RE-OCR AGGREGATION:"
	@echo "  aggregate-reocr-stats # Traverse existing re-OCR S3 outputs and aggregate page/done-marker counts"
	@echo "                        # Set REOCR_AGGREGATE_NEWSPAPER=SNL/FZG or REOCR_AGGREGATE_YEARS='1865 1866' to filter"
	@echo "                        # Set REOCR_AGGREGATE_SKIP_DONE_MARKERS=1 for a faster page-JSON-only scan"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/aggregators_reocr.mk)
