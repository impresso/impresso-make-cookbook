$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_lingproc.mk)

###############################################################################
# LINGUISTIC PROCESSING TARGETS
# Targets for processing newspaper content with linguistic analysis
###############################################################################

# Configuration for S3 storage updates
# Set to --validate for schema validation of output
LINGPROC_VALIDATE_OPTION ?= --validate
  $(call log.debug, LINGPROC_VALIDATE_OPTION)

# Prevent any output to s3 even if s3-output-path is set
# LINGPROC_S3_OUTPUT_DRY_RUN?= --s3-output-dry-run
# To disable the dry-run mode, comment the line above and uncomment the line below
LINGPROC_S3_OUTPUT_DRY_RUN ?=
  $(call log.debug, LINGPROC_S3_OUTPUT_DRY_RUN)

# Keep only the local timestam output files after uploading (only relevant when
# uploading to s3)
#
LINGPROC_KEEP_TIMESTAMP_ONLY_OPTION ?= --keep-timestamp-only
# To disable the keep-timestamp-only mode, comment the line above and uncomment the line below
#LINGPROC_KEEP_TIMESTAMP_ONLY_OPTION ?= 
  $(call log.debug, LINGPROC_KEEP_TIMESTAMP_ONLY_OPTION)


# Quit the processing if the output file already exists in s3
# double check if the output file exists in s3 and quit if it does
LINGPROC_QUIT_IF_S3_OUTPUT_EXISTS_OPTION ?= --quit-if-s3-output-exists
# To disable the quit-if-s3-output-exists mode, comment the line above and uncomment the line below
#LINGPROC_QUIT_IF_S3_OUTPUT_EXISTS_OPTION ?=
  $(call log.debug, LINGPROC_QUIT_IF_S3_OUTPUT_EXISTS_OPTION)

# @TODO: Add a quiet option to the processing script
LINGPROC_QUIET_OPTION ?= 
  $(call log.debug, LINGPROC_QUIET_OPTION)

# variable for all locally available rebuilt stamp files. Needed for dependency tracking
# of the build process. We discard errors as the path or file might not exist yet.
LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(IN_LOCAL_PATH_REBUILT)/*.jsonl.bz2$(IN_LOCAL_REBUILT_STAMP_SUFFIX) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)

define local_rebuilt_to_lingproc_file
$(1:$(IN_LOCAL_PATH_REBUILT)/%.jsonl.bz2$(IN_LOCAL_REBUILT_STAMP_SUFFIX)=$(OUT_LOCAL_PATH_LINGPROC)/%.jsonl.bz2)
endef


LOCAL_LINGPROC_FILES := \
    $(call local_rebuilt_to_lingproc_file,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_LINGPROC_FILES)

# Note: make sync is needed in a separate process to prepare the data for the build! This target just takes whatever the
# current situation regarding the data is and processes it. It does not sync the data from s3 to the local directory.
lingproc-target: $(LOCAL_LINGPROC_FILES)

.PHONY: lingproc-target


# Rule to process a single newspaper
# Note: we need to unset the errexit SHELL flag to be able to communicate the exit code of the processing script
$(OUT_LOCAL_PATH_LINGPROC)/%.jsonl.bz2: $(IN_LOCAL_PATH_REBUILT)/%.jsonl.bz2.stamp $(IN_LOCAL_PATH_LANGIDENT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{  set +e ; \
	  python3 lib/spacy_linguistic_processing.py \
          $(call local_to_s3,$<,.stamp) \
          --lid $(call local_to_s3,$(word 2,$^),.stamp) \
          $(LINGPROC_VALIDATE_OPTION) \
          --s3-output-path $(call local_to_s3,$@,.stamp) \
          $(LINGPROC_KEEP_TIMESTAMP_ONLY_OPTION) \
          $(LINGPROC_QUIT_IF_S3_OUTPUT_EXISTS_OPTION) \
          $(LINGPROC_S3_OUTPUT_DRY_RUN) \
          $(LINGPROC_QUIET_OPTION) \
		  --git-version $(git_version) \
          -o $@ \
          --log-file $@.log.gz ; \
    EXIT_CODE=$$? ; \
	echo "Processing exit code: $$EXIT_CODE" ; \
    if [ $$EXIT_CODE -eq 0 ] ; then \
        echo "Processing completed successfully. Uploading logfile..." ; \
        python3 lib/s3_to_local_stamps.py \
            $(call local_to_s3,$@,.stamp).log.gz \
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
