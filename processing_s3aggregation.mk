$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_s3aggregation.mk)
###############################################################################
# s3aggregation TARGETS
# Targets for on-demand aggregation and extraction
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes s3aggregation processing output data
sync-output :: sync-s3aggregation

# USER-VARIABLE: SYNC_INPUT_s3aggregation
# Target used to synchronize input data for s3aggregation (default: sync-rebuilt)
SYNC_INPUT_s3aggregation ?= sync-rebuilt

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes s3aggregation processing input data
sync-input :: $(SYNC_INPUT_s3aggregation)

# USER-VARIABLE: LOCAL_PATH_INPUT_s3aggregation
# Local directory holding input stamp files for s3aggregation (default: $(LOCAL_PATH_REBUILT))
LOCAL_PATH_INPUT_s3aggregation ?= $(LOCAL_PATH_REBUILT)

# USER-VARIABLE: S3_PATH_INPUT_s3aggregation
# S3 prefix holding input files for s3aggregation (default: $(S3_PATH_REBUILT))
S3_PATH_INPUT_s3aggregation ?= $(S3_PATH_REBUILT)

# DOUBLE-COLON-TARGET: s3aggregation-target
processing-target :: s3aggregation-target


# VARIABLE: LOCAL_INPUT_STAMP_FILES
# Stores all locally available input stamp files for dependency tracking
# Input stamps match S3 file names exactly (no suffix)
LOCAL_INPUT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_INPUT_s3aggregation)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_INPUT_STAMP_FILES)


# FUNCTION: LocalInputTos3aggregationFile
# Converts a local input stamp file name to a local s3aggregation file name
# Input stamps match S3 file names exactly (no suffix)
define LocalInputTos3aggregationFile
$(1:$(LOCAL_PATH_INPUT_s3aggregation)/%.jsonl.bz2=$(LOCAL_PATH_s3aggregation)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_s3aggregation_FILES
# Stores the list of s3aggregation output files based on input stamp files
LOCAL_s3aggregation_FILES := \
    $(call LocalInputTos3aggregationFile,$(LOCAL_INPUT_STAMP_FILES))

  $(call log.debug, LOCAL_s3aggregation_FILES)

# TARGET: s3aggregation-target
#: Processes newspaper content with s3aggregation
#
# Just uses the local data that is there, does not enforce synchronization
s3aggregation-target: $(LOCAL_s3aggregation_FILES)

.PHONY: s3aggregation-target


# FILE-RULE: $(LOCAL_PATH_s3aggregation)/%.jsonl.bz2
#: Rule to process a single newspaper
#: Input stamps match S3 file names exactly (no suffix to strip)
$(LOCAL_PATH_s3aggregation)/%.jsonl.bz2: $(LOCAL_PATH_INPUT_s3aggregation)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
    $(PYTHON) lib/cli_s3aggregation.py \
      --input $(call LocalToS3,$<) \
      --output $@ \
      --log-file $@.log.gz \
      $(CLI_EXTRA_ARGS) \
    && \
    $(PYTHON) -m impresso_cookbook.local_to_s3 \
      $@        $(call LocalToS3,$@) \
      $@.log.gz $(call LocalToS3,$@).log.gz \
    || { rm -vf $@ ; exit 1 ; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_s3aggregation.mk)
