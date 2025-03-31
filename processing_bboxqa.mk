$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_bboxqa.mk)
###############################################################################
# BBOX QUALITY ASSESSMENT TARGETS
# Targets for processing newspaper content with BBOX quality assessment
###############################################################################

# DOUBLE-COLON-TARGET: bboxqa-target
processing-target :: bboxqa-target


#BBOXQA_VERBOSE_OUTPUT_OPTION ?= --verbose-output
BBOXQA_VERBOSE_OUTPUT_OPTION ?= 
  $(call log.debug, BBOXQA_VERBOSE_OUTPUT_OPTION)

# VARIABLE: CANONICAL_PAGES_STAMP_FILES
# Stores all canonical stamp files for dependency tracking
CANONICAL_PAGES_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_CANONICAL_PAGES)/*$(LOCAL_CANONICAL_STAMP_SUFFIX) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, CANONICAL_PAGES_STAMP_FILES)

# FUNCTION: CanonicalPagesToBboxqaFile
# Converts a canonical file name to a local BBOX quality assessment file name
define CanonicalPagesToBboxqaFile
$(1:$(LOCAL_PATH_CANONICAL_PAGES)/%$(LOCAL_CANONICAL_STAMP_SUFFIX)=$(LOCAL_PATH_BBOXQA)/%.jsonl.bz2)
endef

# VARIABLE: LOCAL_BBOXQA_FILES
# Stores the list of BBOX quality assessment files based on canonical stamp files
LOCAL_BBOXQA_FILES := \
    $(call CanonicalPagesToBboxqaFile,$(CANONICAL_PAGES_STAMP_FILES))

  $(call log.debug, LOCAL_BBOXQA_FILES)

# TARGET: bboxqa-target
#: Processes newspaper content with BBOX quality assessment
#
# Just uses the local data that is there, does not enforce synchronization
bboxqa-target: $(LOCAL_BBOXQA_FILES)

PHONY_TARGETS += bboxqa-target

# FILE-RULE: $(LOCAL_PATH_BBOXQA)/%.jsonl.bz2
#: Rule to process a single newspaper
#  \
# Note: Unsets errexit flag to communicate exit codes
$(LOCAL_PATH_BBOXQA)/%.jsonl.bz2: $(LOCAL_PATH_CANONICAL_PAGES)/%$(LOCAL_CANONICAL_STAMP_SUFFIX)
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{  set +e ; \
     python3 lib/check_lines_within_boundaries.py \
          --git_version $(GIT_VERSION) \
          --output $@ \
          --log-file $@.log.gz \
          $(call LocalToS3,$<,.stamp) \
          ; \
    EXIT_CODE=$$? ; \
    echo "Processing exit code: $$EXIT_CODE" ; \
      if [ $$EXIT_CODE -eq 0 ] ; then \
          echo "Processing completed successfully. Uploading logfile..." ; \
          python3 lib/s3_to_local_stamps.py \
              $(call LocalToS3,$@,.stamp).log.gz \
              --upload-file $@.log.gz \
        --force-overwrite ; \
        python3 lib/s3_to_local_stamps.py \
              $(call LocalToS3,$@,) \
              --upload-file $@ \
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


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_bboxqa.mk)
