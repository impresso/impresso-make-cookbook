$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_mediasources.mk)

###############################################################################
# SETUP TARGETS
###############################################################################


setup:: setup-mediasources


# USER-VARIABLE: MEDIASOURCES_WARM_CACHE
# If set to 1, initialize MediaSourcesPipeline during setup so Hugging Face
# model files are downloaded once before parallel processing starts.
MEDIASOURCES_WARM_CACHE ?= 1
  $(call log.debug, MEDIASOURCES_WARM_CACHE)


# USER-VARIABLE: MEDIASOURCES_SETUP_TEST_TEXT
# Short text used to validate the media-source pipeline after model download.
MEDIASOURCES_SETUP_TEST_TEXT ?= Reuters reported the news from Luxembourg.
  $(call log.debug, MEDIASOURCES_SETUP_TEST_TEXT)

help-setup::
	@echo ""
	@echo "MEDIA-SOURCES SETUP:"
	@echo "  setup-mediasources # Download/cache the media-source model and run a smoke test"
	@echo "                     # Controlled by MEDIASOURCES_WARM_CACHE=$(MEDIASOURCES_WARM_CACHE)"


# TARGET: setup-mediasources
#: Download/cache the media-source Hugging Face model and run a smoke test
setup-mediasources:
ifeq ($(MEDIASOURCES_WARM_CACHE),1)
	$(PYTHON) -c 'from impresso_pipelines.mediasources import MediaSourcesPipeline; pipe = MediaSourcesPipeline(model="$(HF_MODEL_MEDIASOURCES)", revision="$(HF_MODEL_REVISION_MEDIASOURCES)", batch_size=1, local_files_only=False); result = pipe(["$(MEDIASOURCES_SETUP_TEST_TEXT)"]); assert isinstance(result, list) and len(result) == 1, result; print("mediasources setup smoke test ok")'
else
	@echo "Skipping media-source Hugging Face cache warmup (set MEDIASOURCES_WARM_CACHE=1 to enable)."
endif

.PHONY: setup-mediasources

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_mediasources.mk)
