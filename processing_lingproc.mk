$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_lingproc.mk)
###############################################################################
# LINGUISTIC PROCESSING TARGETS
# Targets for processing newspaper content with linguistic analysis
###############################################################################

# DOUBLE-COLON-TARGET: lingproc-target
processing-target :: lingproc-target


sync-input :: sync-rebuilt


sync-output :: sync-lingproc


# === USER-CONFIGURABLE VARIABLES =============================================

# USER-VARIABLE: LINGPROC_LOGGING_LEVEL
# Option to specify logging level for linguistic processing.
#
# Uses the global LOGGING_LEVEL as default, can be overridden for lingproc-specific logging.
LINGPROC_LOGGING_LEVEL ?= $(LOGGING_LEVEL)
  $(call log.debug, LINGPROC_LOGGING_LEVEL)

# USER-VARIABLE: LINGPROC_VALIDATE_OPTION
# Option to enable schema validation of the output
#
# Set to no value or $(EMPTY) for preventing JSON schema validation
# LINGPROC_VALIDATE_OPTION ?= $(EMPTY)
LINGPROC_VALIDATE_OPTION ?= --validate
  $(call log.debug, LINGPROC_VALIDATE_OPTION)

# USER-VARIABLE: LINGPROC_QUIET_OPTION
# Reserved for quiet processing mode (@TODO: Implement in script)
LINGPROC_QUIET_OPTION ?= 
  $(call log.debug, LINGPROC_QUIET_OPTION)

# === USER-CONFIGURABLE VARIABLES (Work-In-Progress Management) ===============

# USER-VARIABLE: LINGPROC_WIP_ENABLED
# Option to enable work-in-progress (WIP) file management to prevent concurrent processing.
#
# Set to 1 to enable WIP checks, or leave empty to disable
# When enabled, the system will:
# - Check for existing WIP files on S3 before starting processing
# - Create WIP files to signal work in progress
# - Remove stale WIP files (older than LINGPROC_WIP_MAX_AGE)
# - Remove WIP files after successful completion
LINGPROC_WIP_ENABLED ?= 1
  $(call log.debug, LINGPROC_WIP_ENABLED)

# USER-VARIABLE: LINGPROC_WIP_MAX_AGE
# Maximum age in hours for WIP files before considering them stale.
#
# If a WIP file is older than this value, it will be removed and processing can proceed.
# Can be fractional (e.g., 0.1 for 6 minutes, useful for testing).
# Default: 1 hour
LINGPROC_WIP_MAX_AGE ?= 1
  $(call log.debug, LINGPROC_WIP_MAX_AGE)

# USER-VARIABLE: LINGPROC_UPLOAD_IF_NEWER_OPTION
# Option to control S3 upload behavior based on timestamps.
#
# Set to --upload-if-newer to upload only if local timestamp is newer than S3,
# or leave empty to skip upload (file metadata only will be updated).
# Note: Without --force-write, files are not uploaded to S3 by default.
# This is useful when you want to update S3 when local files have changed without
# forcing overwrite of content-wise unchanged files.
# LINGPROC_UPLOAD_IF_NEWER_OPTION ?= --upload-if-newer
LINGPROC_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, LINGPROC_UPLOAD_IF_NEWER_OPTION)

# USER-VARIABLE: LINGPROC_FORCE_OVERWRITE_OPTION
# Option to force S3 overwrite of existing linguistic processing outputs.
#
# Set to --force-overwrite to process and upload even when S3 output exists.
LINGPROC_FORCE_OVERWRITE_OPTION ?=
  $(call log.debug, LINGPROC_FORCE_OVERWRITE_OPTION)

# USER-VARIABLE: LINGPROC_FORCE_UPLOAD_OPTION
# Backward-compatible alias for LINGPROC_FORCE_OVERWRITE_OPTION.
LINGPROC_FORCE_UPLOAD_OPTION ?= $(LINGPROC_FORCE_OVERWRITE_OPTION)
  $(call log.debug, LINGPROC_FORCE_UPLOAD_OPTION)

LINGPROC_EFFECTIVE_FORCE_OVERWRITE_OPTION := $(or $(LINGPROC_FORCE_OVERWRITE_OPTION),$(LINGPROC_FORCE_UPLOAD_OPTION))
  $(call log.debug, LINGPROC_EFFECTIVE_FORCE_OVERWRITE_OPTION)

# VARIABLE: LINGPROC_WIP_FORCE_OPTION
# Internal flag to force WIP acquisition when either force-overwrite or upload-if-newer is enabled.
# Defined after LINGPROC_UPLOAD_IF_NEWER_OPTION to ensure immediate evaluation picks up its value.
LINGPROC_WIP_FORCE_OPTION := $(if $(or $(LINGPROC_EFFECTIVE_FORCE_OVERWRITE_OPTION),$(LINGPROC_UPLOAD_IF_NEWER_OPTION)),--force,)
  $(call log.debug, LINGPROC_WIP_FORCE_OPTION)

