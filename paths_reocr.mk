$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_reocr.mk)
###############################################################################
# reocr Configuration
###############################################################################

S3_BUCKET_reocr ?= 140-processed-data-sandbox
  $(call log.debug, S3_BUCKET_reocr)

S3_BUCKET_REOCR_INPUT ?= 112-canonical-final
  $(call log.debug, S3_BUCKET_REOCR_INPUT)

PROCESS_LABEL_reocr ?= reocr
  $(call log.debug, PROCESS_LABEL_reocr)

PROCESS_SUBTYPE_LABEL_reocr ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_reocr)

TASK_reocr ?= page-tesseract
  $(call log.debug, TASK_reocr)

MODEL_ID_reocr ?= german_print_20
  $(call log.debug, MODEL_ID_reocr)

HF_TESSERACT_REPO_reocr ?= impresso-project/ocr-models
  $(call log.debug, HF_TESSERACT_REPO_reocr)

HF_TESSERACT_MODEL_reocr ?= german_print_20.traineddata
  $(call log.debug, HF_TESSERACT_MODEL_reocr)

TESSERACT_MODEL_URL_reocr ?= https://raw.githubusercontent.com/JKamlah/german-print-ocr-model/main/data/tesseract/best/german_print/german_print_20.traineddata
  $(call log.debug, TESSERACT_MODEL_URL_reocr)

HF_FONT_REPO_reocr ?=
  $(call log.debug, HF_FONT_REPO_reocr)

HF_FONT_MODEL_reocr ?=
  $(call log.debug, HF_FONT_MODEL_reocr)

REOCR_YEARS ?=
  $(call log.debug, REOCR_YEARS)

RUN_VERSION_reocr ?= v1-0-0
  $(call log.debug, RUN_VERSION_reocr)

RUN_ID_reocr := $(PROCESS_LABEL_reocr)-$(TASK_reocr)-$(MODEL_ID_reocr)_$(RUN_VERSION_reocr)
  $(call log.debug, RUN_ID_reocr)

PATH_REOCR_INPUT := $(S3_BUCKET_REOCR_INPUT)/$(CANONICAL_PATH_SEGMENT)/pages
  $(call log.debug, PATH_REOCR_INPUT)

S3_PATH_REOCR_INPUT := s3://$(PATH_REOCR_INPUT)
  $(call log.debug, S3_PATH_REOCR_INPUT)

LOCAL_PATH_REOCR_INPUT := $(BUILD_DIR)/$(PATH_REOCR_INPUT)
  $(call log.debug, LOCAL_PATH_REOCR_INPUT)

REOCR_INPUT_TITLE := $(notdir $(CANONICAL_PATH_SEGMENT))
  $(call log.debug, REOCR_INPUT_TITLE)

REOCR_INPUT_YEAR_DIRS := $(foreach year,$(REOCR_YEARS),$(REOCR_INPUT_TITLE)-$(year))
  $(call log.debug, REOCR_INPUT_YEAR_DIRS)

REOCR_INPUT_SINGLE_YEAR_DIR := $(if $(filter 1,$(words $(REOCR_INPUT_YEAR_DIRS))),$(firstword $(REOCR_INPUT_YEAR_DIRS)))
  $(call log.debug, REOCR_INPUT_SINGLE_YEAR_DIR)

S3_PATH_REOCR_INPUT_SYNC := $(S3_PATH_REOCR_INPUT)$(if $(REOCR_INPUT_SINGLE_YEAR_DIR),/$(REOCR_INPUT_SINGLE_YEAR_DIR))
  $(call log.debug, S3_PATH_REOCR_INPUT_SYNC)

LOCAL_REOCR_INPUT_SYNC_STAMP_FILES := $(if $(REOCR_INPUT_YEAR_DIRS),$(foreach dir,$(REOCR_INPUT_YEAR_DIRS),$(LOCAL_PATH_REOCR_INPUT)/$(dir).last_synced),$(LOCAL_PATH_REOCR_INPUT).last_synced)
  $(call log.debug, LOCAL_REOCR_INPUT_SYNC_STAMP_FILES)

LOCAL_REOCR_INPUT_SYNC_STAMP_FILE := $(firstword $(LOCAL_REOCR_INPUT_SYNC_STAMP_FILES))
  $(call log.debug, LOCAL_REOCR_INPUT_SYNC_STAMP_FILE)

