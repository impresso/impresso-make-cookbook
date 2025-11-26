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
# - Canonical issues from s3://12-canonical-final/ (JSONL format)
# - Langident/OCRQA enrichments from s3://115-canonical-processed-final/
# - Exact 1:1 correspondence between content items required
#
# Processing:
# - Renames lg → lg_original
# - Adds consolidated_lg, consolidated_ocrqa, consolidated_langident_run_id
# - Sets consolidated=true and updates timestamps
#
# Output:
# - Consolidated canonical issues (JSONL format)
###############################################################################

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
# Looks for stamp files with .stamp extension (legacy)
LOCAL_CANONICAL_ISSUES_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_CANONICAL_PAGES)/*.stamp 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_CANONICAL_ISSUES_STAMP_FILES)


# VARIABLE: LOCAL_LANGIDENT_ENRICHMENT_STAMP_FILES
# Stores all locally available langident enrichment stamp files for dependency tracking
# Looks for .jsonl.bz2 files (actual enrichment stamp files from langident sync)
LOCAL_LANGIDENT_ENRICHMENT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_LANGIDENT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_LANGIDENT_ENRICHMENT_STAMP_FILES)


# FUNCTION: LocalCanonicalToConsolidatedFile
# Converts a local canonical stamp file to a consolidated output file name
# Input: build.d/112-canonical-final/CANONICAL_PATH_SEGMENT/pages/NEWSPAPER-YEAR.stamp
# Output: build.d/118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/issues/NEWSPAPER-YEAR-issues.jsonl.bz2
# Note: Handles .stamp suffix in input files (legacy from sync) but removes it in output
define LocalCanonicalToConsolidatedFile
$(patsubst $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp,$(LOCAL_PATH_consolidatedcanonical)/issues/%-issues.jsonl.bz2,$(1))
endef


# FUNCTION: LocalCanonicalToEnrichmentFile
# Converts a local canonical stamp file to the corresponding enrichment file
# Input: build.d/112-canonical-final/CANONICAL_PATH_SEGMENT/pages/NEWSPAPER-YEAR.stamp
# Output: build.d/115-canonical-processed-final/langident/RUN_ID/CANONICAL_PATH_SEGMENT/NEWSPAPER-YEAR.jsonl.bz2
# Note: Input has .stamp, output is .jsonl.bz2 (the actual enrichment file)
define LocalCanonicalToEnrichmentFile
$(patsubst $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp,$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2,$(1))
endef


# VARIABLE: LOCAL_consolidatedcanonical_FILES
# Stores the list of consolidated canonical files based on canonical stamp files
LOCAL_consolidatedcanonical_FILES := \
    $(call LocalCanonicalToConsolidatedFile,$(LOCAL_CANONICAL_ISSUES_STAMP_FILES))

  $(call log.debug, LOCAL_consolidatedcanonical_FILES)

# TARGET: consolidatedcanonical-target
#: Processes newspaper content with consolidated canonical format
#
# Merges canonical issues with langident/OCRQA enrichments.
# Uses recursive make to ensure input data is synced before building file list.
# Depends on:
#   - sync-canonical: Syncs canonical pages data
#   - sync-langident: Syncs langident enrichment data for consolidation
consolidatedcanonical-target: sync-canonical sync-langident
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) consolidatedcanonical-files-target

.PHONY: consolidatedcanonical-target

# TARGET: consolidatedcanonical-files-target
#: Internal target that builds the actual consolidated files
# Called recursively after sync to ensure stamp files are available
consolidatedcanonical-files-target: $(LOCAL_consolidatedcanonical_FILES)

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
    $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp \
    $(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
    python3 lib/cli_consolidatedcanonical.py \
      --canonical-input $(S3_PATH_CANONICAL_ISSUES)/$*-issues.jsonl.bz2 \
      --enrichment-input $(call LocalToS3,$(word 2,$^),'') \
      --output $@ \
      --langident-run-id $(LANGIDENT_ENRICHMENT_RUN_ID) \
      --log-level $(LOGGING_LEVEL) \
      --log-file $@.log.gz \
    && \
    python3 -m impresso_cookbook.local_to_s3 \
    		--set-timestamp --log-level $(LOGGING_LEVEL) \
        --keep-timestamp-only \
      $@        $(call LocalToS3,$@,'') \
      $@.log.gz $(call LocalToS3,$@,'').log.gz \
    || { rm -vf $@ ; exit 1; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_consolidatedcanonical.mk)
