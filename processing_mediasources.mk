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

BATCH_SIZE_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin BATCH_SIZE_MEDIASOURCES)),not configured,$(BATCH_SIZE_MEDIASOURCES))
OUTER_BATCH_SIZE_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin OUTER_BATCH_SIZE_MEDIASOURCES)),not configured,$(OUTER_BATCH_SIZE_MEDIASOURCES))
DEVICE_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin DEVICE_MEDIASOURCES)),not configured,$(DEVICE_MEDIASOURCES))
DIAGNOSTICS_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin DIAGNOSTICS_MEDIASOURCES)),not configured,$(DIAGNOSTICS_MEDIASOURCES))

help-processing::
	@echo ""
	@echo "MEDIA-SOURCES PROCESSING:"
	@echo "  mediasources-target # Process rebuilt content with media-source NER"
	@echo ""
	@echo "MEDIA-SOURCES SETTINGS:"
	@echo "  HF_MODEL_MEDIASOURCES=$(HF_MODEL_MEDIASOURCES)"
	@echo "  HF_MODEL_REVISION_MEDIASOURCES=$(HF_MODEL_REVISION_MEDIASOURCES)"

help-processing:: ; @echo "  BATCH_SIZE_MEDIASOURCES=$(BATCH_SIZE_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  OUTER_BATCH_SIZE_MEDIASOURCES=$(OUTER_BATCH_SIZE_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  DEVICE_MEDIASOURCES=$(DEVICE_MEDIASOURCES_HELP)"
help-processing:: ; @echo "  DIAGNOSTICS_MEDIASOURCES=$(DIAGNOSTICS_MEDIASOURCES_HELP)"


LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
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


$(LOCAL_PATH_MEDIASOURCES)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
    $(PYTHON) lib/cli_mediasources.py \
      --input $(call LocalToS3,$<) \
      --output $@ \
      --log-file $@.log.gz \
      --log-level $(LOGGING_LEVEL) \
      --hf-model $(HF_MODEL_MEDIASOURCES) \
      --revision $(HF_MODEL_REVISION_MEDIASOURCES) \
      --batch-size $(BATCH_SIZE_MEDIASOURCES) \
      --outer-batch-size $(OUTER_BATCH_SIZE_MEDIASOURCES) \
      --device $(DEVICE_MEDIASOURCES) \
      $(DIAGNOSTICS_MEDIASOURCES) \
    && \
    $(PYTHON) -m impresso_cookbook.local_to_s3 \
      $@        $(call LocalToS3,$@) \
      $@.log.gz $(call LocalToS3,$@).log.gz \
    || { rm -vf $@ ; exit 1 ; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_mediasources.mk)
