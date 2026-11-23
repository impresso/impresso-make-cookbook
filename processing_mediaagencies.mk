$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_mediaagencies.mk)
###############################################################################
# mediaagencies TARGETS
# Targets for processing newspaper content with media-agency NER
###############################################################################


sync-output :: sync-mediaagencies

sync-input :: sync-rebuilt

# DOUBLE-COLON-TARGET: processing-target
#: Contribute media-agency NER processing to generic processing
processing-target :: mediaagencies-target

# Newspaper-level processing output used by show-delete-newspaper-s3.
S3_DELETE_NEWSPAPER_PREFIX ?= $(S3_PATH_MEDIAAGENCIES)

BATCH_SIZE_MEDIAAGENCIES_HELP := $(if $(filter undefined,$(origin BATCH_SIZE_MEDIAAGENCIES)),not configured,$(BATCH_SIZE_MEDIAAGENCIES))
OUTER_BATCH_SIZE_MEDIAAGENCIES_HELP := $(if $(filter undefined,$(origin OUTER_BATCH_SIZE_MEDIAAGENCIES)),not configured,$(OUTER_BATCH_SIZE_MEDIAAGENCIES))
OUTER_BATCH_MAX_CHARS_MEDIAAGENCIES_HELP := $(if $(filter undefined,$(origin OUTER_BATCH_MAX_CHARS_MEDIAAGENCIES)),not configured,$(OUTER_BATCH_MAX_CHARS_MEDIAAGENCIES))
DTYPE_MEDIAAGENCIES_HELP := $(if $(filter undefined,$(origin DTYPE_MEDIAAGENCIES)),not configured,$(DTYPE_MEDIAAGENCIES))
DEVICE_MEDIAAGENCIES_HELP := $(if $(filter undefined,$(origin DEVICE_MEDIAAGENCIES)),not configured,$(DEVICE_MEDIAAGENCIES))
FILTER_ANACHRONISTIC_MEDIAAGENCIES_HELP := $(if $(filter undefined,$(origin FILTER_ANACHRONISTIC_MEDIAAGENCIES)),not configured,$(FILTER_ANACHRONISTIC_MEDIAAGENCIES))
DIAGNOSTICS_MEDIAAGENCIES_HELP := $(if $(filter undefined,$(origin DIAGNOSTICS_MEDIAAGENCIES)),not configured,$(DIAGNOSTICS_MEDIAAGENCIES))
MIN_YEAR_MEDIAAGENCIES_HELP := $(if $(filter undefined,$(origin MIN_YEAR_MEDIAAGENCIES)),not configured,$(MIN_YEAR_MEDIAAGENCIES))
SAMPLE_MEDIAAGENCIES_HELP := $(if $(filter undefined,$(origin SAMPLE_MEDIAAGENCIES)),not configured,$(SAMPLE_MEDIAAGENCIES))
SAMPLE_SEED_MEDIAAGENCIES_HELP := $(if $(filter undefined,$(origin SAMPLE_SEED_MEDIAAGENCIES)),not configured,$(SAMPLE_SEED_MEDIAAGENCIES))

help-processing::
	@echo ""
	@echo "MEDIA-AGENCIES PROCESSING:"
	@echo "  mediaagencies-target # Process rebuilt content with media-agency NER"
	@echo ""
	@echo "MEDIA-AGENCIES SETTINGS:"
	@echo "  HF_MODEL_MEDIAAGENCIES=$(HF_MODEL_MEDIAAGENCIES)"
	@echo "  HF_MODEL_REVISION_MEDIAAGENCIES=$(HF_MODEL_REVISION_MEDIAAGENCIES)"

help-processing:: ; @echo "  BATCH_SIZE_MEDIAAGENCIES=$(BATCH_SIZE_MEDIAAGENCIES_HELP)"
help-processing:: ; @echo "  OUTER_BATCH_SIZE_MEDIAAGENCIES=$(OUTER_BATCH_SIZE_MEDIAAGENCIES_HELP)"
help-processing:: ; @echo "  OUTER_BATCH_MAX_CHARS_MEDIAAGENCIES=$(OUTER_BATCH_MAX_CHARS_MEDIAAGENCIES_HELP)"
help-processing:: ; @echo "  DTYPE_MEDIAAGENCIES=$(DTYPE_MEDIAAGENCIES_HELP)"
help-processing:: ; @echo "  DEVICE_MEDIAAGENCIES=$(DEVICE_MEDIAAGENCIES_HELP)"
help-processing:: ; @echo "  FILTER_ANACHRONISTIC_MEDIAAGENCIES=$(FILTER_ANACHRONISTIC_MEDIAAGENCIES_HELP)"
help-processing:: ; @echo "  DIAGNOSTICS_MEDIAAGENCIES=$(DIAGNOSTICS_MEDIAAGENCIES_HELP)"
help-processing:: ; @echo "  MIN_YEAR_MEDIAAGENCIES=$(MIN_YEAR_MEDIAAGENCIES_HELP)"
help-processing:: ; @echo "  SAMPLE_MEDIAAGENCIES=$(SAMPLE_MEDIAAGENCIES_HELP)"
help-processing:: ; @echo "  SAMPLE_SEED_MEDIAAGENCIES=$(SAMPLE_SEED_MEDIAAGENCIES_HELP)"


