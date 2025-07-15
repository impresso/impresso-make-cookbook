$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_newsagencies.mk)
###############################################################################
# newsagencies TARGETS
# Targets for processing newspaper content with OCR quality assessment
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes newsagencies processing output data
sync-output :: sync-newsagencies

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes newsagencies processing input data
sync-input :: sync-rebuilt

# DOUBLE-COLON-TARGET: newsagencies-target
processing-target :: newsagencies-target


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltTonewsagenciesFile
# Converts a local rebuilt file name to a local newsagencies file name
define LocalRebuiltTonewsagenciesFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX)=$(LOCAL_PATH_NEWSAGENCIES)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_NEWSAGENCIES_FILES
# Stores the list of OCR quality assessment files based on rebuilt stamp files
LOCAL_NEWSAGENCIES_FILES := \
    $(call LocalRebuiltTonewsagenciesFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_NEWSAGENCIES_FILES)

# TARGET: newsagencies-target
#: Processes newspaper content with OCR quality assessment
#
# Just uses the local data that is there, does not enforce synchronization
newsagencies-target: $(LOCAL_NEWSAGENCIES_FILES)

.PHONY: newsagencies-target

# FILE-RULE: $(LOCAL_PATH_NEWSAGENCIES)/%.jsonl.bz2
#: Rule to process a single newspaper
$(LOCAL_PATH_NEWSAGENCIES)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX)
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
    python3 lib/cli_newsagencies.py \
      --input $(call LocalToS3,$<,$(LOCAL_REBUILT_STAMP_SUFFIX)) \
      --output $@ \
      --log-file $@.log.gz \
      --log-level $(LOGGING_LEVEL) \
    && \
    python3 -m impresso_cookbook.local_to_s3 \
      $@        $(call LocalToS3,$@,'') \
      $@.log.gz $(call LocalToS3,$@,'').log.gz \
    || { rm -vf $@ ; exit 1 ; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_newsagencies.mk)
