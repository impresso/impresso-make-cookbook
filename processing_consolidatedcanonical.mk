$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_consolidatedcanonical.mk)
###############################################################################
# consolidatedcanonical TARGETS
# Targets for processing newspaper content with language identification
# and OCR quality assessment consolidation
#
# This module consolidates canonical newspaper data with langident/OCRQA
# enrichments to produce consolidated canonical format with all
# consolidated_* properties as defined in issue.schema.json
#
# Input Requirements:
# - Canonical issues from s3://112-canonical-final/ (JSONL format)
# - Canonical pages from s3://112-canonical-final/ (JSONL format)
# - Langident/OCRQA enrichments from s3://115-canonical-processed-final/
# - Exact 1:1 correspondence between content items required
#
# Processing:
# - Issues: Renames lg → lg_original, adds consolidated_* fields
# - Pages: Copies from canonical to consolidated bucket (future: data mixing)
# - Sets consolidated=true and updates timestamps
#
# Output:
# - Consolidated canonical issues (JSONL format)
# - Consolidated canonical pages (JSONL format, copied)
###############################################################################

# USER-VARIABLE: CONSOLIDATEDCANONICAL_VALIDATE_OPTION
# Option to enable schema validation of the consolidated canonical output
#
# Set to --validate to enable JSON schema validation against issue.schema.json
# Set to empty value or $(EMPTY) to disable validation
CONSOLIDATEDCANONICAL_VALIDATE_OPTION ?= --validate
  $(call log.debug, CONSOLIDATEDCANONICAL_VALIDATE_OPTION)

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes consolidatedcanonical processing output data from S3 to local
# Downloads existing consolidated canonical files for resume/inspection
sync-output :: sync-consolidatedcanonical

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes canonical and langident enrichment input data for consolidation
sync-input :: sync-consolidatedcanonical-input

# DOUBLE-COLON-TARGET: processing-target
# Main processing target for consolidatedcanonical
processing-target :: consolidatedcanonical-target