LOCAL_REBUILT_STAMP_FILES := \
    $(call filter_newspaper_year_files,$(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat)))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


define LocalRebuiltToMediaagenciesFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_MEDIAAGENCIES)/%.jsonl.bz2)
endef


LOCAL_MEDIAAGENCIES_FILES := \
    $(call LocalRebuiltToMediaagenciesFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_MEDIAAGENCIES_FILES)


# TARGET: mediaagencies-target
#: Process newspaper content with media-agency NER
mediaagencies-target: $(LOCAL_MEDIAAGENCIES_FILES)

.PHONY: mediaagencies-target



###
# S3 preflight and WIP lifecycle
#------------------------------------------------------------------------------

# USER-VARIABLE: MEDIAAGENCIES_WIP_ENABLED
# Enable WIP locking; set empty to disable locking (existence checks remain).
MEDIAAGENCIES_WIP_ENABLED ?= 1
  $(call log.debug, MEDIAAGENCIES_WIP_ENABLED)

# USER-VARIABLE: MEDIAAGENCIES_WIP_MAX_AGE
# Lock expiry in hours; choose longer than one complete processing/upload run.
MEDIAAGENCIES_WIP_MAX_AGE ?= 24
  $(call log.debug, MEDIAAGENCIES_WIP_MAX_AGE)

# USER-VARIABLE: MEDIAAGENCIES_FORCE_OVERWRITE_OPTION
# Set to --force-overwrite to replace existing S3 output.
MEDIAAGENCIES_FORCE_OVERWRITE_OPTION ?=
  $(call log.debug, MEDIAAGENCIES_FORCE_OVERWRITE_OPTION)

# USER-VARIABLE: MEDIAAGENCIES_UPLOAD_IF_NEWER_OPTION
# Set to --upload-if-newer to allow processing and compare timestamps at upload.
MEDIAAGENCIES_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, MEDIAAGENCIES_UPLOAD_IF_NEWER_OPTION)

# Bypass output existence only; active WIP locks still cause a skip.
MEDIAAGENCIES_WIP_FORCE_OPTION = $(if $(or $(MEDIAAGENCIES_FORCE_OVERWRITE_OPTION),$(MEDIAAGENCIES_UPLOAD_IF_NEWER_OPTION)),--force,)

help-processing::
	@echo "MEDIAAGENCIES S3/WIP OPTIONS:"
	@echo "  MEDIAAGENCIES_WIP_ENABLED=$(MEDIAAGENCIES_WIP_ENABLED)"
	@echo "  MEDIAAGENCIES_WIP_MAX_AGE=$(MEDIAAGENCIES_WIP_MAX_AGE)"
	@echo "  MEDIAAGENCIES_FORCE_OVERWRITE_OPTION=$(MEDIAAGENCIES_FORCE_OVERWRITE_OPTION)"
	@echo "  MEDIAAGENCIES_UPLOAD_IF_NEWER_OPTION=$(MEDIAAGENCIES_UPLOAD_IF_NEWER_OPTION)"

$(LOCAL_PATH_MEDIAAGENCIES)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{ acquired_wip=0 ; \
	  status=0 ; \
	  if [ -n "$(MEDIAAGENCIES_WIP_ENABLED)" ] ; then \
	    $(PYTHON) -m impresso_cookbook.manage_s3_wip acquire \
	      --s3-target $(call LocalToS3,$@) \
	      --wip-max-age $(MEDIAAGENCIES_WIP_MAX_AGE) \
	      --log-level $(LOGGING_LEVEL) \
	      --local-target $@ \
	      --files $@ $@.log.gz \
	      $(MEDIAAGENCIES_WIP_FORCE_OPTION) || status=$$? ; \
	    case "$$status" in \
	      0) acquired_wip=1 ;; \
	      2|3) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  elif [ -z "$(MEDIAAGENCIES_FORCE_OVERWRITE_OPTION)" ] && [ -z "$(MEDIAAGENCIES_UPLOAD_IF_NEWER_OPTION)" ] ; then \
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
	  TMPDIR=/tmp TORCHINDUCTOR_CACHE_DIR=/tmp/inductor TRITON_CACHE_DIR=/tmp/triton \
	  $(PYTHON) -m impresso_inference.tasks.mediaagencies.cli.run \
	    --input $(call LocalToS3,$<) \
	    --output $@ \
	    --model-name $(HF_MODEL_MEDIAAGENCIES) \
	    --revision $(HF_MODEL_REVISION_MEDIAAGENCIES) \
	    --batch-size $(BATCH_SIZE_MEDIAAGENCIES) \
	    --precision $(if $(filter float32,$(DTYPE_MEDIAAGENCIES)),fp32,bf16) \
	    --device $(if $(filter auto,$(DEVICE_MEDIAAGENCIES)),cuda,$(DEVICE_MEDIAAGENCIES)) \
	    $(if $(filter --filter-anachronistic,$(FILTER_ANACHRONISTIC_MEDIAAGENCIES)),,--no-filter-anachronistic) || status=$$? ; \
	  if [ "$$status" -eq 0 ] ; then \
	    $(PYTHON) -m impresso_cookbook.local_to_s3 \
	      $(MEDIAAGENCIES_FORCE_OVERWRITE_OPTION) $(MEDIAAGENCIES_UPLOAD_IF_NEWER_OPTION) \
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


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_mediaagencies.mk)
