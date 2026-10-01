$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_content_item_classification.mk)
###############################################################################
# content_item_classification TARGETS
# Targets for processing newspaper content with OCR quality assessment
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes content_item_classification processing output data
sync-output :: sync-content_item_classification

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes content_item_classification processing input data
# @TODO: This needs to be updated to content_item_classification processing
sync-input :: sync-rebuilt

# DOUBLE-COLON-TARGET: content_item_classification-target
processing-target :: content_item_classification-target


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
# Rebuilt stamps match S3 file names exactly (no suffix)
LOCAL_REBUILT_STAMP_FILES := \
    $(call filter_newspaper_year_files,$(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat)))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltTocontent_item_classificationFile
# Converts a local rebuilt stamp file name to a local content_item_classification file name
# Rebuilt stamps match S3 file names exactly (no suffix)
define LocalRebuiltTocontent_item_classificationFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_content_item_classification)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_content_item_classification_FILES
# Stores the list of OCR quality assessment files based on rebuilt stamp files
LOCAL_content_item_classification_FILES := \
    $(call LocalRebuiltTocontent_item_classificationFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_content_item_classification_FILES)

# TARGET: content_item_classification-target
#: Processes newspaper content with OCR quality assessment
#
# Just uses the local data that is there, does not enforce synchronization
content_item_classification-target: $(LOCAL_content_item_classification_FILES)

.PHONY: content_item_classification-target

###
# S3 preflight and WIP lifecycle
#------------------------------------------------------------------------------

# USER-VARIABLE: CONTENT_ITEM_CLASSIFICATION_WIP_ENABLED
# Enable WIP locking; set empty to disable locking (existence checks remain).
CONTENT_ITEM_CLASSIFICATION_WIP_ENABLED ?= 1
  $(call log.debug, CONTENT_ITEM_CLASSIFICATION_WIP_ENABLED)

# USER-VARIABLE: CONTENT_ITEM_CLASSIFICATION_WIP_MAX_AGE
# Lock expiry in hours; choose longer than one complete processing/upload run.
CONTENT_ITEM_CLASSIFICATION_WIP_MAX_AGE ?= 24
  $(call log.debug, CONTENT_ITEM_CLASSIFICATION_WIP_MAX_AGE)

# USER-VARIABLE: CONTENT_ITEM_CLASSIFICATION_FORCE_OVERWRITE_OPTION
# Set to --force-overwrite to replace existing S3 output.
CONTENT_ITEM_CLASSIFICATION_FORCE_OVERWRITE_OPTION ?=
  $(call log.debug, CONTENT_ITEM_CLASSIFICATION_FORCE_OVERWRITE_OPTION)

# USER-VARIABLE: CONTENT_ITEM_CLASSIFICATION_UPLOAD_IF_NEWER_OPTION
# Set to --upload-if-newer to allow processing and compare timestamps at upload.
CONTENT_ITEM_CLASSIFICATION_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, CONTENT_ITEM_CLASSIFICATION_UPLOAD_IF_NEWER_OPTION)

# Bypass output existence only; active WIP locks still cause a skip.
CONTENT_ITEM_CLASSIFICATION_WIP_FORCE_OPTION = $(if $(or $(CONTENT_ITEM_CLASSIFICATION_FORCE_OVERWRITE_OPTION),$(CONTENT_ITEM_CLASSIFICATION_UPLOAD_IF_NEWER_OPTION)),--force,)

help-processing::
	@echo "CONTENT_ITEM_CLASSIFICATION S3/WIP OPTIONS:"
	@echo "  CONTENT_ITEM_CLASSIFICATION_WIP_ENABLED=$(CONTENT_ITEM_CLASSIFICATION_WIP_ENABLED)"
	@echo "  CONTENT_ITEM_CLASSIFICATION_WIP_MAX_AGE=$(CONTENT_ITEM_CLASSIFICATION_WIP_MAX_AGE)"
	@echo "  CONTENT_ITEM_CLASSIFICATION_FORCE_OVERWRITE_OPTION=$(CONTENT_ITEM_CLASSIFICATION_FORCE_OVERWRITE_OPTION)"
	@echo "  CONTENT_ITEM_CLASSIFICATION_UPLOAD_IF_NEWER_OPTION=$(CONTENT_ITEM_CLASSIFICATION_UPLOAD_IF_NEWER_OPTION)"

# FILE-RULE: $(LOCAL_PATH_content_item_classification)/%.jsonl.bz2
#: Rule to process a single newspaper
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
$(LOCAL_PATH_content_item_classification)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{ acquired_wip=0 ; \
	  status=0 ; \
	  if [ -n "$(CONTENT_ITEM_CLASSIFICATION_WIP_ENABLED)" ] ; then \
	    $(PYTHON) -m impresso_cookbook.manage_s3_wip acquire \
	      --s3-target $(call LocalToS3,$@) \
	      --wip-max-age $(CONTENT_ITEM_CLASSIFICATION_WIP_MAX_AGE) \
	      --log-level $(LOGGING_LEVEL) \
	      --local-target $@ \
	      --files $@ $@.log.gz \
	      $(CONTENT_ITEM_CLASSIFICATION_WIP_FORCE_OPTION) || status=$$? ; \
	    case "$$status" in \
	      0) acquired_wip=1 ;; \
	      2|3) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  elif [ -z "$(CONTENT_ITEM_CLASSIFICATION_FORCE_OVERWRITE_OPTION)" ] && [ -z "$(CONTENT_ITEM_CLASSIFICATION_UPLOAD_IF_NEWER_OPTION)" ] ; then \
	    $(PYTHON) -m impresso_cookbook.local_to_s3 \
	      --s3-file-exists $(call LocalToS3,$@) \
	      --exit-2-if-exists \
	      --log-level $(LOGGING_LEVEL) || status=$$? ; \
	    case "$$status" in \
	      0) ;; \
	      2) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  fi ; \
	  status=0 ; \
	  $(PYTHON) lib/cli_content_item_classification.py \
	    --input $(call LocalToS3,$<) \
	    --output $@ \
	    --log-file $@.log.gz \
	    --model-id $(HF_MODEL_CONTENT_ITEM_CLASSIFICATION) || status=$$? ; \
	  if [ "$$status" -eq 0 ] ; then \
	    $(PYTHON) -m impresso_cookbook.local_to_s3 \
	      $(CONTENT_ITEM_CLASSIFICATION_FORCE_OVERWRITE_OPTION) $(CONTENT_ITEM_CLASSIFICATION_UPLOAD_IF_NEWER_OPTION) \
	      $@        $(call LocalToS3,$@) \
	      $@.log.gz $(call LocalToS3,$@).log.gz || status=$$? ; \
	  fi ; \
	  if [ "$$status" -ne 0 ] ; then \
	    rm -f $@ || true ; \
	  fi ; \
	  release_status=0 ; \
	  if [ "$$acquired_wip" -eq 1 ] ; then \
	    $(PYTHON) -m impresso_cookbook.manage_s3_wip release \
	      --s3-target $(call LocalToS3,$@) \
	      --log-level $(LOGGING_LEVEL) || release_status=$$? ; \
	  fi ; \
	  if [ "$$status" -ne 0 ] ; then \
	    exit "$$status" ; \
	  fi ; \
	  exit "$$release_status" ; \
	}


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_content_item_classification.mk)
