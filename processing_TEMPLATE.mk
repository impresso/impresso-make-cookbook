$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_TEMPLATE.mk)
###############################################################################
# TEMPLATE TARGETS
# Targets for processing newspaper content with OCR quality assessment
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes TEMPLATE processing output data
sync-output :: sync-TEMPLATE

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes TEMPLATE processing input data
# @TODO: This needs to be updated to TEMPLATE processing
sync-input :: sync-rebuilt

# DOUBLE-COLON-TARGET: TEMPLATE-target
processing-target :: TEMPLATE-target

# Newspaper-level processing output used by show-delete-newspaper-s3.
S3_DELETE_NEWSPAPER_PREFIX ?= $(S3_PATH_TEMPLATE)


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
# Rebuilt stamps match S3 file names exactly (no suffix)
LOCAL_REBUILT_STAMP_FILES := \
    $(call filter_newspaper_year_files,$(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat)))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltToTEMPLATEFile
# Converts a local rebuilt stamp file name to a local TEMPLATE file name
# Rebuilt stamps match S3 file names exactly (no suffix)
define LocalRebuiltToTEMPLATEFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_TEMPLATE)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_TEMPLATE_FILES
# Stores the list of OCR quality assessment files based on rebuilt stamp files
LOCAL_TEMPLATE_FILES := \
    $(call LocalRebuiltToTEMPLATEFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_TEMPLATE_FILES)

# TARGET: TEMPLATE-target
#: Processes newspaper content with OCR quality assessment
#
# Just uses the local data that is there, does not enforce synchronization
TEMPLATE-target: $(LOCAL_TEMPLATE_FILES)

.PHONY: TEMPLATE-target

###
# S3 preflight and WIP lifecycle
#------------------------------------------------------------------------------

# USER-VARIABLE: TEMPLATE_WIP_ENABLED
# Enable WIP locking; set empty to disable locking (existence checks remain).
TEMPLATE_WIP_ENABLED ?= 1
  $(call log.debug, TEMPLATE_WIP_ENABLED)

# USER-VARIABLE: TEMPLATE_WIP_MAX_AGE
# Lock expiry in hours; choose longer than one complete processing/upload run.
TEMPLATE_WIP_MAX_AGE ?= 24
  $(call log.debug, TEMPLATE_WIP_MAX_AGE)

# USER-VARIABLE: TEMPLATE_FORCE_OVERWRITE_OPTION
# Set to --force-overwrite to replace existing S3 output.
TEMPLATE_FORCE_OVERWRITE_OPTION ?=
  $(call log.debug, TEMPLATE_FORCE_OVERWRITE_OPTION)

# USER-VARIABLE: TEMPLATE_UPLOAD_IF_NEWER_OPTION
# Set to --upload-if-newer to allow processing and compare timestamps at upload.
TEMPLATE_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, TEMPLATE_UPLOAD_IF_NEWER_OPTION)

# Bypass output existence only; active WIP locks still cause a skip.
TEMPLATE_WIP_FORCE_OPTION = $(if $(or $(TEMPLATE_FORCE_OVERWRITE_OPTION),$(TEMPLATE_UPLOAD_IF_NEWER_OPTION)),--force,)

help-processing::
	@echo "TEMPLATE S3/WIP OPTIONS:"
	@echo "  TEMPLATE_WIP_ENABLED=$(TEMPLATE_WIP_ENABLED)"
	@echo "  TEMPLATE_WIP_MAX_AGE=$(TEMPLATE_WIP_MAX_AGE)"
	@echo "  TEMPLATE_FORCE_OVERWRITE_OPTION=$(TEMPLATE_FORCE_OVERWRITE_OPTION)"
	@echo "  TEMPLATE_UPLOAD_IF_NEWER_OPTION=$(TEMPLATE_UPLOAD_IF_NEWER_OPTION)"

# FILE-RULE: $(LOCAL_PATH_TEMPLATE)/%.jsonl.bz2
#: Rule to process a single newspaper
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
$(LOCAL_PATH_TEMPLATE)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{ acquired_wip=0 ; \
	  status=0 ; \
	  if [ -n "$(TEMPLATE_WIP_ENABLED)" ] ; then \
	    $(PYTHON) -m impresso_cookbook.manage_s3_wip acquire \
	      --s3-target $(call LocalToS3,$@) \
	      --wip-max-age $(TEMPLATE_WIP_MAX_AGE) \
	      --log-level $(LOGGING_LEVEL) \
	      --local-target $@ \
	      --files $@ $@.log.gz \
	      $(TEMPLATE_WIP_FORCE_OPTION) || status=$$? ; \
	    case "$$status" in \
	      0) acquired_wip=1 ;; \
	      2|3) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  elif [ -z "$(TEMPLATE_FORCE_OVERWRITE_OPTION)" ] && [ -z "$(TEMPLATE_UPLOAD_IF_NEWER_OPTION)" ] ; then \
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
	  $(PYTHON) lib/cli_TEMPLATE.py \
	    --input $(call LocalToS3,$<) \
	    --output $@ \
	    --log-file $@.log.gz || status=$$? ; \
	  if [ "$$status" -eq 0 ] ; then \
	    $(PYTHON) -m impresso_cookbook.local_to_s3 \
	      $(TEMPLATE_FORCE_OVERWRITE_OPTION) $(TEMPLATE_UPLOAD_IF_NEWER_OPTION) \
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


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_TEMPLATE.mk)
