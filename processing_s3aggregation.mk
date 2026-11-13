$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_s3aggregation.mk)
###############################################################################
# s3aggregation TARGETS
# Targets for processing newspaper content with OCR quality assessment
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes s3aggregation processing output data
sync-output :: sync-s3aggregation

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes s3aggregation processing input data
# @TODO: This needs to be updated to s3aggregation processing
sync-input :: sync-rebuilt 

# DOUBLE-COLON-TARGET: s3aggregation-target
processing-target :: s3aggregation-target


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
# Rebuilt stamps match S3 file names exactly (no suffix)
LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltTos3aggregationFile
# Converts a local rebuilt stamp file name to a local s3aggregation file name
# Rebuilt stamps match S3 file names exactly (no suffix)
define LocalRebuiltTos3aggregationFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_s3aggregation)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_s3aggregation_FILES
# Stores the list of OCR quality assessment files based on rebuilt stamp files
LOCAL_s3aggregation_FILES := \
    $(call LocalRebuiltTos3aggregationFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_s3aggregation_FILES)

# TARGET: s3aggregation-target
#: Processes newspaper content with OCR quality assessment
#
# Just uses the local data that is there, does not enforce synchronization
s3aggregation-target: $(LOCAL_s3aggregation_FILES)

.PHONY: s3aggregation-target

# FILE-RULE: $(LOCAL_PATH_s3aggregation)/%.jsonl.bz2
#: Rule to process a single newspaper
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
$(LOCAL_PATH_s3aggregation)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
    python3 lib/cli_s3aggregation.py \
      --input $(call LocalToS3,$<) \
      --output $@ \
      --log-file $@.log.gz \
      $(CLI_EXTRA_ARGS) \
    && \
    python3 -m impresso_cookbook.local_to_s3 \
      $@        $(call LocalToS3,$@) \
      $@.log.gz $(call LocalToS3,$@).log.gz \
    || { rm -vf $@ ; exit 1 ; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_s3aggregation.mk)
