$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_mediasources.mk)
###############################################################################
# mediasources TARGETS
# Targets for processing newspaper content with media-source NER
###############################################################################


sync-output :: sync-mediasources

sync-input :: sync-rebuilt

# DOUBLE-COLON-TARGET: processing-target
#: Contribute media-source NER processing to generic processing
processing-target :: mediasources-target

# Newspaper-level processing output used by show-delete-newspaper-s3.
S3_DELETE_NEWSPAPER_PREFIX ?= $(S3_PATH_MEDIASOURCES)

BATCH_SIZE_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin BATCH_SIZE_MEDIASOURCES)),not configured,$(BATCH_SIZE_MEDIASOURCES))
OUTER_BATCH_SIZE_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin OUTER_BATCH_SIZE_MEDIASOURCES)),not configured,$(OUTER_BATCH_SIZE_MEDIASOURCES))
OUTER_BATCH_MAX_CHARS_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin OUTER_BATCH_MAX_CHARS_MEDIASOURCES)),not configured,$(OUTER_BATCH_MAX_CHARS_MEDIASOURCES))
DTYPE_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin DTYPE_MEDIASOURCES)),not configured,$(DTYPE_MEDIASOURCES))
DEVICE_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin DEVICE_MEDIASOURCES)),not configured,$(DEVICE_MEDIASOURCES))
FILTER_ANACHRONISTIC_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin FILTER_ANACHRONISTIC_MEDIASOURCES)),not configured,$(FILTER_ANACHRONISTIC_MEDIASOURCES))
DIAGNOSTICS_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin DIAGNOSTICS_MEDIASOURCES)),not configured,$(DIAGNOSTICS_MEDIASOURCES))
MIN_YEAR_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin MIN_YEAR_MEDIASOURCES)),not configured,$(MIN_YEAR_MEDIASOURCES))
SAMPLE_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin SAMPLE_MEDIASOURCES)),not configured,$(SAMPLE_MEDIASOURCES))
SAMPLE_SEED_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin SAMPLE_SEED_MEDIASOURCES)),not configured,$(SAMPLE_SEED_MEDIASOURCES))

help-processing::
	@echo ""
	@echo "MEDIA-SOURCES PROCESSING:"
	@echo "  make mediasources-target                # Process rebuilt content with media-source NER"
	@echo ""
	@echo "MEDIA-SOURCES SETTINGS:"
	@echo "  HF_MODEL_MEDIASOURCES=$(HF_MODEL_MEDIASOURCES)"
	@echo "  HF_MODEL_REVISION_MEDIASOURCES=$(HF_MODEL_REVISION_MEDIASOURCES)"

help-processing:: ; @echo "  BATCH_SIZE_MEDIASOURCES=$(BATCH_SIZE_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  OUTER_BATCH_SIZE_MEDIASOURCES=$(OUTER_BATCH_SIZE_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  OUTER_BATCH_MAX_CHARS_MEDIASOURCES=$(OUTER_BATCH_MAX_CHARS_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  DTYPE_MEDIASOURCES=$(DTYPE_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  DEVICE_MEDIASOURCES=$(DEVICE_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  FILTER_ANACHRONISTIC_MEDIASOURCES=$(FILTER_ANACHRONISTIC_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  DIAGNOSTICS_MEDIASOURCES=$(DIAGNOSTICS_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  MIN_YEAR_MEDIASOURCES=$(MIN_YEAR_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  SAMPLE_MEDIASOURCES=$(SAMPLE_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  SAMPLE_SEED_MEDIASOURCES=$(SAMPLE_SEED_MEDIASOURCES_HELP)"


LOCAL_REBUILT_STAMP_FILES := \
    $(call filter_newspaper_year_files,$(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat)))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


define LocalRebuiltToMediasourcesFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_MEDIASOURCES)/%.jsonl.bz2)
endef


LOCAL_MEDIASOURCES_FILES := \
    $(call LocalRebuiltToMediasourcesFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_MEDIASOURCES_FILES)


# TARGET: mediasources-target
#: Process newspaper content with media-source NER
mediasources-target: $(LOCAL_MEDIASOURCES_FILES)

.PHONY: mediasources-target



###
# S3 preflight and WIP lifecycle
#------------------------------------------------------------------------------

# USER-VARIABLE: MEDIASOURCES_WIP_ENABLED
# Enable WIP locking; set empty to disable locking (existence checks remain).
MEDIASOURCES_WIP_ENABLED ?= 1
  $(call log.debug, MEDIASOURCES_WIP_ENABLED)