# VARIABLE: LOCAL_CANONICAL_ISSUES_STAMP_FILES
# Stores all locally available canonical issue stamp files for dependency tracking
# Note: We sync canonical pages which include yearly stamps, but we need issue files
# Looks for stamp files matching the LOCAL_CANONICAL_STAMP_SUFFIX pattern
LOCAL_CANONICAL_ISSUES_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_CANONICAL_ISSUES)/*$(LOCAL_CANONICAL_STAMP_SUFFIX) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_CANONICAL_ISSUES_STAMP_FILES)

# VARIABLE: LOCAL_CANONICAL_PAGES_STAMP_FILES
# Stores all locally available canonical pages stamp files for dependency tracking
# These are yearly stamps (e.g., NEWSPAPER-YEAR or NEWSPAPER-YEAR.stamp) that track page sync status
LOCAL_CANONICAL_PAGES_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_CANONICAL_PAGES)/*$(LOCAL_CANONICAL_STAMP_SUFFIX) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_CANONICAL_PAGES_STAMP_FILES)

# VARIABLE: LOCAL_LANGIDENT_ENRICHMENT_STAMP_FILES
# Stores all locally available langident enrichment stamp files for dependency tracking
# Looks for .jsonl.bz2 files (actual enrichment stamp files from langident sync)
LOCAL_LANGIDENT_ENRICHMENT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_LANGIDENT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_LANGIDENT_ENRICHMENT_STAMP_FILES)

# FUNCTION: LocalCanonicalToConsolidatedFile
# Converts a local canonical stamp file to a consolidated output file name
# Input: build.d/112-canonical-final/CANONICAL_PATH_SEGMENT/pages/NEWSPAPER-YEAR or NEWSPAPER-YEAR.stamp
# Output: $(LOCAL_PATH_consolidatedcanonical)/issues/NEWSPAPER-YEAR-issues.jsonl.bz2
# Note: Handles stamps with or without extension based on LOCAL_CANONICAL_STAMP_SUFFIX
define LocalCanonicalToConsolidatedFile
$(patsubst $(LOCAL_PATH_CANONICAL_PAGES)/%$(LOCAL_CANONICAL_STAMP_SUFFIX),$(LOCAL_PATH_consolidatedcanonical)/issues/%-issues.jsonl.bz2,$(1))
endef

# FUNCTION: LocalCanonicalToEnrichmentFile
# Converts a local canonical stamp file to the corresponding enrichment file
# Input: build.d/112-canonical-final/CANONICAL_PATH_SEGMENT/pages/NEWSPAPER-YEAR or NEWSPAPER-YEAR.stamp
# Output: build.d/115-canonical-processed-final/langident/RUN_ID/CANONICAL_PATH_SEGMENT/NEWSPAPER-YEAR.jsonl.bz2
# Note: Handles stamps with or without extension, output is .jsonl.bz2 (the actual enrichment file)
define LocalCanonicalToEnrichmentFile
$(patsubst $(LOCAL_PATH_CANONICAL_PAGES)/%$(LOCAL_CANONICAL_STAMP_SUFFIX),$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2,$(1))
endef

# FUNCTION: LocalCanonicalPagesToConsolidatedStamp
# Converts a local canonical pages stamp file to a consolidated pages stamp file
# Input: build.d/112-canonical-final/CANONICAL_PATH_SEGMENT/pages/NEWSPAPER-YEAR or NEWSPAPER-YEAR.stamp
# Output: build.d/118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/pages/NEWSPAPER-YEAR.stamp
# Note: Output always uses .stamp extension for tracking consolidated pages sync status
define LocalCanonicalPagesToConsolidatedStamp
$(patsubst $(LOCAL_PATH_CANONICAL_PAGES)/%$(LOCAL_CANONICAL_STAMP_SUFFIX),$(LOCAL_PATH_consolidatedcanonical_PAGES)/%.stamp,$(1))
endef

# VARIABLE: LOCAL_consolidatedcanonical_FILES
# Stores the list of consolidated canonical issues files based on canonical stamp files
LOCAL_consolidatedcanonical_FILES := \
    $(call LocalCanonicalToConsolidatedFile,$(LOCAL_CANONICAL_ISSUES_STAMP_FILES))
  $(call log.info, LOCAL_consolidatedcanonical_FILES)

# VARIABLE: LOCAL_consolidatedcanonical_PAGES_STAMPS
# Stores the list of consolidated pages stamp files based on canonical pages stamps
# These track the copy/processing status of pages data
LOCAL_consolidatedcanonical_PAGES_STAMPS := \
    $(call LocalCanonicalPagesToConsolidatedStamp,$(LOCAL_CANONICAL_PAGES_STAMP_FILES))
  $(call log.info, LOCAL_consolidatedcanonical_PAGES_STAMPS)

# TARGET: consolidatedcanonical-target
#: Processes newspaper content with consolidated canonical format
#
# Merges canonical issues with langident/OCRQA enrichments and copies pages.
# Uses recursive make to ensure input data is synced before building file list.
# Depends on:
#   - sync-canonical: Syncs canonical pages data
#   - sync-langident: Syncs langident enrichment data for consolidation
consolidatedcanonical-target: sync-canonical sync-langident
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) consolidatedcanonical-files-target

.PHONY: consolidatedcanonical-target

# TARGET: consolidatedcanonical-files-target
#: Internal target that builds the actual consolidated files (issues and pages)
# Called recursively after sync to ensure stamp files are available
consolidatedcanonical-files-target: $(LOCAL_consolidatedcanonical_FILES) $(LOCAL_consolidatedcanonical_PAGES_STAMPS)

.PHONY: consolidatedcanonical-files-target

# FILE-RULE: $(LOCAL_PATH_consolidatedcanonical)/issues/%-issues.jsonl.bz2
#: Rule to process a single newspaper year
#
# Pattern matches consolidated canonical output files for the current newspaper.
# 
# Dependencies:
# - Canonical pages stamp (.stamp file from sync)
# - Langident enrichment file (.jsonl.bz2 file from langident processing)
#
# Processing:
# - Reads canonical issues from S3
# - Reads langident enrichments from S3  
# - Merges data with strict matching
# - Writes consolidated canonical output
# - Uploads to S3
$(LOCAL_PATH_consolidatedcanonical)/issues/%-issues.jsonl.bz2: \
    $(LOCAL_PATH_CANONICAL_PAGES)/%$(LOCAL_CANONICAL_STAMP_SUFFIX) \
    $(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
    python3 lib/cli_consolidatedcanonical.py \
      --canonical-input $(S3_PATH_CANONICAL_ISSUES)/$*-issues.jsonl.bz2 \
      --enrichment-input $(call LocalToS3,$(word 2,$^),'') \
      --output $@ \
      --langident-run-id $(LANGIDENT_ENRICHMENT_RUN_ID) \
      $(CONSOLIDATEDCANONICAL_VALIDATE_OPTION) \
      --log-level $(LOGGING_LEVEL) \
      --log-file $@.log.gz \
    && \
    python3 -m impresso_cookbook.local_to_s3 \
    --set-timestamp --log-level $(LOGGING_LEVEL) \
	  --keep-timestamp-only \
      $@        $(call LocalToS3,$@,'') \
      $@.log.gz $(call LocalToS3,$@,'').log.gz \
    || { rm -vf $@ ; exit 1; }

# FILE-RULE: $(LOCAL_PATH_consolidatedcanonical_PAGES)/%.stamp
#: Rule to process/copy pages data from canonical to consolidated bucket
#
# Pattern matches consolidated canonical pages stamps for the current newspaper.
# Currently performs a direct copy from canonical S3 to consolidated S3.
# Future versions may integrate additional data (e.g., ReOCR results).
# 
# Dependencies:
# - Canonical pages stamp (.stamp file from sync)
#
# Processing:
# - Copies all pages files for the year from canonical S3 to consolidated S3
# - Creates a stamp file to track completion
# - Preserves directory structure and file organization
$(LOCAL_PATH_consolidatedcanonical_PAGES)/%.stamp: \
    $(LOCAL_PATH_CANONICAL_PAGES)/%$(LOCAL_CANONICAL_STAMP_SUFFIX)
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	AWS_CONFIG_FILE=.aws/config AWS_SHARED_CREDENTIALS_FILE=.aws/credentials aws s3 cp \
		--recursive \
		--endpoint-url $(SE_HOST_URL) \
		$(S3_PATH_CANONICAL_PAGES)/$*/ \
		$(S3_PATH_consolidatedcanonical_PAGES)/$*/ \
	&& touch $@

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_consolidatedcanonical.mk)