# USER-VARIABLE: LINGPROC_SKIP_IF_OUTPUT_EXISTS_OPTION
# Retained for compatibility with generic pipeline interfaces.
# By default, existing S3 output is skipped during preflight (both with and without WIP enabled)
# unless LINGPROC_FORCE_OVERWRITE_OPTION or LINGPROC_UPLOAD_IF_NEWER_OPTION is active.
PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION ?=
LINGPROC_SKIP_IF_OUTPUT_EXISTS_OPTION ?= $(PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION)
  $(call log.debug, LINGPROC_SKIP_IF_OUTPUT_EXISTS_OPTION)

# === INTERNAL COMPUTED VARIABLES ==============================================


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
# Rebuilt stamps match S3 file names exactly (no suffix)
LOCAL_REBUILT_STAMP_FILES := \
    $(call filter_newspaper_year_files,$(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat)))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltToLingprocFile
# Converts a local rebuilt stamp file name to a local linguistic processing file name
# Rebuilt stamps match S3 file names exactly (no suffix)
define LocalRebuiltToLingprocFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_LINGPROC)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_LINGPROC_FILES
# Stores the list of linguistic processing files based on rebuilt stamp files
LOCAL_LINGPROC_FILES := \
    $(call LocalRebuiltToLingprocFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_LINGPROC_FILES)

# TARGET: lingproc-target
#: Processes newspaper content with linguistic analysis
#
# Just uses the local data that is there, does not enforce synchronization
lingproc-target: $(LOCAL_LINGPROC_FILES)

.PHONY: lingproc-target

help-processing::
	@echo "LINGUISTIC PROCESSING:"
	@echo "  lingproc-target   # Process rebuilt newspaper content with linguistic analysis"
	@echo "                    # Also contributes to processing-target"
	@echo ""
	@echo "LINGPROC VARIABLES:"
	@echo "  LINGPROC_LOGGING_LEVEL=$(LINGPROC_LOGGING_LEVEL)"
	@echo "  LINGPROC_VALIDATE_OPTION=$(LINGPROC_VALIDATE_OPTION)"
	@echo "  LINGPROC_WIP_ENABLED=$(LINGPROC_WIP_ENABLED)"
	@echo "  LINGPROC_WIP_MAX_AGE=$(LINGPROC_WIP_MAX_AGE)"
	@echo "  LINGPROC_UPLOAD_IF_NEWER_OPTION=$(LINGPROC_UPLOAD_IF_NEWER_OPTION)"
	@echo "  LINGPROC_FORCE_OVERWRITE_OPTION=$(LINGPROC_FORCE_OVERWRITE_OPTION)"
	@echo "  LINGPROC_FORCE_UPLOAD_OPTION=$(LINGPROC_FORCE_UPLOAD_OPTION)"
	@echo "  LINGPROC_SKIP_IF_OUTPUT_EXISTS_OPTION=$(LINGPROC_SKIP_IF_OUTPUT_EXISTS_OPTION)"

LINGPROC_LANGIDENT_NEEDED ?= 1
  $(call log.debug, LINGPROC_LANGIDENT_NEEDED)


