$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/aggregators_mediaagencies.mk)

VERIFY_EXTENSIONS ?= jsonl.bz2 json


# TARGET: aggregate-mediaagencies
#: Aggregate media-agency NER results and remove redundant NEL/model fields
aggregate-mediaagencies:
	$(PYTHON) cookbook/lib/s3_aggregator.py \
	  --jq-filter cookbook/lib/mediaagencies_aggregate.jq \
	  --s3-prefix $(S3_PATH_MEDIAAGENCIES:/$(NEWSPAPER)=) \
	  -o $(S3_PATH_MEDIAAGENCIES:/$(NEWSPAPER)=)__AGGREGATED.jsonl.gz


# TARGET: aggregate-mediaagencies-low-confidence
#: Aggregate only media-agency mentions with confidence_ner below 0.8
aggregate-mediaagencies-low-confidence:
	$(PYTHON) cookbook/lib/s3_aggregator.py \
	  --jq-filter cookbook/lib/mediaagencies_low_confidence_aggregate.jq \
	  --s3-prefix $(S3_PATH_MEDIAAGENCIES:/$(NEWSPAPER)=) \
	  -o $(S3_PATH_MEDIAAGENCIES:/$(NEWSPAPER)=)__AGGREGATED.confidence_ner_lt_0-8.jsonl.gz


# TARGET: aggregate-mediaagencies-mentions
#: Collect all media-agency mentions, one JSON object per mention
aggregate-mediaagencies-mentions:
	$(PYTHON) cookbook/lib/s3_aggregator.py \
	  --jq-filter cookbook/lib/mediaagencies_mentions.jq \
	  --s3-prefix $(S3_PATH_MEDIAAGENCIES:/$(NEWSPAPER)=) \
	  -o $(S3_PATH_MEDIAAGENCIES:/$(NEWSPAPER)=)__AGGREGATED.mentions.jsonl.gz


# TARGET: aggregate
#: Conventional cookbook aggregation entry point for media-agency outputs
aggregate: aggregate-mediaagencies


verify-data::
	@echo "Verifying data readability for $(S3_PATH_MEDIAAGENCIES:/$(NEWSPAPER)=)"
	$(PYTHON) cookbook/lib/s3_aggregator.py --verify \
	  --s3-prefix $(S3_PATH_MEDIAAGENCIES:/$(NEWSPAPER)=) \
	  $(if $(VERIFY_EXTENSIONS),--verify-file-extensions $(VERIFY_EXTENSIONS),)


verify-and-clean::
	@echo "Verifying and cleaning corrupted data for $(S3_PATH_MEDIAAGENCIES:/$(NEWSPAPER)=)"
	@echo "WARNING: This will DELETE corrupted files!"
	$(PYTHON) cookbook/lib/s3_aggregator.py --verify --verify-and-delete \
	  --s3-prefix $(S3_PATH_MEDIAAGENCIES:/$(NEWSPAPER)=) \
	  $(if $(VERIFY_EXTENSIONS),--verify-file-extensions $(VERIFY_EXTENSIONS),)


.PHONY: aggregate aggregate-mediaagencies aggregate-mediaagencies-low-confidence aggregate-mediaagencies-mentions


help-aggregation::
	@echo "MEDIA-AGENCIES AGGREGATION:"
	@echo "  aggregate-mediaagencies # Aggregate media-agency NER output and strip redundant fields"
	@echo "  aggregate-mediaagencies-low-confidence # Aggregate only mentions with confidence_ner < 0.8"
	@echo "  aggregate-mediaagencies-mentions # Collect all mentions, one JSON line each (ci_id, newspaper, date, type, label, wikidata_id, start, end, surface, confidence_ner)"
	@echo "  aggregate              # Conventional alias for aggregate-mediaagencies"
	@echo "  verify-data            # Verify that media-agency data files are readable"
	@echo "                         # Usage: make verify-data [VERIFY_EXTENSIONS='json jsonl.gz']"
	@echo "  verify-and-clean       # Verify data and DELETE corrupted files"
	@echo "                         # Usage: make verify-and-clean [VERIFY_EXTENSIONS='json jsonl.gz']"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/aggregators_mediaagencies.mk)