# USER-VARIABLE: MEDIASOURCES_WIP_MAX_AGE
# Lock expiry in hours; choose longer than one complete processing/upload run.
MEDIASOURCES_WIP_MAX_AGE ?= 24
  $(call log.debug, MEDIASOURCES_WIP_MAX_AGE)

# USER-VARIABLE: MEDIASOURCES_FORCE_OVERWRITE_OPTION
# Set to --force-overwrite to replace existing S3 output.
MEDIASOURCES_FORCE_OVERWRITE_OPTION ?=
  $(call log.debug, MEDIASOURCES_FORCE_OVERWRITE_OPTION)

# USER-VARIABLE: MEDIASOURCES_UPLOAD_IF_NEWER_OPTION
# Set to --upload-if-newer to allow processing and compare timestamps at upload.
MEDIASOURCES_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, MEDIASOURCES_UPLOAD_IF_NEWER_OPTION)

# Bypass output existence only; active WIP locks still cause a skip.
MEDIASOURCES_WIP_FORCE_OPTION = $(if $(or $(MEDIASOURCES_FORCE_OVERWRITE_OPTION),$(MEDIASOURCES_UPLOAD_IF_NEWER_OPTION)),--force,)

help-processing::
	@echo "MEDIASOURCES S3/WIP OPTIONS:"
	@echo "  MEDIASOURCES_WIP_ENABLED=$(MEDIASOURCES_WIP_ENABLED)"
	@echo "  MEDIASOURCES_WIP_MAX_AGE=$(MEDIASOURCES_WIP_MAX_AGE)"
	@echo "  MEDIASOURCES_FORCE_OVERWRITE_OPTION=$(MEDIASOURCES_FORCE_OVERWRITE_OPTION)"
	@echo "  MEDIASOURCES_UPLOAD_IF_NEWER_OPTION=$(MEDIASOURCES_UPLOAD_IF_NEWER_OPTION)"

$(LOCAL_PATH_MEDIASOURCES)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{ acquired_wip=0 ; \
	  status=0 ; \
	  if [ -n "$(MEDIASOURCES_WIP_ENABLED)" ] ; then \
	    $(PYTHON) -m impresso_cookbook.manage_s3_wip acquire \
	      --s3-target $(call LocalToS3,$@) \
	      --wip-max-age $(MEDIASOURCES_WIP_MAX_AGE) \
	      --log-level $(LOGGING_LEVEL) \
	      --local-target $@ \
	      --files $@ $@.log.gz \
	      $(MEDIASOURCES_WIP_FORCE_OPTION) || status=$$? ; \
	    case "$$status" in \
	      0) acquired_wip=1 ;; \
	      2|3) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  elif [ -z "$(MEDIASOURCES_FORCE_OVERWRITE_OPTION)" ] && [ -z "$(MEDIASOURCES_UPLOAD_IF_NEWER_OPTION)" ] ; then \
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
	  MIN_YEAR_MEDIASOURCES="$(MIN_YEAR_MEDIASOURCES)" \
	  OUTER_BATCH_MAX_CHARS_MEDIASOURCES="$(OUTER_BATCH_MAX_CHARS_MEDIASOURCES)" \
	  SAMPLE_MEDIASOURCES="$(SAMPLE_MEDIASOURCES)" \
	  SAMPLE_SEED_MEDIASOURCES="$(SAMPLE_SEED_MEDIASOURCES)" \
	  $(PYTHON) lib/cli_mediasources.py \
	    --input $(call LocalToS3,$<) \
	    --output $@ \
	    --log-file $@.log.gz \
	    --log-level $(LOGGING_LEVEL) \
	    --hf-model $(HF_MODEL_MEDIASOURCES) \
	    --revision $(HF_MODEL_REVISION_MEDIASOURCES) \
	    --batch-size $(BATCH_SIZE_MEDIASOURCES) \
	    --outer-batch-size $(OUTER_BATCH_SIZE_MEDIASOURCES) \
	    --dtype $(DTYPE_MEDIASOURCES) \
	    --device $(DEVICE_MEDIASOURCES) \
	    $(FILTER_ANACHRONISTIC_MEDIASOURCES) \
	    $(DIAGNOSTICS_MEDIASOURCES) || status=$$? ; \
	  if [ "$$status" -eq 0 ] ; then \
	    $(PYTHON) -m impresso_cookbook.local_to_s3 \
	      $(MEDIASOURCES_FORCE_OVERWRITE_OPTION) $(MEDIASOURCES_UPLOAD_IF_NEWER_OPTION) \
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


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_mediasources.mk)
