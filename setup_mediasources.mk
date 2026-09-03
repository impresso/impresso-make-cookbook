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

DTYPE_MEDIASOURCES_HELP := $(if $(filter undefined,$(origin DTYPE_MEDIASOURCES)),not configured,$(DTYPE_MEDIASOURCES))

help-setup::
	@echo ""
	@echo "MEDIA-SOURCES SETUP:"
	@echo "  setup-mediasources # Download/cache the media-source model and run a smoke test"
	@echo "                     # Controlled by MEDIASOURCES_WARM_CACHE=$(MEDIASOURCES_WARM_CACHE)"
	@echo "                     # DTYPE_MEDIASOURCES=$(DTYPE_MEDIASOURCES_HELP)"


# TARGET: setup-mediasources
#: Download/cache the media-source Hugging Face model and run a smoke test
setup-mediasources:
ifeq ($(MEDIASOURCES_WARM_CACHE),1)
	HF_MODEL_MEDIASOURCES="$(HF_MODEL_MEDIASOURCES)" \
	HF_MODEL_REVISION_MEDIASOURCES="$(HF_MODEL_REVISION_MEDIASOURCES)" \
	DTYPE_MEDIASOURCES="$(DTYPE_MEDIASOURCES)" \
	MEDIASOURCES_SETUP_TEST_TEXT="$(MEDIASOURCES_SETUP_TEST_TEXT)" \
	$(PYTHON) -c 'import os; from huggingface_hub import snapshot_download; from impresso_pipelines.mediasources import MediaSourcesPipeline; model = os.environ["HF_MODEL_MEDIASOURCES"]; revision = os.environ["HF_MODEL_REVISION_MEDIASOURCES"]; requested_dtype = os.environ["DTYPE_MEDIASOURCES"]; model_path = snapshot_download(repo_id=model, revision=revision, local_files_only=False); print(f"mediasources model cache: {model_path}"); print(f"mediasources requested dtype: {requested_dtype}"); pipe = MediaSourcesPipeline(model=model, revision=revision, dtype=requested_dtype, batch_size=1, local_files_only=False); hf_model = getattr(pipe, "model", None); dtype = getattr(hf_model, "dtype", None); print(f"mediasources model dtype: {dtype if dtype is not None else next(hf_model.parameters()).dtype}"); result = pipe([os.environ["MEDIASOURCES_SETUP_TEST_TEXT"]]); assert isinstance(result, list) and len(result) == 1, result; print("mediasources setup smoke test ok")'
else
	@echo "Skipping media-source Hugging Face cache warmup (set MEDIASOURCES_WARM_CACHE=1 to enable)."
endif

.PHONY: setup-mediasources

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_mediasources.mk)
