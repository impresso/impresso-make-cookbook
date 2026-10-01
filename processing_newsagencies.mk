$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_newsagencies.mk)
###############################################################################
# newsagencies TARGETS
# Targets for processing newspaper content with newsagencies NER
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes newsagencies processing output data
sync-output :: sync-newsagencies

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes newsagencies processing input data
sync-input :: sync-rebuilt

# DOUBLE-COLON-TARGET: newsagencies-target
processing-target :: newsagencies-target

# Newspaper-level processing output used by show-delete-newspaper-s3.
S3_DELETE_NEWSPAPER_PREFIX ?= $(S3_PATH_NEWSAGENCIES)


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
# Rebuilt stamps match S3 file names exactly (no suffix)
LOCAL_REBUILT_STAMP_FILES := \
    $(call filter_newspaper_year_files,$(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat)))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltTonewsagenciesFile
# Converts a local rebuilt stamp file name to a local newsagencies file name
# Rebuilt stamps match S3 file names exactly (no suffix)
define LocalRebuiltTonewsagenciesFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_NEWSAGENCIES)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_NEWSAGENCIES_FILES
# Stores the list of newsagencies output files based on rebuilt stamp files
LOCAL_NEWSAGENCIES_FILES := \
    $(call LocalRebuiltTonewsagenciesFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_NEWSAGENCIES_FILES)

# TARGET: newsagencies-target
#: Processes newspaper content with news agency NER
#
# Just uses the local data that is there, does not enforce synchronization
newsagencies-target: $(LOCAL_NEWSAGENCIES_FILES)

.PHONY: newsagencies-target

###
# S3 preflight and WIP lifecycle
#------------------------------------------------------------------------------

# USER-VARIABLE: NEWSAGENCIES_WIP_ENABLED
# Enable WIP locking; set empty to disable locking (existence checks remain).
NEWSAGENCIES_WIP_ENABLED ?= 1
  $(call log.debug, NEWSAGENCIES_WIP_ENABLED)

# USER-VARIABLE: NEWSAGENCIES_WIP_MAX_AGE
# Lock expiry in hours; choose longer than one complete processing/upload run.
NEWSAGENCIES_WIP_MAX_AGE ?= 24
  $(call log.debug, NEWSAGENCIES_WIP_MAX_AGE)

# USER-VARIABLE: NEWSAGENCIES_FORCE_OVERWRITE_OPTION
# Set to --force-overwrite to replace existing S3 output.
NEWSAGENCIES_FORCE_OVERWRITE_OPTION ?=
  $(call log.debug, NEWSAGENCIES_FORCE_OVERWRITE_OPTION)

# USER-VARIABLE: NEWSAGENCIES_UPLOAD_IF_NEWER_OPTION
# Set to --upload-if-newer to allow processing and compare timestamps at upload.
NEWSAGENCIES_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, NEWSAGENCIES_UPLOAD_IF_NEWER_OPTION)

# Bypass output existence only; active WIP locks still cause a skip.
NEWSAGENCIES_WIP_FORCE_OPTION = $(if $(or $(NEWSAGENCIES_FORCE_OVERWRITE_OPTION),$(NEWSAGENCIES_UPLOAD_IF_NEWER_OPTION)),--force,)

help-processing::
	@echo "NEWSAGENCIES S3/WIP OPTIONS:"
	@echo "  NEWSAGENCIES_WIP_ENABLED=$(NEWSAGENCIES_WIP_ENABLED)"
	@echo "  NEWSAGENCIES_WIP_MAX_AGE=$(NEWSAGENCIES_WIP_MAX_AGE)"
	@echo "  NEWSAGENCIES_FORCE_OVERWRITE_OPTION=$(NEWSAGENCIES_FORCE_OVERWRITE_OPTION)"
	@echo "  NEWSAGENCIES_UPLOAD_IF_NEWER_OPTION=$(NEWSAGENCIES_UPLOAD_IF_NEWER_OPTION)"

# FILE-RULE: $(LOCAL_PATH_NEWSAGENCIES)/%.jsonl.bz2
#: Rule to process a single newspaper
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
$(LOCAL_PATH_NEWSAGENCIES)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{ acquired_wip=0 ; \
	  status=0 ; \
	  if [ -n "$(NEWSAGENCIES_WIP_ENABLED)" ] ; then \
	    python3 -m impresso_cookbook.manage_s3_wip acquire \
	      --s3-target $(call LocalToS3,$@) \
	      --wip-max-age $(NEWSAGENCIES_WIP_MAX_AGE) \
	      --log-level $(LOGGING_LEVEL) \
	      --local-target $@ \
	      --files $@ $@.log.gz \
	      $(NEWSAGENCIES_WIP_FORCE_OPTION) || status=$$? ; \
	    case "$$status" in \
	      0) acquired_wip=1 ;; \
	      2|3) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  elif [ -z "$(NEWSAGENCIES_FORCE_OVERWRITE_OPTION)" ] && [ -z "$(NEWSAGENCIES_UPLOAD_IF_NEWER_OPTION)" ] ; then \
	    python3 -m impresso_cookbook.local_to_s3 \
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
	  python3 lib/cli_newsagencies.py \
	    --input $(call LocalToS3,$<) \
	    --output $@ \
	    --log-file $@.log.gz \
	    --log-level $(LOGGING_LEVEL) \
	    --hf-model $(HF_MODEL_NEWSAGENCIES) || status=$$? ; \
	  if [ "$$status" -eq 0 ] ; then \
	    python3 -m impresso_cookbook.local_to_s3 \
	      $(NEWSAGENCIES_FORCE_OVERWRITE_OPTION) $(NEWSAGENCIES_UPLOAD_IF_NEWER_OPTION) \
	      $@        $(call LocalToS3,$@) \
	      $@.log.gz $(call LocalToS3,$@).log.gz || status=$$? ; \
	  fi ; \
	  if [ "$$status" -ne 0 ] ; then \
	    rm -f $@ || true ; \
	  fi ; \
	  release_status=0 ; \
	  if [ "$$acquired_wip" -eq 1 ] ; then \
	    python3 -m impresso_cookbook.manage_s3_wip release \
	      --s3-target $(call LocalToS3,$@) \
	      --log-level $(LOGGING_LEVEL) || release_status=$$? ; \
	  fi ; \
	  if [ "$$status" -ne 0 ] ; then \
	    exit "$$status" ; \
	  fi ; \
	  exit "$$release_status" ; \
	}


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_newsagencies.mk)
