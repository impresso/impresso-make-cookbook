$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_mediaagencies.mk)
###############################################################################
# mediaagencies TARGETS
# Targets for processing newspaper content with media-agency NER
###############################################################################


# DOUBLE-COLON-TARGET: processing-target
#: Contribute media-agency NER processing to generic processing
processing-target :: mediaagencies-target

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


###
# Pipeline stage selection
#------------------------------------------------------------------------------

# USER-VARIABLE: MEDIAAGENCIES_STAGE
# Which part of the pipeline this make invocation runs:
#   all     - rebuilt JSONL -> final JSONL in one GPU process (cli.run)
#   prepare - rebuilt JSONL -> stage-1 parquet (CPU: tokenization and windows)
#   forward - stage-1 parquet -> stage-2 parquet (GPU: forward pass, sparse logits)
#   decode  - stage-2 parquet -> final JSONL (CPU: Viterbi decoding and filtering)
# Each stage syncs the stamps of its own input and output, so a collection run
# only processes years whose input exists and whose output is missing.
MEDIAAGENCIES_STAGE ?= all
  $(call log.debug, MEDIAAGENCIES_STAGE)

ifeq ($(filter $(MEDIAAGENCIES_STAGE),all prepare forward decode),)
$(error MEDIAAGENCIES_STAGE must be one of: all prepare forward decode (got '$(MEDIAAGENCIES_STAGE)'))
endif

# USER-VARIABLE: MIN_YEAR_MEDIAAGENCIES
# Years before this cutoff predate every label's founding year (Havas, 1835), so
# the anachronism filter would drop every entity. In the all and prepare stages
# such years skip the model and get empty results ({"id", "entities": []} per
# article) written directly to the final output. Set empty to disable.
MIN_YEAR_MEDIAAGENCIES ?=
  $(call log.debug, MIN_YEAR_MEDIAAGENCIES)

# USER-VARIABLE: CPU_WORKERS_MEDIAAGENCIES
# CPU worker processes per prepare/decode/all call. Keep 1 when COLLECTION_JOBS
# already uses all cores (for example COLLECTION_JOBS=30 on a 30-core machine).
CPU_WORKERS_MEDIAAGENCIES ?= 1
  $(call log.debug, CPU_WORKERS_MEDIAAGENCIES)

help-processing::
	@echo "MEDIAAGENCIES STAGES:"
	@echo "  MEDIAAGENCIES_STAGE=$(MEDIAAGENCIES_STAGE)  # all | prepare (CPU) | forward (GPU) | decode (CPU)"
	@echo "  CPU_WORKERS_MEDIAAGENCIES=$(CPU_WORKERS_MEDIAAGENCIES)"
	@echo "  MIN_YEAR_MEDIAAGENCIES=$(MIN_YEAR_MEDIAAGENCIES)  # earlier years get empty results without the model"
	@echo "  Example: make collection MEDIAAGENCIES_STAGE=prepare COLLECTION_JOBS=30 NEWSPAPER_JOBS=1 CFG=..."

ifeq ($(MEDIAAGENCIES_STAGE),all)
sync-input :: sync-rebuilt
sync-output :: sync-mediaagencies
clean-sync-output :: clean-sync-mediaagencies
S3_DELETE_NEWSPAPER_PREFIX ?= $(S3_PATH_MEDIAAGENCIES)
endif
ifeq ($(MEDIAAGENCIES_STAGE),prepare)
sync-input :: sync-rebuilt
sync-output :: sync-mediaagencies-stage1 sync-mediaagencies
clean-sync-output :: clean-sync-mediaagencies-stages clean-sync-mediaagencies
S3_DELETE_NEWSPAPER_PREFIX ?= $(S3_PATH_MEDIAAGENCIES_STAGE1)
endif
ifeq ($(MEDIAAGENCIES_STAGE),forward)
sync-input :: sync-mediaagencies-stage1
sync-output :: sync-mediaagencies-stage2
clean-sync-input :: clean-sync-mediaagencies-stages
clean-sync-output :: clean-sync-mediaagencies-stages
S3_DELETE_NEWSPAPER_PREFIX ?= $(S3_PATH_MEDIAAGENCIES_STAGE2)
endif
ifeq ($(MEDIAAGENCIES_STAGE),decode)
sync-input :: sync-mediaagencies-stage2
sync-output :: sync-mediaagencies
clean-sync-input :: clean-sync-mediaagencies-stages
clean-sync-output :: clean-sync-mediaagencies
S3_DELETE_NEWSPAPER_PREFIX ?= $(S3_PATH_MEDIAAGENCIES)
endif


