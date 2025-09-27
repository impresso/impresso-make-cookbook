$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/aggregators_lingproc.mk)
###############################################################################
# LINGUISTIC PROCESSING TOKEN AGGREGATORS
# Targets for extracting and aggregating tokens from linguistic processing data
#
# This module provides parallel token extraction from S3-stored linguistic
# processing data, organized by newspaper and language. Supports resumable
# processing with S3 existence checks and local-first workflow with stampification.
# 
# The extraction process reads linguistic processing JSON files from S3, applies
# jq filters to extract tokens for specific languages, and stores results in a
# component bucket with proper versioning and organization.
###############################################################################


# USER-VARIABLE: S3_BUCKET_LINGPROC_COMPONENT
# Component bucket for storing aggregated linguistic processing results
#
# Specifies the S3 bucket where token aggregation results are stored,
# separate from the main linguistic processing data bucket. This separation
# allows for better organization and access control of derived data products.
S3_BUCKET_LINGPROC_COMPONENT ?= 130-component-sandbox
  $(call log.debug, S3_BUCKET_LINGPROC_COMPONENT)


# VARIABLE: ALL_NEWSPAPERS
# List all available newspapers for parallel processing using newspaper list definitions
#
# Reads the canonical list of newspaper identifiers using make's file function
# and newspaper_list.mk definitions to determine which newspapers should be processed.
ALL_NEWSPAPERS := $(file < build.d/newspapers.txt)


# VARIABLE: S3_TOKENS_BASE_PATH
# Base S3 path for storing token files in component bucket
#
# Constructs the S3 path using the component bucket and run ID to ensure
# proper versioning and organization of extracted token files. The path structure
# follows the pattern: s3://bucket/tokens/run-id/language/newspaper_tokens.txt.gz
S3_TOKENS_BASE_PATH := s3://$(S3_BUCKET_LINGPROC_COMPONENT)/tokens/$(RUN_ID_LINGPROC)
  $(call log.debug, S3_TOKENS_BASE_PATH)


# VARIABLE: LOCAL_TOKENS_BASE_PATH
# Local path for storing token files (mirrors S3 structure)
#
# Defines the local build directory path that mirrors the S3 structure
# for temporary storage before upload and stampification. Files are processed
# locally first for reliability and then uploaded with verification.
LOCAL_TOKENS_BASE_PATH := $(BUILD_DIR)/$(S3_BUCKET_LINGPROC_COMPONENT)/tokens/$(RUN_ID_LINGPROC)
  $(call log.debug, LOCAL_TOKENS_BASE_PATH)


# PATTERN-RULE: extract-tokens-%-de
#: Extract German tokens for a specific newspaper
#
# Processes all linguistic processing files for a newspaper to extract German
# tokens using jq filters. The process includes S3 existence checking for
# resumability, local processing with logging, and upload with stampification.
# Skips processing if output already exists on S3 to enable parallel execution.
extract-tokens-%-de:
	@mkdir -p $(LOCAL_TOKENS_BASE_PATH)/de
	@if python3 -m impresso_cookbook.local_to_s3 --s3-file-exists $(S3_TOKENS_BASE_PATH)/de/$*_de_tokens.txt.gz --wip --wip-max-age 2 --create-wip $(LOCAL_TOKENS_BASE_PATH)/de/$*_de_tokens.txt.gz $(S3_TOKENS_BASE_PATH)/de/$*_de_tokens.txt.gz $(LOCAL_TOKENS_BASE_PATH)/de/$*_de_tokens.log.gz $(S3_TOKENS_BASE_PATH)/de/$*_de_tokens.log.gz ; then \
		echo "File already exists or WIP in progress, skipping processing for $*_de_tokens.txt.gz"; \
	else \
		LANGUAGE=de python cookbook/lib/s3_aggregator.py --jq-filter lib/extract_tokens.jq \
		--s3-prefix s3://$(PATH_LINGPROC_BASE)/$* \
		-o $(LOCAL_TOKENS_BASE_PATH)/de/$*_de_tokens.txt.gz \
		--log-file $(LOCAL_TOKENS_BASE_PATH)/de/$*_de_tokens.log.gz && \
		python3 -m impresso_cookbook.local_to_s3 \
		--keep-timestamp-only \
		--set-timestamp \
		--ts-key __file__ \
		--remove-wip \
		$(LOCAL_TOKENS_BASE_PATH)/de/$*_de_tokens.txt.gz $(S3_TOKENS_BASE_PATH)/de/$*_de_tokens.txt.gz \
		$(LOCAL_TOKENS_BASE_PATH)/de/$*_de_tokens.log.gz $(S3_TOKENS_BASE_PATH)/de/$*_de_tokens.log.gz; \
	fi


