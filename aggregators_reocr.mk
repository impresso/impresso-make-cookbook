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

REOCR_AGGREGATE_INCLUDE_DONE_MARKERS ?= 0
  $(call log.debug, REOCR_AGGREGATE_INCLUDE_DONE_MARKERS)

REOCR_SAMPLE_PAGES ?= 500
  $(call log.debug, REOCR_SAMPLE_PAGES)

REOCR_SAMPLE_LINES_PER_PAGE ?= 4
  $(call log.debug, REOCR_SAMPLE_LINES_PER_PAGE)

REOCR_SAMPLE_SEED ?= 13
  $(call log.debug, REOCR_SAMPLE_SEED)

REOCR_SAMPLE_LOW_CONFIDENCE ?= 50
  $(call log.debug, REOCR_SAMPLE_LOW_CONFIDENCE)

REOCR_SAMPLE_HIGH_CONFIDENCE ?= 90
  $(call log.debug, REOCR_SAMPLE_HIGH_CONFIDENCE)

REOCR_SAMPLE_PREFIX ?= $(S3_PATH_reocr_RUN_ROOT)
  $(call log.debug, REOCR_SAMPLE_PREFIX)

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
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_AGGREGATE_INCLUDE_DONE_MARKERS)),--include-done-markers,--skip-done-markers) \
	  --progress-every $(REOCR_AGGREGATE_PROGRESS_EVERY) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_AGGREGATED)/stats.log.gz \
	&& \
	$(PYTHON) -m impresso_cookbook.local_to_s3 \
	  --set-timestamp --log-level $(LOGGING_LEVEL) \
	  $(LOCAL_PATH_reocr_AGGREGATED)/stats.jsonl.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_stats.jsonl.gz \
	  $(LOCAL_PATH_reocr_AGGREGATED)/stats.log.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_stats.log.gz

# TARGET: sample-reocr-lines
#: Sample line-level re-OCR examples from page JSON outputs on S3.
sample-reocr-lines:
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(LOCAL_PATH_reocr_AGGREGATED) && \
	$(PYTHON) lib/sample_reocr_lines.py \
	  --s3-prefix $(REOCR_SAMPLE_PREFIX) \
	  --output $(LOCAL_PATH_reocr_AGGREGATED)/line-sample.jsonl.gz \
	  --pages $(REOCR_SAMPLE_PAGES) \
	  --lines-per-page $(REOCR_SAMPLE_LINES_PER_PAGE) \
	  --low-confidence $(REOCR_SAMPLE_LOW_CONFIDENCE) \
	  --high-confidence $(REOCR_SAMPLE_HIGH_CONFIDENCE) \
	  --seed $(REOCR_SAMPLE_SEED) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_AGGREGATED)/line-sample.log.gz \
	&& \
	$(PYTHON) -m impresso_cookbook.local_to_s3 \
	  --set-timestamp --log-level $(LOGGING_LEVEL) \
	  $(LOCAL_PATH_reocr_AGGREGATED)/line-sample.jsonl.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_line-sample.jsonl.gz \
	  $(LOCAL_PATH_reocr_AGGREGATED)/line-sample.log.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_line-sample.log.gz

# TARGET: aggregate
#: Conventional cookbook aggregation entry point for re-OCR outputs.
aggregate: aggregate-reocr-stats

.PHONY: aggregate aggregate-reocr-stats sample-reocr-lines

help-aggregation::
	@echo "RE-OCR AGGREGATION:"
	@echo "  aggregate-reocr-stats # Traverse existing re-OCR S3 page JSON outputs and aggregate page coverage"
	@echo "                        # Set REOCR_AGGREGATE_NEWSPAPER=SNL/FZG or REOCR_AGGREGATE_YEARS='1865 1866' to filter"
	@echo "                        # Page JSON coverage is the default; set REOCR_AGGREGATE_INCLUDE_DONE_MARKERS=1 to also scan stamps"
	@echo "  sample-reocr-lines # Randomly sample line-level high/low confidence re-OCR examples"
	@echo "                     # Defaults: REOCR_SAMPLE_PAGES=500 REOCR_SAMPLE_LINES_PER_PAGE=4"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/aggregators_reocr.mk)
