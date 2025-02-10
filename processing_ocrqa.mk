$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_ocrqa.mk)
###############################################################################
# OCR QUALITY ASSESSMENT TARGETS
# Targets for processing newspaper content with OCR quality assessment
###############################################################################

# DOUBLE-COLON-TARGET: ocrqa-target
processing-target :: ocrqa-target

# USER-VARIABLE: OCRQA_VALIDATE_OPTION
# Option to enable schema validation of the output
#
# Set to no value or $(EMPTY) for preventing JSON schema validation
# OCRQA_VALIDATE_OPTION ?= $(EMPTY)
# OCRQA_VALIDATE_OPTION ?= --validate
OCRQA_VALIDATE_OPTION ?= 
  $(call log.debug, OCRQA_VALIDATE_OPTION)


# USER-VARIABLE: OCRQA_QUIET_OPTION
# Reserved for quiet processing mode (@TODO: Implement in script)
OCRQA_QUIET_OPTION ?= 
  $(call log.debug, OCRQA_QUIET_OPTION)

# USER-VARIABLE: OCRQA_LANGUAGES_OPTION
# Specify the languages to be used for OCR quality assessment. Must be synchronized with
# the bloomfilters used for the processing script!
OCRQA_LANGUAGES_OPTION ?= de fr
  $(call log.debug, OCRQA_LANGUAGES_OPTION)


# USER-VARIABLE: OCRQA_BLOOMFILTERS_OPTION Specify the bloom filter files to be used for
# OCR quality assessment. This can be huggingface filepaths (starting with hf:// impresso-project/OCR-quality-assessment-unigram/ocrqa-wp_v1.0.5-de.bloom or
# local files). Must be synchronized with the bloomfilters used for the processing
# script!
OCRQA_BLOOMFILTERS_OPTION ?= hf:// impresso-project/OCR-quality-assessment-unigram/ocrqa-wp_v1.0.5-de.bloom hf:// impresso-project/OCR-quality-assessment-unigram/ocrqa-wp_v1.0.5-fr.bloom
  $(call log.debug, OCRQA_BLOOMFILTERS_OPTION)


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltToOcrqaFile
# Converts a local rebuilt file name to a local OCR quality assessment file name
define LocalRebuiltToOcrqaFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX)=$(LOCAL_PATH_OCRQA)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_OCRQA_FILES
# Stores the list of OCR quality assessment files based on rebuilt stamp files
LOCAL_OCRQA_FILES := \
    $(call LocalRebuiltToOcrqaFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_OCRQA_FILES)

# TARGET: ocrqa-target
#: Processes newspaper content with OCR quality assessment
#
# Just uses the local data that is there, does not enforce synchronization
ocrqa-target: $(LOCAL_OCRQA_FILES)

PHONY_TARGETS += ocrqa-target

# FILE-RULE: $(LOCAL_PATH_OCRQA)/%.jsonl.bz2
#: Rule to process a single newspaper
#
# Note: Unsets errexit flag to communicate exit codes
$(LOCAL_PATH_OCRQA)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX) $(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{  set +e ; \
     python3 lib/ocrqa_bloom.py \
          --languages $(OCRQA_LANGUAGES_OPTION) \
          --bloomfilters $(OCRQA_BLOOMFILTERS_OPTION) \
          -i $(call LocalToS3,$<,$(LOCAL_REBUILT_STAMP_SUFFIX)) \
          --lid $(call LocalToS3,$(word 2,$^),'') \
          $(OCRQA_VALIDATE_OPTION) \
          --s3-output-path $(call LocalToS3,$@,.'') \
          $(PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION) \
          $(PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION) \
          $(PROCESSING_S3_OUTPUT_DRY_RUN) \
          --git-version $(git_version) \
          -o $@ \
          --log-file $@.log.gz ; \
    EXIT_CODE=$$? ; \
    echo "Processing exit code: $$EXIT_CODE" ; \
      if [ $$EXIT_CODE -eq 0 ] ; then \
          echo "Processing completed successfully. Uploading logfile..." ; \
          python3 lib/s3_to_local_stamps.py \
              $(call LocalToS3,$@,.stamp).log.gz \
              --upload-file $@.log.gz \
        --force-overwrite ; \
      elif [ $$EXIT_CODE -eq 3 ] ; then \
          echo "Processing skipped (output exists on S3). Not uploading logfile." ; \
          rm -f $@ ; \
          exit 0 ; \
      else \
          echo "An error occurred during processing. Exit code: $$EXIT_CODE" ; \
          rm -f $@ ; \
          exit $$EXIT_CODE ; \
      fi ; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_ocrqa.mk)