REOCR_INPUT_FILE_GLOBS := $(if $(REOCR_INPUT_YEAR_DIRS),$(foreach dir,$(REOCR_INPUT_YEAR_DIRS),$(LOCAL_PATH_REOCR_INPUT)/$(dir)/*.jsonl.bz2),$(LOCAL_PATH_REOCR_INPUT)/*/*.jsonl.bz2)
  $(call log.debug, REOCR_INPUT_FILE_GLOBS)

PATH_reocr := $(S3_BUCKET_reocr)/$(PROCESS_LABEL_reocr)$(PROCESS_SUBTYPE_LABEL_reocr)/$(RUN_ID_reocr)/$(CANONICAL_PATH_SEGMENT)
  $(call log.debug, PATH_reocr)

S3_PATH_reocr := s3://$(PATH_reocr)
  $(call log.debug, S3_PATH_reocr)

S3_PATH_reocr_PAGES := $(S3_PATH_reocr)/pages
  $(call log.debug, S3_PATH_reocr_PAGES)

S3_PATH_reocr_PAGES_SYNC := $(S3_PATH_reocr_PAGES)$(if $(REOCR_INPUT_SINGLE_YEAR_DIR),/$(REOCR_INPUT_SINGLE_YEAR_DIR))
  $(call log.debug, S3_PATH_reocr_PAGES_SYNC)

S3_PATH_reocr_STAMPS := $(S3_PATH_reocr)/stamps
  $(call log.debug, S3_PATH_reocr_STAMPS)

S3_PATH_reocr_STAMPS_SYNC := $(S3_PATH_reocr_STAMPS)$(if $(REOCR_INPUT_SINGLE_YEAR_DIR),/$(REOCR_INPUT_SINGLE_YEAR_DIR))
  $(call log.debug, S3_PATH_reocr_STAMPS_SYNC)

S3_PATH_reocr_LOGS := $(S3_PATH_reocr)/logs
  $(call log.debug, S3_PATH_reocr_LOGS)

LOCAL_PATH_reocr := $(BUILD_DIR)/$(PATH_reocr)
  $(call log.debug, LOCAL_PATH_reocr)

LOCAL_PATH_reocr_PAGES := $(LOCAL_PATH_reocr)/pages
  $(call log.debug, LOCAL_PATH_reocr_PAGES)

LOCAL_reocr_PAGES_SYNC_STAMP_FILE := $(LOCAL_PATH_reocr_PAGES)$(if $(REOCR_INPUT_SINGLE_YEAR_DIR),/$(REOCR_INPUT_SINGLE_YEAR_DIR)).last_synced
  $(call log.debug, LOCAL_reocr_PAGES_SYNC_STAMP_FILE)

LOCAL_reocr_PAGES_SYNC_STAMP_FILES := $(if $(REOCR_INPUT_YEAR_DIRS),$(foreach dir,$(REOCR_INPUT_YEAR_DIRS),$(LOCAL_PATH_reocr_PAGES)/$(dir).last_synced),$(LOCAL_PATH_reocr_PAGES).last_synced)
  $(call log.debug, LOCAL_reocr_PAGES_SYNC_STAMP_FILES)

LOCAL_PATH_reocr_STAMPS := $(LOCAL_PATH_reocr)/stamps
  $(call log.debug, LOCAL_PATH_reocr_STAMPS)

LOCAL_reocr_SYNC_STAMP_FILE := $(LOCAL_PATH_reocr_STAMPS)$(if $(REOCR_INPUT_SINGLE_YEAR_DIR),/$(REOCR_INPUT_SINGLE_YEAR_DIR)).last_synced
  $(call log.debug, LOCAL_reocr_SYNC_STAMP_FILE)

LOCAL_reocr_SYNC_STAMP_FILES := $(if $(REOCR_INPUT_YEAR_DIRS),$(foreach dir,$(REOCR_INPUT_YEAR_DIRS),$(LOCAL_PATH_reocr_STAMPS)/$(dir).last_synced),$(LOCAL_PATH_reocr_STAMPS).last_synced)
  $(call log.debug, LOCAL_reocr_SYNC_STAMP_FILES)

LOCAL_PATH_reocr_LOGS := $(LOCAL_PATH_reocr)/logs
  $(call log.debug, LOCAL_PATH_reocr_LOGS)

LOCAL_PATH_reocr_WORK := $(LOCAL_PATH_reocr)/work
  $(call log.debug, LOCAL_PATH_reocr_WORK)

help-path-variables::
	@echo ""
	@echo "RE-OCR INPUT PATHS:"
	@echo "  S3_BUCKET_REOCR_INPUT=$(S3_BUCKET_REOCR_INPUT)"
	@echo "  S3_PATH_REOCR_INPUT=$(S3_PATH_REOCR_INPUT)"
	@echo "  S3_PATH_REOCR_INPUT_SYNC=$(S3_PATH_REOCR_INPUT_SYNC)"
	@echo "  LOCAL_PATH_REOCR_INPUT=$(LOCAL_PATH_REOCR_INPUT)"
	@echo "  LOCAL_REOCR_INPUT_SYNC_STAMP_FILES=$(LOCAL_REOCR_INPUT_SYNC_STAMP_FILES)"
	@echo "  LOCAL_REOCR_INPUT_SYNC_STAMP_FILE=$(LOCAL_REOCR_INPUT_SYNC_STAMP_FILE)"
	@echo "  REOCR_YEARS=$(REOCR_YEARS)"
	@echo "  REOCR_INPUT_FILE_GLOBS=$(REOCR_INPUT_FILE_GLOBS)"
	@echo ""
	@echo "RE-OCR OUTPUT PATHS:"
	@echo "  S3_BUCKET_reocr=$(S3_BUCKET_reocr)"
	@echo "  PROCESS_LABEL_reocr=$(PROCESS_LABEL_reocr)"
	@echo "  PROCESS_SUBTYPE_LABEL_reocr=$(PROCESS_SUBTYPE_LABEL_reocr)"
	@echo "  TASK_reocr=$(TASK_reocr)"
	@echo "  MODEL_ID_reocr=$(MODEL_ID_reocr)"
	@echo "  RUN_VERSION_reocr=$(RUN_VERSION_reocr)"
	@echo "  RUN_ID_reocr=$(RUN_ID_reocr)"
	@echo "  S3_PATH_reocr=$(S3_PATH_reocr)"
	@echo "  S3_PATH_reocr_PAGES=$(S3_PATH_reocr_PAGES)"
	@echo "  S3_PATH_reocr_PAGES_SYNC=$(S3_PATH_reocr_PAGES_SYNC)"
	@echo "  S3_PATH_reocr_STAMPS=$(S3_PATH_reocr_STAMPS)"
	@echo "  S3_PATH_reocr_STAMPS_SYNC=$(S3_PATH_reocr_STAMPS_SYNC)"
	@echo "  S3_PATH_reocr_LOGS=$(S3_PATH_reocr_LOGS)"
	@echo "  LOCAL_PATH_reocr=$(LOCAL_PATH_reocr)"
	@echo "  LOCAL_PATH_reocr_PAGES=$(LOCAL_PATH_reocr_PAGES)"
	@echo "  LOCAL_reocr_PAGES_SYNC_STAMP_FILES=$(LOCAL_reocr_PAGES_SYNC_STAMP_FILES)"
	@echo "  LOCAL_reocr_PAGES_SYNC_STAMP_FILE=$(LOCAL_reocr_PAGES_SYNC_STAMP_FILE)"
	@echo "  LOCAL_PATH_reocr_STAMPS=$(LOCAL_PATH_reocr_STAMPS)"
	@echo "  LOCAL_reocr_SYNC_STAMP_FILES=$(LOCAL_reocr_SYNC_STAMP_FILES)"
	@echo "  LOCAL_reocr_SYNC_STAMP_FILE=$(LOCAL_reocr_SYNC_STAMP_FILE)"
	@echo "  LOCAL_PATH_reocr_LOGS=$(LOCAL_PATH_reocr_LOGS)"
	@echo "  LOCAL_PATH_reocr_WORK=$(LOCAL_PATH_reocr_WORK)"
	@echo ""
	@echo "RE-OCR MODEL SETTINGS:"
	@echo "  HF_TESSERACT_REPO_reocr=$(HF_TESSERACT_REPO_reocr)"
	@echo "  HF_TESSERACT_MODEL_reocr=$(HF_TESSERACT_MODEL_reocr)"
	@echo "  TESSERACT_MODEL_URL_reocr=$(TESSERACT_MODEL_URL_reocr)"
	@echo "  HF_FONT_REPO_reocr=$(HF_FONT_REPO_reocr)"
	@echo "  HF_FONT_MODEL_reocr=$(HF_FONT_MODEL_reocr)"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_reocr.mk)