###
# Input and output file lists
#------------------------------------------------------------------------------

# FUNCTION: filter_mediaagencies_year_files
# Restrict a file list to NEWSPAPER_YEARS for files named <alias>-<year>$(2).
filter_mediaagencies_year_files = $(if $(strip $(NEWSPAPER_YEARS)),$(foreach year,$(strip $(NEWSPAPER_YEARS)),$(filter %-$(year)$(2),$(1))),$(1))

# FUNCTION: list_mediaagencies_files
# Local stamp/data files in directory $(1) with suffix $(2), year-filtered and sorted.
list_mediaagencies_files = $(call filter_mediaagencies_year_files,$(shell ls -r $(1)/*$(2) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat)),$(2))

ifneq ($(filter $(MEDIAAGENCIES_STAGE),all prepare decode),)
LOCAL_REBUILT_STAMP_FILES := $(call list_mediaagencies_files,$(LOCAL_PATH_REBUILT),.jsonl.bz2)
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)

# Rebuilt year files <alias>-<year>.jsonl.bz2 with year < MIN_YEAR_MEDIAAGENCIES.
ifneq ($(strip $(MIN_YEAR_MEDIAAGENCIES)),)
LOCAL_REBUILT_EARLY_FILES := $(shell for f in $(LOCAL_REBUILT_STAMP_FILES); do \
    y=$${f%.jsonl.bz2}; y=$${y##*-}; \
    if [ "$$y" -lt $(MIN_YEAR_MEDIAAGENCIES) ] 2>/dev/null; then echo "$$f"; fi; \
  done)
else
LOCAL_REBUILT_EARLY_FILES :=
endif
  $(call log.debug, LOCAL_REBUILT_EARLY_FILES)

LOCAL_REBUILT_MODEL_FILES := $(filter-out $(LOCAL_REBUILT_EARLY_FILES),$(LOCAL_REBUILT_STAMP_FILES))

# Final outputs that get empty results without running the model.
LOCAL_MEDIAAGENCIES_EMPTY_FILES := \
    $(LOCAL_REBUILT_EARLY_FILES:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_MEDIAAGENCIES)/%.jsonl.bz2)
  $(call log.debug, LOCAL_MEDIAAGENCIES_EMPTY_FILES)
endif

ifeq ($(MEDIAAGENCIES_STAGE),all)
LOCAL_MEDIAAGENCIES_FILES := \
    $(LOCAL_REBUILT_MODEL_FILES:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_MEDIAAGENCIES)/%.jsonl.bz2) \
    $(LOCAL_MEDIAAGENCIES_EMPTY_FILES)
endif
ifeq ($(MEDIAAGENCIES_STAGE),prepare)
LOCAL_MEDIAAGENCIES_FILES := \
    $(LOCAL_REBUILT_MODEL_FILES:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_MEDIAAGENCIES_STAGE1)/%.stage1.parquet) \
    $(LOCAL_MEDIAAGENCIES_EMPTY_FILES)
endif
ifeq ($(MEDIAAGENCIES_STAGE),forward)
LOCAL_MEDIAAGENCIES_STAGE1_STAMP_FILES := $(call list_mediaagencies_files,$(LOCAL_PATH_MEDIAAGENCIES_STAGE1),.stage1.parquet)
LOCAL_MEDIAAGENCIES_FILES := \
    $(LOCAL_MEDIAAGENCIES_STAGE1_STAMP_FILES:$(LOCAL_PATH_MEDIAAGENCIES_STAGE1)/%.stage1.parquet=$(LOCAL_PATH_MEDIAAGENCIES_STAGE2)/%.stage2.parquet)
endif
ifeq ($(MEDIAAGENCIES_STAGE),decode)
LOCAL_MEDIAAGENCIES_STAGE2_STAMP_FILES := $(call list_mediaagencies_files,$(LOCAL_PATH_MEDIAAGENCIES_STAGE2),.stage2.parquet)
LOCAL_MEDIAAGENCIES_FILES := \
    $(LOCAL_MEDIAAGENCIES_STAGE2_STAMP_FILES:$(LOCAL_PATH_MEDIAAGENCIES_STAGE2)/%.stage2.parquet=$(LOCAL_PATH_MEDIAAGENCIES)/%.jsonl.bz2) \
    $(LOCAL_MEDIAAGENCIES_EMPTY_FILES)
endif
  $(call log.debug, LOCAL_MEDIAAGENCIES_FILES)


# TARGET: mediaagencies-target
#: Process newspaper content with media-agency NER (stage set by MEDIAAGENCIES_STAGE)
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
MEDIAAGENCIES_WIP_MAX_AGE ?= 3
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


###
# Stage commands
#------------------------------------------------------------------------------
# Inputs are read directly from S3 ($(call LocalToS3,$<)); outputs are written
# to the local target and uploaded afterwards. The local files are only stamps.

MEDIAAGENCIES_MODEL_OPTIONS = \
    --model-name $(HF_MODEL_MEDIAAGENCIES) \
    --revision $(HF_MODEL_REVISION_MEDIAAGENCIES)

MEDIAAGENCIES_GPU_OPTIONS = \
    --batch-size $(BATCH_SIZE_MEDIAAGENCIES) \
    --precision $(if $(filter float32,$(DTYPE_MEDIAAGENCIES)),fp32,bf16) \
    --device $(if $(filter auto,$(DEVICE_MEDIAAGENCIES)),cuda,$(DEVICE_MEDIAAGENCIES))

MEDIAAGENCIES_FILTER_OPTION = \
    $(if $(filter --filter-anachronistic,$(FILTER_ANACHRONISTIC_MEDIAAGENCIES)),,--no-filter-anachronistic)

MEDIAAGENCIES_CMD_all = $(PYTHON) -m impresso_inference.tasks.mediaagencies.cli.run \
    --input $(call LocalToS3,$<) --output $@ \
    $(MEDIAAGENCIES_MODEL_OPTIONS) $(MEDIAAGENCIES_GPU_OPTIONS) $(MEDIAAGENCIES_FILTER_OPTION)

MEDIAAGENCIES_CMD_prepare = $(PYTHON) -m impresso_inference.tasks.mediaagencies.cli.prepare \
    --input $(call LocalToS3,$<) --output $@ \
    $(MEDIAAGENCIES_MODEL_OPTIONS) --num-workers $(CPU_WORKERS_MEDIAAGENCIES)

MEDIAAGENCIES_CMD_forward = $(PYTHON) -m impresso_inference.tasks.mediaagencies.cli.forward \
    --input $(call LocalToS3,$<) --output $@ \
    $(MEDIAAGENCIES_MODEL_OPTIONS) $(MEDIAAGENCIES_GPU_OPTIONS)

# Mention surfaces are rebuilt exactly from the stage-2 tokens and offsets: the
# rebuilt 'ft' field has only spaces between tokens. Set
# DECODE_TEXT_INPUT_MEDIAAGENCIES=1 to also read the rebuilt input text for spot
# checks (surfaces from the source, offsets verified); it costs extra memory.
DECODE_TEXT_INPUT_MEDIAAGENCIES ?=

MEDIAAGENCIES_DECODE_TEXT_INPUT_OPTION = \
    $(if $(DECODE_TEXT_INPUT_MEDIAAGENCIES),--text-input $(patsubst $(LOCAL_PATH_MEDIAAGENCIES)/%,$(S3_PATH_REBUILT)/%,$@),)

# The decoder reads the content-item IDs of the rebuilt input (not its text) and
# checks each stage-2 ID against them; empty stage-2 IDs are filled by position.
# This repairs stage-2 files whose stage 1 missed the 'ci_id' field (v1-0-0 run:
# all BNF and FedGaz files). The decode stops on a row-count or ID mismatch.
# Set DECODE_ID_INPUT_MEDIAAGENCIES= to skip the check.
DECODE_ID_INPUT_MEDIAAGENCIES ?= 1
  $(call log.debug, DECODE_ID_INPUT_MEDIAAGENCIES)
MEDIAAGENCIES_DECODE_ID_INPUT_OPTION = \
    $(if $(DECODE_ID_INPUT_MEDIAAGENCIES),--id-input $(patsubst $(LOCAL_PATH_MEDIAAGENCIES)/%,$(S3_PATH_REBUILT)/%,$@),)

# Validate every decoded row against the pinned impresso-schemas submodule
# (entities-nel.v2). A failure stops the rule before upload.
# Set DECODE_VALIDATE_SCHEMAS_MEDIAAGENCIES= to skip validation.
DECODE_VALIDATE_SCHEMAS_MEDIAAGENCIES ?= impresso-schemas/json

MEDIAAGENCIES_DECODE_VALIDATE_OPTION = \
    $(if $(DECODE_VALIDATE_SCHEMAS_MEDIAAGENCIES),--validate-schemas $(DECODE_VALIDATE_SCHEMAS_MEDIAAGENCIES),)

# Decode processes per job. 1 decodes in process and streams the stage-2 file in
# blocks (about 1 GB peak on the largest files); run parallel jobs with make -j.
# More workers use a process pool, which bounds memory only on Python 3.14+.
DECODE_WORKERS_MEDIAAGENCIES ?= 1
  $(call log.debug, DECODE_WORKERS_MEDIAAGENCIES)

MEDIAAGENCIES_CMD_decode = $(PYTHON) -m impresso_inference.tasks.mediaagencies.cli.decode \
    --input $(call LocalToS3,$<) --output $@ \
    $(MEDIAAGENCIES_DECODE_TEXT_INPUT_OPTION) $(MEDIAAGENCIES_DECODE_ID_INPUT_OPTION) \
    $(MEDIAAGENCIES_DECODE_VALIDATE_OPTION) \
    $(MEDIAAGENCIES_MODEL_OPTIONS) --num-workers $(DECODE_WORKERS_MEDIAAGENCIES) $(MEDIAAGENCIES_FILTER_OPTION)

MEDIAAGENCIES_CMD_empty = $(PYTHON) -m impresso_inference.tasks.mediaagencies.cli.empty \
    --input $(call LocalToS3,$<) --output $@ \
    --reason "publication year before MIN_YEAR_MEDIAAGENCIES=$(MIN_YEAR_MEDIAAGENCIES)" \
    $(MEDIAAGENCIES_MODEL_OPTIONS) $(MEDIAAGENCIES_DECODE_VALIDATE_OPTION)

# Intermediate parquet buffers are truncated to zero-byte stamps after upload.
MEDIAAGENCIES_UPLOAD_OPTIONS_all :=
MEDIAAGENCIES_UPLOAD_OPTIONS_prepare := --keep-timestamp-only
MEDIAAGENCIES_UPLOAD_OPTIONS_forward := --keep-timestamp-only
MEDIAAGENCIES_UPLOAD_OPTIONS_decode :=
MEDIAAGENCIES_UPLOAD_OPTIONS_empty :=


# FUNCTION: mediaagencies_stage_recipe
# Acquire the S3 WIP lock (or skip if the output exists), run the stage command
# $(MEDIAAGENCIES_CMD_<stage>) with its log in $@.log.gz, upload output and log,
# and release the lock. Args: $(1) stage name.
define mediaagencies_stage_recipe
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
	  $(MEDIAAGENCIES_CMD_$(1)) > $@.log 2>&1 || status=$$? ; \
	  tail -n 3 $@.log ; \
	  gzip -f $@.log || status=$$? ; \
	  if [ "$$status" -eq 0 ] ; then \
	    $(PYTHON) -m impresso_cookbook.local_to_s3 \
	      $(MEDIAAGENCIES_FORCE_OVERWRITE_OPTION) $(MEDIAAGENCIES_UPLOAD_IF_NEWER_OPTION) \
	      $(MEDIAAGENCIES_UPLOAD_OPTIONS_$(1)) \
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
endef


###
# Stage rules (only the selected stage's rule is defined)
#------------------------------------------------------------------------------

ifeq ($(MEDIAAGENCIES_STAGE),all)
$(LOCAL_PATH_MEDIAAGENCIES)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(call mediaagencies_stage_recipe,all)
endif

# Years before MIN_YEAR_MEDIAAGENCIES (all, prepare and decode stages). A static pattern
# rule takes precedence over the implicit rule of the all stage.
ifneq ($(strip $(LOCAL_MEDIAAGENCIES_EMPTY_FILES)),)
$(LOCAL_MEDIAAGENCIES_EMPTY_FILES): $(LOCAL_PATH_MEDIAAGENCIES)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(call mediaagencies_stage_recipe,empty)
endif

ifeq ($(MEDIAAGENCIES_STAGE),prepare)
$(LOCAL_PATH_MEDIAAGENCIES_STAGE1)/%.stage1.parquet: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(call mediaagencies_stage_recipe,prepare)
endif

ifeq ($(MEDIAAGENCIES_STAGE),forward)
$(LOCAL_PATH_MEDIAAGENCIES_STAGE2)/%.stage2.parquet: $(LOCAL_PATH_MEDIAAGENCIES_STAGE1)/%.stage1.parquet
	$(call mediaagencies_stage_recipe,forward)
endif

ifeq ($(MEDIAAGENCIES_STAGE),decode)
$(LOCAL_PATH_MEDIAAGENCIES)/%.jsonl.bz2: $(LOCAL_PATH_MEDIAAGENCIES_STAGE2)/%.stage2.parquet
	$(call mediaagencies_stage_recipe,decode)
endif


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_mediaagencies.mk)
