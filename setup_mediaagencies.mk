$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_mediaagencies.mk)

###############################################################################
# SETUP TARGETS
###############################################################################


setup:: setup-mediaagencies


# USER-VARIABLE: MEDIAAGENCIES_WARM_CACHE
# If set to 1, run the impresso-inference runner on one test text during setup so
# Hugging Face model files are downloaded once before parallel processing starts.
MEDIAAGENCIES_WARM_CACHE ?= 1
  $(call log.debug, MEDIAAGENCIES_WARM_CACHE)


# USER-VARIABLE: MEDIAAGENCIES_SETUP_TEST_TEXT
# Short text used to validate the media-agency pipeline after model download.
MEDIAAGENCIES_SETUP_TEST_TEXT ?= Reuters reported the news from Luxembourg.
  $(call log.debug, MEDIAAGENCIES_SETUP_TEST_TEXT)

DTYPE_MEDIAAGENCIES_HELP := $(if $(filter undefined,$(origin DTYPE_MEDIAAGENCIES)),not configured,$(DTYPE_MEDIAAGENCIES))

help-setup::
	@echo ""
	@echo "MEDIA-AGENCIES SETUP:"
	@echo "  setup-mediaagencies # Download/cache the media-agency model and run a smoke test"
	@echo "                     # Controlled by MEDIAAGENCIES_WARM_CACHE=$(MEDIAAGENCIES_WARM_CACHE)"
	@echo "                     # DTYPE_MEDIAAGENCIES=$(DTYPE_MEDIAAGENCIES_HELP)"


# TARGET: setup-mediaagencies
#: Download/cache the media-agency Hugging Face model and run a smoke test
setup-mediaagencies:
ifeq ($(MEDIAAGENCIES_WARM_CACHE),1)
	mkdir -p $(BUILD_DIR)/setup-smoke-mediaagencies
	printf '{"id":"setup-smoke","ft":"%s","d":"1950-01-01"}\n' "$(MEDIAAGENCIES_SETUP_TEST_TEXT)" > $(BUILD_DIR)/setup-smoke-mediaagencies/in.jsonl
	TMPDIR=/tmp TORCHINDUCTOR_CACHE_DIR=/tmp/inductor TRITON_CACHE_DIR=/tmp/triton \
	$(PYTHON) -m impresso_inference.tasks.mediaagencies.cli.run \
	  --input $(BUILD_DIR)/setup-smoke-mediaagencies/in.jsonl \
	  --output $(BUILD_DIR)/setup-smoke-mediaagencies/out.jsonl \
	  --model-name $(HF_MODEL_MEDIAAGENCIES) \
	  --revision $(HF_MODEL_REVISION_MEDIAAGENCIES) \
	  --batch-size 1 \
	  --precision $(if $(filter float32,$(DTYPE_MEDIAAGENCIES)),fp32,bf16) \
	  --device $(if $(filter auto,$(DEVICE_MEDIAAGENCIES)),cuda,$(DEVICE_MEDIAAGENCIES)) \
	  --no-filter-anachronistic
	grep -q '"org.ent.pressagency.reuters"' $(BUILD_DIR)/setup-smoke-mediaagencies/out.jsonl
	@echo "mediaagencies setup smoke test ok"
else
	@echo "Skipping media-agency Hugging Face cache warmup (set MEDIAAGENCIES_WARM_CACHE=1 to enable)."
endif

.PHONY: setup-mediaagencies

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_mediaagencies.mk)
