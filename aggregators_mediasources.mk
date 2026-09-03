$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/aggregators_mediasources.mk)

VERIFY_EXTENSIONS ?= jsonl.bz2 json


# TARGET: aggregate-mediasources
#: Aggregate media-source NER results and remove redundant NEL/model fields
aggregate-mediasources:
	$(PYTHON) cookbook/lib/s3_aggregator.py \
	  --jq-filter cookbook/lib/mediasources_aggregate.jq \
	  --s3-prefix $(S3_PATH_MEDIASOURCES:/$(NEWSPAPER)=) \
	  -o $(S3_PATH_MEDIASOURCES:/$(NEWSPAPER)=)__AGGREGATED.jsonl.gz


# TARGET: aggregate-mediasources-low-confidence
#: Aggregate only media-source mentions with confidence_ner below 0.8
aggregate-mediasources-low-confidence:
	$(PYTHON) cookbook/lib/s3_aggregator.py \
	  --jq-filter cookbook/lib/mediasources_low_confidence_aggregate.jq \
	  --s3-prefix $(S3_PATH_MEDIASOURCES:/$(NEWSPAPER)=) \
	  -o $(S3_PATH_MEDIASOURCES:/$(NEWSPAPER)=)__AGGREGATED.confidence_ner_lt_0-8.jsonl.gz


# TARGET: aggregate
#: Conventional cookbook aggregation entry point for media-source outputs
aggregate: aggregate-mediasources


verify-data::
	@echo "Verifying data readability for $(S3_PATH_MEDIASOURCES:/$(NEWSPAPER)=)"
	$(PYTHON) cookbook/lib/s3_aggregator.py --verify \
	  --s3-prefix $(S3_PATH_MEDIASOURCES:/$(NEWSPAPER)=) \
	  $(if $(VERIFY_EXTENSIONS),--verify-file-extensions $(VERIFY_EXTENSIONS),)


verify-and-clean::
	@echo "Verifying and cleaning corrupted data for $(S3_PATH_MEDIASOURCES:/$(NEWSPAPER)=)"
	@echo "WARNING: This will DELETE corrupted files!"
	$(PYTHON) cookbook/lib/s3_aggregator.py --verify --verify-and-delete \
	  --s3-prefix $(S3_PATH_MEDIASOURCES:/$(NEWSPAPER)=) \
	  $(if $(VERIFY_EXTENSIONS),--verify-file-extensions $(VERIFY_EXTENSIONS),)


.PHONY: aggregate aggregate-mediasources aggregate-mediasources-low-confidence


help-aggregation::
	@echo "MEDIA-SOURCES AGGREGATION:"
	@echo "  aggregate-mediasources # Aggregate media-source NER output and strip redundant fields"
	@echo "  aggregate-mediasources-low-confidence # Aggregate only mentions with confidence_ner < 0.8"
	@echo "  aggregate              # Conventional alias for aggregate-mediasources"
	@echo "  verify-data            # Verify that media-source data files are readable"
	@echo "                         # Usage: make verify-data [VERIFY_EXTENSIONS='json jsonl.gz']"
	@echo "  verify-and-clean       # Verify data and DELETE corrupted files"
	@echo "                         # Usage: make verify-and-clean [VERIFY_EXTENSIONS='json jsonl.gz']"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/aggregators_mediasources.mk)
