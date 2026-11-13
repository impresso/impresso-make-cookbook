$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/aggregators_s3aggregation.mk)
###############################################################################
# S3 AGGREGATION RECIPES
# Targets for aggregating extracted/transformed s3aggregation outputs per newspaper
###############################################################################

# USER-VARIABLE: S3_PATH_AGGREGATED_s3aggregation
# Destination S3 path for newspaper aggregated output
S3_PATH_AGGREGATED_s3aggregation ?= s3://$(S3_BUCKET_s3aggregation)/$(PROCESS_LABEL_s3aggregation)/aggregated/$(NEWSPAPER).jsonl.gz
  $(call log.debug, S3_PATH_AGGREGATED_s3aggregation)

# USER-VARIABLE: AGGREGATE_KEYS_s3aggregation
# Keys to extract in the aggregated output (omitting redundant metadata)
AGGREGATE_KEYS_s3aggregation ?= target_person_id target_person_name target_wikidata_id target_name_form match_method article_id newspaper date language surface lOffset rOffset entity_type linked_wikidata_id confidence_ner confidence_nel confidence_ner_entity confidence_ner_type

# USER-VARIABLE: AGGREGATE_JQ_FILTER_s3aggregation
# Optional path to a jq filter file for aggregation transformations
AGGREGATE_JQ_FILTER_s3aggregation ?=

# TARGET: aggregate
#: Aggregate per-newspaper extracted mentions into a consolidated stream on S3
aggregate:
	$(PYTHON) cookbook/lib/s3_aggregator.py \
	  --s3-prefix $(S3_PATH_s3aggregation) \
	  $(if $(AGGREGATE_KEYS_s3aggregation),--keys $(AGGREGATE_KEYS_s3aggregation),) \
	  $(if $(AGGREGATE_JQ_FILTER_s3aggregation),--jq-filter $(AGGREGATE_JQ_FILTER_s3aggregation),) \
	  -o $(S3_PATH_AGGREGATED_s3aggregation)

.PHONY: aggregate

help-aggregation::
	@echo ""
	@echo "S3 AGGREGATION TARGETS:"
	@echo "  make aggregate NEWSPAPER=...       # Aggregate output files for a newspaper to S3"
	@echo "  make collection COLLECTION_TARGET=aggregate  # Aggregate all newspapers in parallel"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/aggregators_s3aggregation.mk)
