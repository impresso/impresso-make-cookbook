$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_bboxqa.mk)
###############################################################################
# BBOX QUALITY ASSESSMENT TARGETS
# Targets for processing newspaper content with BBOX quality assessment
###############################################################################

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes BBOX quality assessment input data
sync-input :: sync-canonical


# DOUBLE-COLON-TARGET: sync-output
# Synchronizes BBOX quality assessment output data
sync-output :: sync-bboxqa


# DOUBLE-COLON-TARGET: bboxqa-target
processing-target :: bboxqa-target

# Newspaper-level processing output used by show-delete-newspaper-s3.
S3_DELETE_NEWSPAPER_PREFIX ?= $(S3_PATH_BBOXQA)


#BBOXQA_IIIF_GALLICA_V3_OPTION ?= --iiif-gallica-v3
BBOXQA_IIIF_GALLICA_V3_OPTION ?= $(EMPTY)
  $(call log.debug, #BBOXQA_IIIF_GALLICA_V3_OPTION ?= --iiif-gallica-v3)

# VARIABLE: CANONICAL_PAGES_STAMP_FILES
# Stores all canonical stamp files for dependency tracking
# Canonical stamps have hard-coded .stamp suffix for yearly directories
CANONICAL_PAGES_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_CANONICAL_PAGES)/*.stamp 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, CANONICAL_PAGES_STAMP_FILES)

# FUNCTION: CanonicalPagesToBboxqaFile
# Converts a canonical stamp file name to a local BBOX quality assessment file name
# Canonical stamps have hard-coded .stamp suffix
define CanonicalPagesToBboxqaFile
$(1:$(LOCAL_PATH_CANONICAL_PAGES)/%.stamp=$(LOCAL_PATH_BBOXQA)/%.jsonl.bz2)
endef

# VARIABLE: LOCAL_BBOXQA_FILES
# Stores the list of BBOX quality assessment files based on canonical stamp files
LOCAL_BBOXQA_FILES := \
    $(call CanonicalPagesToBboxqaFile,$(CANONICAL_PAGES_STAMP_FILES))

  $(call log.debug, LOCAL_BBOXQA_FILES)

# TARGET: bboxqa-target
#: Processes newspaper content with BBOX quality assessment
#
# Just uses the local data that is there, does not enforce synchronization
bboxqa-target: $(LOCAL_BBOXQA_FILES)

.PHONY: bboxqa-target

###
# S3 preflight and WIP lifecycle
#------------------------------------------------------------------------------

# USER-VARIABLE: BBOXQA_WIP_ENABLED
# Enable WIP locking; set empty to disable locking (existence checks remain).
BBOXQA_WIP_ENABLED ?= 1
  $(call log.debug, BBOXQA_WIP_ENABLED)

# USER-VARIABLE: BBOXQA_WIP_MAX_AGE
# Lock expiry in hours; choose longer than one complete processing/upload run.
BBOXQA_WIP_MAX_AGE ?= 24
  $(call log.debug, BBOXQA_WIP_MAX_AGE)

# USER-VARIABLE: BBOXQA_FORCE_OVERWRITE_OPTION
# Set to --force-overwrite to replace existing S3 output.
BBOXQA_FORCE_OVERWRITE_OPTION ?=
  $(call log.debug, BBOXQA_FORCE_OVERWRITE_OPTION)

# USER-VARIABLE: BBOXQA_UPLOAD_IF_NEWER_OPTION
# Set to --upload-if-newer to allow processing and compare timestamps at upload.
BBOXQA_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, BBOXQA_UPLOAD_IF_NEWER_OPTION)

# Bypass output existence only; active WIP locks still cause a skip.
BBOXQA_WIP_FORCE_OPTION = $(if $(or $(BBOXQA_FORCE_OVERWRITE_OPTION),$(BBOXQA_UPLOAD_IF_NEWER_OPTION)),--force,)

help-processing::
	@echo "BBOXQA S3/WIP OPTIONS:"
	@echo "  BBOXQA_WIP_ENABLED=$(BBOXQA_WIP_ENABLED)"
	@echo "  BBOXQA_WIP_MAX_AGE=$(BBOXQA_WIP_MAX_AGE)"
	@echo "  BBOXQA_FORCE_OVERWRITE_OPTION=$(BBOXQA_FORCE_OVERWRITE_OPTION)"
	@echo "  BBOXQA_UPLOAD_IF_NEWER_OPTION=$(BBOXQA_UPLOAD_IF_NEWER_OPTION)"

# FILE-RULE: $(LOCAL_PATH_BBOXQA)/%.jsonl.bz2
#: Rule to process a single newspaper year file
#: Canonical stamps have hard-coded .stamp suffix
$(LOCAL_PATH_BBOXQA)/%.jsonl.bz2: $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{ acquired_wip=0 ; \
	  status=0 ; \
	  if [ -n "$(BBOXQA_WIP_ENABLED)" ] ; then \
	    python3 -m impresso_cookbook.manage_s3_wip acquire \
	      --s3-target $(call LocalToS3,$@) \
	      --wip-max-age $(BBOXQA_WIP_MAX_AGE) \
	      --log-level $(LOGGING_LEVEL) \
	      --local-target $@ \
	      --files $@ $@.log.gz \
	      $(BBOXQA_WIP_FORCE_OPTION) || status=$$? ; \
	    case "$$status" in \
	      0) acquired_wip=1 ;; \
	      2|3) exit 0 ;; \
	      *) exit "$$status" ;; \
	    esac ; \
	  elif [ -z "$(BBOXQA_FORCE_OVERWRITE_OPTION)" ] && [ -z "$(BBOXQA_UPLOAD_IF_NEWER_OPTION)" ] ; then \
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
	  python3 lib/bboxqa.py \
	    --git_version $(GIT_VERSION) \
	    --output $@ \
	    --log-file $@.log.gz \
	    $(call LocalToS3,$<,.stamp) || status=$$? ; \
	  if [ "$$status" -eq 0 ] ; then \
	    python3 -m impresso_cookbook.local_to_s3 \
	      $(BBOXQA_FORCE_OVERWRITE_OPTION) $(BBOXQA_UPLOAD_IF_NEWER_OPTION) \
	      $(PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION) \
	      --set-timestamp \
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


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_bboxqa.mk)