# PATTERN-RULE: extract-tokens-%-fr
#: Extract French tokens for a specific newspaper
#
# Processes all linguistic processing files for a newspaper to extract French
# tokens using jq filters. The process includes S3 existence checking for
# resumability, local processing with logging, and upload with stampification.
# Skips processing if output already exists on S3 to enable parallel execution.
extract-tokens-%-fr:
	@mkdir -p $(LOCAL_TOKENS_BASE_PATH)/fr
	@if python3 -m impresso_cookbook.local_to_s3 --s3-file-exists $(S3_TOKENS_BASE_PATH)/fr/$*_fr_tokens.txt.gz --wip --wip-max-age 2 --create-wip $(LOCAL_TOKENS_BASE_PATH)/fr/$*_fr_tokens.txt.gz $(S3_TOKENS_BASE_PATH)/fr/$*_fr_tokens.txt.gz $(LOCAL_TOKENS_BASE_PATH)/fr/$*_fr_tokens.log.gz $(S3_TOKENS_BASE_PATH)/fr/$*_fr_tokens.log.gz ; then \
		echo "File already exists or WIP in progress, skipping processing for $*_fr_tokens.txt.gz"; \
	else \
		LANGUAGE=fr python cookbook/lib/s3_aggregator.py --jq-filter lib/extract_tokens.jq \
		--s3-prefix s3://$(PATH_LINGPROC_BASE)/$* \
		-o $(LOCAL_TOKENS_BASE_PATH)/fr/$*_fr_tokens.txt.gz \
		--log-file $(LOCAL_TOKENS_BASE_PATH)/fr/$*_fr_tokens.log.gz && \
		python3 -m impresso_cookbook.local_to_s3 \
		--keep-timestamp-only \
		--set-timestamp \
		--ts-key __file__ \
		--remove-wip \
		$(LOCAL_TOKENS_BASE_PATH)/fr/$*_fr_tokens.txt.gz $(S3_TOKENS_BASE_PATH)/fr/$*_fr_tokens.txt.gz \
		$(LOCAL_TOKENS_BASE_PATH)/fr/$*_fr_tokens.log.gz $(S3_TOKENS_BASE_PATH)/fr/$*_fr_tokens.log.gz; \
	fi


# PATTERN-RULE: extract-tokens-%-en
#: Extract English tokens for a specific newspaper
#
# Processes all linguistic processing files for a newspaper to extract English
# tokens using jq filters. The process includes S3 existence checking for
# resumability, local processing with logging, and upload with stampification.
# Skips processing if output already exists on S3 to enable parallel execution.
extract-tokens-%-en:
	@mkdir -p $(LOCAL_TOKENS_BASE_PATH)/en
	@if python3 -m impresso_cookbook.local_to_s3 --s3-file-exists $(S3_TOKENS_BASE_PATH)/en/$*_en_tokens.txt.gz --wip --wip-max-age 2 --create-wip $(LOCAL_TOKENS_BASE_PATH)/en/$*_en_tokens.txt.gz $(S3_TOKENS_BASE_PATH)/en/$*_en_tokens.txt.gz $(LOCAL_TOKENS_BASE_PATH)/en/$*_en_tokens.log.gz $(S3_TOKENS_BASE_PATH)/en/$*_en_tokens.log.gz ; then \
		echo "File already exists or WIP in progress, skipping processing for $*_en_tokens.txt.gz"; \
	else \
		LANGUAGE=en python cookbook/lib/s3_aggregator.py --jq-filter lib/extract_tokens.jq \
		--s3-prefix s3://$(PATH_LINGPROC_BASE)/$* \
		-o $(LOCAL_TOKENS_BASE_PATH)/en/$*_en_tokens.txt.gz \
		--log-file $(LOCAL_TOKENS_BASE_PATH)/en/$*_en_tokens.log.gz && \
		python3 -m impresso_cookbook.local_to_s3 \
		--keep-timestamp-only \
		--set-timestamp \
		--ts-key __file__ \
		--remove-wip \
		$(LOCAL_TOKENS_BASE_PATH)/en/$*_en_tokens.txt.gz $(S3_TOKENS_BASE_PATH)/en/$*_en_tokens.txt.gz \
		$(LOCAL_TOKENS_BASE_PATH)/en/$*_en_tokens.log.gz $(S3_TOKENS_BASE_PATH)/en/$*_en_tokens.log.gz; \
	fi


