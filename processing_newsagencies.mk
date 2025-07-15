$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_newsagencies.mk)
###############################################################################
# myprocessing TARGETS
# Targets for processing newspaper content with OCR quality assessment
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes myprocessing processing output data
sync-output :: sync-myprocessing

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes myprocessing processing input data
sync-input :: sync-rebuilt

# DOUBLE-COLON-TARGET: myprocessing-target
processing-target :: myprocessing-target


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltTomyprocessingFile
# Converts a local rebuilt file name to a local myprocessing file name
define LocalRebuiltTomyprocessingFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX)=$(LOCAL_PATH_MYPROCESSING)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_MYPROCESSING_FILES
# Stores the list of OCR quality assessment files based on rebuilt stamp files
LOCAL_MYPROCESSING_FILES := \
    $(call LocalRebuiltTomyprocessingFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_MYPROCESSING_FILES)

# TARGET: myprocessing-target
#: Processes newspaper content with OCR quality assessment
#
# Just uses the local data that is there, does not enforce synchronization
myprocessing-target: $(LOCAL_MYPROCESSING_FILES)

.PHONY: myprocessing-target

# FILE-RULE: $(LOCAL_PATH_MYPROCESSING)/%.jsonl.bz2
#: Rule to process a single newspaper
$(LOCAL_PATH_MYPROCESSING)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX)
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
    python3 lib/cli_myprocessing.py \
      --input $(<) \
      --output $@ \
      --log-file $@.log.gz \
    && \
    python3 -m impresso_cookbook.local_to_s3 \
      $@        $(call LocalToS3,$@,'') \
      $@.log.gz $(call LocalToS3,$@,'').log.gz \
    || { rm -vf $@ ; exit 1 ; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_newsagencies.mk)
