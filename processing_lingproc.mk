$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_lingproc.mk)
###############################################################################
# LINGUISTIC PROCESSING TARGETS
# Targets for processing newspaper content with linguistic analysis
###############################################################################

# DOUBLE-COLON-TARGET: lingproc-target
processing-target :: lingproc-target


# USER-VARIABLE: LINGPROC_VALIDATE_OPTION
# Option to enable schema validation of the output
#
# Set to no value or $(EMPTY) for preventing JSON schema validation
# LINGPROC_VALIDATE_OPTION ?= $(EMPTY)
LINGPROC_VALIDATE_OPTION ?= --validate
  $(call log.debug, LINGPROC_VALIDATE_OPTION)


# USER-VARIABLE: LINGPROC_QUIET_OPTION
# Reserved for quiet processing mode (@TODO: Implement in script)
LINGPROC_QUIET_OPTION ?= 
  $(call log.debug, LINGPROC_QUIET_OPTION)


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltToLingprocFile
# Converts a local rebuilt file name to a local linguistic processing file name
define LocalRebuiltToLingprocFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX)=$(LOCAL_PATH_LINGPROC)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_LINGPROC_FILES
# Stores the list of linguistic processing files based on rebuilt stamp files
LOCAL_LINGPROC_FILES := \
    $(call LocalRebuiltToLingprocFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_LINGPROC_FILES)

# TARGET: lingproc-target
#: Processes newspaper content with linguistic analysis
#
# Just uses the local data that is there, does not enforce synchronization
lingproc-target: $(LOCAL_LINGPROC_FILES)

PHONY_TARGETS += lingproc-target

# FILE-RULE: $(LOCAL_PATH_LINGPROC)/%.jsonl.bz2
#: Rule to process a single newspaper
#
# Note: Unsets errexit flag to communicate exit codes
$(LOCAL_PATH_LINGPROC)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX) $(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{  set +e ; \
     python3 lib/spacy_linguistic_processing.py \
          $(call LocalToS3,$<,$(LOCAL_REBUILT_STAMP_SUFFIX)) \
          --lid $(call LocalToS3,$(word 2,$^),'') \
          $(LINGPROC_VALIDATE_OPTION) \
          --s3-output-path $(call LocalToS3,$@,.'') \
          $(PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION) \
          $(PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION) \
          $(PROCESSING_S3_OUTPUT_DRY_RUN) \
          $(LINGPROC_QUIET_OPTION) \
          --git-version $(GIT_VERSION) \
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


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_lingproc.mk)