# PATTERN-RULE: aggregate-tokens-%
#: Combine all newspaper token files for a specific language into corpus file
#
# Aggregates individual newspaper token files for a language into a single
# consolidated file for corpus-wide analysis and distribution. Reads from S3,
# filters by language-specific filename patterns, and creates unified output
# with comprehensive logging for data provenance tracking.
aggregate-tokens-%:
	@mkdir -p $(LOCAL_TOKENS_BASE_PATH)
	python cookbook/lib/s3_aggregator.py --s3-prefix $(S3_TOKENS_BASE_PATH) \
	--filter filename=*_$*_tokens.txt.gz \
	--keys content \
	-o $(LOCAL_TOKENS_BASE_PATH)/ALL_$*_tokens.txt.gz \
	--log-file $(LOCAL_TOKENS_BASE_PATH)/ALL_$*_tokens.log.gz
	python3 -m impresso_cookbook.local_to_s3 \
	--keep-timestamp-only \
	--set-timestamp \
	--ts-key __file__ \
	$(LOCAL_TOKENS_BASE_PATH)/ALL_$*_tokens.txt.gz $(S3_TOKENS_BASE_PATH)/ALL_$*_tokens.txt.gz \
	$(LOCAL_TOKENS_BASE_PATH)/ALL_$*_tokens.log.gz $(S3_TOKENS_BASE_PATH)/ALL_$*_tokens.log.gz


# TARGET: extract-tokens-de
#: Extract German tokens for all newspapers in parallel
#
# Processes all newspapers concurrently using make's parallel job execution.
# Each newspaper extraction runs independently, allowing for efficient resource
# utilization. Use with -j flag to control parallelism: make extract-tokens-de -j4
extract-tokens-de: $(foreach newspaper,$(ALL_NEWSPAPERS),extract-tokens-$(newspaper)-de)


# TARGET: extract-tokens-fr
#: Extract French tokens for all newspapers in parallel
#
# Processes all newspapers concurrently using make's parallel job execution.
# Each newspaper extraction runs independently, allowing for efficient resource
# utilization. Use with -j flag to control parallelism: make extract-tokens-fr -j4
extract-tokens-fr: $(foreach newspaper,$(ALL_NEWSPAPERS),extract-tokens-$(newspaper)-fr)


# TARGET: extract-tokens-en
#: Extract English tokens for all newspapers in parallel
#
# Processes all newspapers concurrently using make's parallel job execution.
# Each newspaper extraction runs independently, allowing for efficient resource
# utilization. Use with -j flag to control parallelism: make extract-tokens-en -j4
extract-tokens-en: $(foreach newspaper,$(ALL_NEWSPAPERS),extract-tokens-$(newspaper)-en)


# TARGET: extract-all-tokens
#: Extract tokens for all newspapers and all supported languages
#
# Comprehensive token extraction across all supported languages and newspapers.
# Runs sequentially by language but newspapers within each language run in parallel.
# This is the main entry point for complete corpus token extraction workflows.
extract-all-tokens: extract-tokens-de extract-tokens-fr extract-tokens-en


# TARGET: list-newspapers
#: Display all available newspapers for token extraction processing
#
# Shows the complete list of newspaper identifiers that will be processed for
# token extraction. Useful for verification and debugging of newspaper coverage
# before starting large-scale extraction operations.
list-newspapers:
	@echo "Available newspapers: $(ALL_NEWSPAPERS)"


# TARGET: extract-tokens
#: Extract German tokens for all newspapers (backward compatibility)
#
# Default target that extracts German tokens for all newspapers.
# Maintains compatibility with existing workflows that expect German
# as the default language for token extraction operations.
extract-tokens: extract-tokens-de


.PHONY: extract-tokens-de extract-tokens-fr extract-tokens-en extract-all-tokens
.PHONY: aggregate-tokens-de aggregate-tokens-fr aggregate-tokens-en
.PHONY: list-newspapers extract-tokens


$(call log.debug, COOKBOOK END INCLUDE: cookbook/aggregators_lingproc.mk)
# Default target that extracts German tokens for all newspapers.
# Maintains compatibility with existing workflows that expect German
# as the default language for token extraction operations.
extract-tokens: extract-tokens-de


.PHONY: extract-tokens-de extract-tokens-fr extract-tokens-en extract-all-tokens
.PHONY: aggregate-tokens-de aggregate-tokens-fr aggregate-tokens-en
.PHONY: list-newspapers extract-tokens


$(call log.debug, COOKBOOK END INCLUDE: cookbook/aggregators_lingproc.mk)
extract-tokens: extract-tokens-de


.PHONY: extract-tokens-de extract-tokens-fr extract-tokens-en extract-all-tokens
.PHONY: aggregate-tokens-de aggregate-tokens-fr aggregate-tokens-en
.PHONY: list-newspapers extract-tokens


$(call log.debug, COOKBOOK END INCLUDE: cookbook/aggregators_lingproc.mk)