ifeq ($(LINGPROC_LANGIDENT_NEEDED),1)
# FILE-RULE: $(LOCAL_PATH_LINGPROC)/%.jsonl.bz2
#: Rule to process a single newspaper with language identification
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
$(LOCAL_PATH_LINGPROC)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2 $(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{ acquired_wip=0 ; \
	  status=0 ; \
	  if [ -n "$(LINGPROC_WIP_ENABLED)" ] ; then \
	    python3 -m impresso_cookbook.manage_s3_wip acquire \
	      --s3-target $(call LocalToS3,$@) \
	      --wip-max-age $(LINGPROC_WIP_MAX_AGE) \
	      --log-level $(LINGPROC_LOGGING_LEVEL) \
	      --local-target $@ \
	      --files $@ $@.log.gz \
	      $(LINGPROC_WIP_FORCE_OPTION) || status=$$? ; \
	    case "$$status" in \
	      0) acquired_wip=1 ;; \
	      2|3) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  elif [ -z "$(LINGPROC_EFFECTIVE_FORCE_OVERWRITE_OPTION)" ] && [ -z "$(LINGPROC_UPLOAD_IF_NEWER_OPTION)" ] ; then \
	    python3 -m impresso_cookbook.local_to_s3 \
	      --s3-file-exists $(call LocalToS3,$@) \
	      --exit-2-if-exists \
	      --log-level $(LINGPROC_LOGGING_LEVEL) || status=$$? ; \
	    case "$$status" in \
	      0) ;; \
	      2|3) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  fi ; \
	  status=0 ; \
	  python3 lib/spacy_linguistic_processing.py \
	    $(call LocalToS3,$<) \
	    --lid $(call LocalToS3,$(word 2,$^)) \
	    $(LINGPROC_VALIDATE_OPTION) \
	    --git-version $(GIT_VERSION) \
	    $(LINGPROC_QUIET_OPTION) \
	    -o $@ \
	    --log-level $(LINGPROC_LOGGING_LEVEL) \
	    --log-file $@.log.gz || status=$$? ; \
	  if [ "$$status" -eq 0 ] ; then \
	    python3 -m impresso_cookbook.local_to_s3 \
	      --set-timestamp \
	      $(LINGPROC_UPLOAD_IF_NEWER_OPTION) \
	      $(LINGPROC_EFFECTIVE_FORCE_OVERWRITE_OPTION) \
	      --log-level $(LINGPROC_LOGGING_LEVEL) \
	      $@ $(call LocalToS3,$@) \
	      $@.log.gz $(call LocalToS3,$@).log.gz || status=$$? ; \
	  fi ; \
	  if [ "$$status" -ne 0 ] ; then \
	    rm -f $@ || true ; \
	  fi ; \
	  release_status=0 ; \
	  if [ "$$acquired_wip" -eq 1 ] ; then \
	    python3 -m impresso_cookbook.manage_s3_wip release \
	      --s3-target $(call LocalToS3,$@) \
	      --log-level $(LINGPROC_LOGGING_LEVEL) || release_status=$$? ; \
	  fi ; \
	  if [ "$$status" -ne 0 ] ; then \
	    exit "$$status" ; \
	  fi ; \
	  exit "$$release_status" ; \
	}
else
# FILE-RULE: $(LOCAL_PATH_LINGPROC)/%.jsonl.bz2
#: Rule to process a single newspaper without language identification
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
#: Trusts the lg property inside the rebuilt file
$(LOCAL_PATH_LINGPROC)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{ acquired_wip=0 ; \
	  status=0 ; \
	  if [ -n "$(LINGPROC_WIP_ENABLED)" ] ; then \
	    python3 -m impresso_cookbook.manage_s3_wip acquire \
	      --s3-target $(call LocalToS3,$@) \
	      --wip-max-age $(LINGPROC_WIP_MAX_AGE) \
	      --log-level $(LINGPROC_LOGGING_LEVEL) \
	      --local-target $@ \
	      --files $@ $@.log.gz \
	      $(LINGPROC_WIP_FORCE_OPTION) || status=$$? ; \
	    case "$$status" in \
	      0) acquired_wip=1 ;; \
	      2|3) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  elif [ -z "$(LINGPROC_EFFECTIVE_FORCE_OVERWRITE_OPTION)" ] && [ -z "$(LINGPROC_UPLOAD_IF_NEWER_OPTION)" ] ; then \
	    python3 -m impresso_cookbook.local_to_s3 \
	      --s3-file-exists $(call LocalToS3,$@) \
	      --exit-2-if-exists \
	      --log-level $(LINGPROC_LOGGING_LEVEL) || status=$$? ; \
	    case "$$status" in \
	      0) ;; \
	      2|3) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  fi ; \
	  status=0 ; \
	  python3 lib/spacy_linguistic_processing.py \
	    $(call LocalToS3,$<) \
	    $(LINGPROC_VALIDATE_OPTION) \
	    --max-doc-length 100000 \
	    --git-version $(GIT_VERSION) \
	    $(LINGPROC_QUIET_OPTION) \
	    -o $@ \
	    --log-level $(LINGPROC_LOGGING_LEVEL) \
	    --log-file $@.log.gz || status=$$? ; \
	  if [ "$$status" -eq 0 ] ; then \
	    python3 -m impresso_cookbook.local_to_s3 \
	      --set-timestamp \
	      $(LINGPROC_UPLOAD_IF_NEWER_OPTION) \
	      $(LINGPROC_EFFECTIVE_FORCE_OVERWRITE_OPTION) \
	      --log-level $(LINGPROC_LOGGING_LEVEL) \
	      $@ $(call LocalToS3,$@) \
	      $@.log.gz $(call LocalToS3,$@).log.gz || status=$$? ; \
	  fi ; \
	  if [ "$$status" -ne 0 ] ; then \
	    rm -f $@ || true ; \
	  fi ; \
	  release_status=0 ; \
	  if [ "$$acquired_wip" -eq 1 ] ; then \
	    python3 -m impresso_cookbook.manage_s3_wip release \
	      --s3-target $(call LocalToS3,$@) \
	      --log-level $(LINGPROC_LOGGING_LEVEL) || release_status=$$? ; \
	  fi ; \
	  if [ "$$status" -ne 0 ] ; then \
	    exit "$$status" ; \
	  fi ; \
	  exit "$$release_status" ; \
	}
endif

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_lingproc.mk)
