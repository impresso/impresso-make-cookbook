$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_nel.mk)
###############################################################################
# nel TARGETS
# Targets for processing newspaper content with NEL
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes nel processing output data
sync-output :: sync-nel

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes nel processing input data
sync-input :: sync-rebuilt

# DOUBLE-COLON-TARGET: nel-target
processing-target :: nel-target

# Newspaper-level processing output used by show-delete-newspaper-s3.
S3_DELETE_NEWSPAPER_PREFIX ?= $(S3_PATH_NEL)


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
# Rebuilt stamps match S3 file names exactly (no suffix)
 LOCAL_REBUILT_STAMP_FILES := \
    $(call filter_newspaper_year_files,$(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat)))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltToNelFile
# Converts a local rebuilt stamp file name to a local nel file name
# Rebuilt stamps match S3 file names exactly (no suffix)
define LocalRebuiltToNelFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_NEL)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_NEL_FILES
# Stores the list of NEL files based on rebuilt stamp files
LOCAL_NEL_FILES := \
    $(call LocalRebuiltToNelFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_NEL_FILES)

# TARGET: nel-target
#: Processes newspaper content with NEL
#
# Just uses the local data that is there, does not enforce synchronization
nel-target: $(LOCAL_NEL_FILES)

.PHONY: nel-target

###
# S3 preflight and WIP lifecycle
#------------------------------------------------------------------------------

# USER-VARIABLE: NEL_WIP_ENABLED
# Enable WIP locking; set empty to disable locking (existence checks remain).
NEL_WIP_ENABLED ?= 1
  $(call log.debug, NEL_WIP_ENABLED)

# USER-VARIABLE: NEL_WIP_MAX_AGE
# Lock expiry in hours; choose longer than one complete processing/upload run.
NEL_WIP_MAX_AGE ?= 24
  $(call log.debug, NEL_WIP_MAX_AGE)

# USER-VARIABLE: NEL_FORCE_OVERWRITE_OPTION
# Set to --force-overwrite to replace existing S3 output.
NEL_FORCE_OVERWRITE_OPTION ?=
  $(call log.debug, NEL_FORCE_OVERWRITE_OPTION)

# USER-VARIABLE: NEL_UPLOAD_IF_NEWER_OPTION
# Set to --upload-if-newer to allow processing and compare timestamps at upload.
NEL_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, NEL_UPLOAD_IF_NEWER_OPTION)

# Bypass output existence only; active WIP locks still cause a skip.
NEL_WIP_FORCE_OPTION = $(if $(or $(NEL_FORCE_OVERWRITE_OPTION),$(NEL_UPLOAD_IF_NEWER_OPTION)),--force,)

help-processing::
	@echo "NEL S3/WIP OPTIONS:"
	@echo "  NEL_WIP_ENABLED=$(NEL_WIP_ENABLED)"
	@echo "  NEL_WIP_MAX_AGE=$(NEL_WIP_MAX_AGE)"
	@echo "  NEL_FORCE_OVERWRITE_OPTION=$(NEL_FORCE_OVERWRITE_OPTION)"
	@echo "  NEL_UPLOAD_IF_NEWER_OPTION=$(NEL_UPLOAD_IF_NEWER_OPTION)"

# FILE-RULE: $(LOCAL_PATH_NEL)/%.jsonl.bz2
#: Rule to process a single newspaper
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
$(LOCAL_PATH_NEL)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{ acquired_wip=0 ; \
	  status=0 ; \
	  if [ -n "$(NEL_WIP_ENABLED)" ] ; then \
	    $(PYTHON) -m impresso_cookbook.manage_s3_wip acquire \
	      --s3-target $(call LocalToS3,$@) \
	      --wip-max-age $(NEL_WIP_MAX_AGE) \
	      --log-level $(LOGGING_LEVEL) \
	      --local-target $@ \
	      --files $@ $@.log.gz \
	      $(NEL_WIP_FORCE_OPTION) || status=$$? ; \
	    case "$$status" in \
	      0) acquired_wip=1 ;; \
	      2|3) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  elif [ -z "$(NEL_FORCE_OVERWRITE_OPTION)" ] && [ -z "$(NEL_UPLOAD_IF_NEWER_OPTION)" ] ; then \
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
	  $(PYTHON) lib/cli_nel.py \
	    --input $(call LocalToS3,$<) \
	    --output $@ \
	    --log-file $@.log.gz \
	    --log-level $(LOGGING_LEVEL) || status=$$? ; \
	  if [ "$$status" -eq 0 ] ; then \
	    $(PYTHON) -m impresso_cookbook.local_to_s3 \
	      $(NEL_FORCE_OVERWRITE_OPTION) $(NEL_UPLOAD_IF_NEWER_OPTION) \
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


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_nel.mk)
