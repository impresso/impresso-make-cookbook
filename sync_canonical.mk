$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_canonical.mk)
###############################################################################
# Sync Canonical Pages Data
# Targets for synchronizing canonical pages data from S3 to local storage
#
#

# This module provides functionality to sync canonical pages data from S3
# storage to local directories using stamp files to track synchronization
# status. Subsumes all sync-input targets from the necessary inputs.
#
# CONFIGURATION FLAGS:
# ====================
# USE_CANONICAL: Set to 1 to use canonical format (default: 1)
# NEWSPAPER_HAS_PROVIDER: Set to 1 if newspapers organized with PROVIDER level (default: 1)
# NEWSPAPER_FNMATCH: Pattern to filter newspapers (e.g., BL/*, SWA/*, */WTCH)
#
# S3 STRUCTURE AND LOCAL STAMP MAPPING:
# =====================================
# S3 data is organized hierarchically by provider, then newspaper, with pages and issues:
# In this example, the newspaper "AATA" from the "BL" data provider library is used:
#
#   s3://112-canonical-final/BL/AATA/
#   ├── pages/
#   │   ├── AATA-1846/
#   │   │   ├── AATA-1846-02-07-a-pages.jsonl.bz2
#   │   │   ├── AATA-1846-02-14-a-pages.jsonl.bz2
#   │   │   └── ...
#   │   ├── AATA-1847/
#   │   │   └── ...
#   │   └── ...
#   └── issues/
#       ├── AATA-1846-issues.jsonl.bz2
#       ├── AATA-1847-issues.jsonl.bz2
#       └── ...
#
# Local pages stamps are created at the yearly level (same level as issues metadata),
# not at the indivual pages per issues level:
#
#   build.d/112-canonical-final/BL/AATA/
#   └── pages/
#       ├── AATA-1846.stamp          <- Tracks sync status for all AATA-1846 pages
#       ├── AATA-1847.stamp          <- Tracks sync status for all AATA-1847 pages
#       ├── ...
#       └── pages.last_synced        <- Master sync stamp file for all pages per year data
#
###############################################################################

# USER-VARIABLE: USE_CANONICAL
# Flag to indicate using canonical format instead of rebuilt format
# Set to 1 to enable canonical format processing
USE_CANONICAL ?= 1
  $(call log.debug, USE_CANONICAL)


# USER-VARIABLE: NEWSPAPER_HAS_PROVIDER
# Flag to indicate if newspapers are organized with PROVIDER level in S3
# Set to 1 if structure is PROVIDER/NEWSPAPER, 0 if just NEWSPAPER
NEWSPAPER_HAS_PROVIDER ?= 1
  $(call log.debug, NEWSPAPER_HAS_PROVIDER)


# USER-VARIABLE: NEWSPAPER_FNMATCH
# Pattern to filter newspapers for processing
# Examples: BL/*, SWA/*, */WTCH, BL/AATA
# Leave empty to process all newspapers
NEWSPAPER_FNMATCH ?=
  $(call log.debug, NEWSPAPER_FNMATCH)


# VARIABLE: LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE
# Local synchronization stamp file for canonical pages input data
#
# This file serves as a timestamp marker indicating when the canonical
# pages data was last successfully synchronized from S3 storage.
LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE := $(call newspaper_sync_stamp_targets,$(LOCAL_PATH_CANONICAL_PAGES))
$(call expand_newspaper_year_sync_targets,$(LOCAL_PATH_CANONICAL_PAGES))
  $(call log.debug, LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)

# VARIABLE: LOCAL_CANONICAL_AUDIOS_SYNC_STAMP_FILE
# Local synchronization stamp file for canonical audio input data.
LOCAL_CANONICAL_AUDIOS_SYNC_STAMP_FILE := $(call newspaper_sync_stamp_targets,$(LOCAL_PATH_CANONICAL_AUDIOS))
$(call expand_newspaper_year_sync_targets,$(LOCAL_PATH_CANONICAL_AUDIOS))
  $(call log.debug, LOCAL_CANONICAL_AUDIOS_SYNC_STAMP_FILE)

CANONICAL_SYNC_TITLE := $(notdir $(NEWSPAPER))
  $(call log.debug, CANONICAL_SYNC_TITLE)

# VARIABLE: LOCAL_CANONICAL_INPUT_SYNC_STAMP_FILES
# Selected canonical synchronization stamps. In auto mode, sync both record
# layouts and let the discovered stamps decide which files feed processing.
ifeq ($(CANONICAL_INPUT_KIND),audios)
LOCAL_CANONICAL_INPUT_SYNC_STAMP_FILES := $(LOCAL_CANONICAL_AUDIOS_SYNC_STAMP_FILE)
LOCAL_CANONICAL_INPUT_SYNC_TARGETS := sync-canonical-audios
else ifeq ($(CANONICAL_INPUT_KIND),pages)
LOCAL_CANONICAL_INPUT_SYNC_STAMP_FILES := $(LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)
LOCAL_CANONICAL_INPUT_SYNC_TARGETS := sync-canonical-pages
else
LOCAL_CANONICAL_INPUT_SYNC_STAMP_FILES := $(LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE) $(LOCAL_CANONICAL_AUDIOS_SYNC_STAMP_FILE)
LOCAL_CANONICAL_INPUT_SYNC_TARGETS := sync-canonical-pages sync-canonical-audios
endif
  $(call log.debug, LOCAL_CANONICAL_INPUT_SYNC_STAMP_FILES)
  $(call log.debug, LOCAL_CANONICAL_INPUT_SYNC_TARGETS)

# TARGET: sync-canonical
#: Synchronize canonical pages/audio input data from S3 to local storage
#
# Phony operation: always queries S3 when explicitly requested. The selected
# child operation targets are controlled by CANONICAL_INPUT_KIND.
sync-canonical: $(LOCAL_CANONICAL_INPUT_SYNC_TARGETS)

.PHONY: sync-canonical sync-canonical-pages sync-canonical-audios

clean-sync-input:: clean-sync-canonical

clean-sync-canonical:
	rm -vf \
	  $(call newspaper_sync_clean_files,$(LOCAL_PATH_CANONICAL_PAGES)) \
	  $(call newspaper_sync_clean_files,$(LOCAL_PATH_CANONICAL_AUDIOS)) \
	  || true

.PHONY: clean-sync-canonical

help-sync::
	@echo ""
	@echo "CANONICAL INPUT SYNC:"
	@echo "  sync-canonical # Synchronize canonical pages/audio input data from S3"
	@echo "                 # Set NEWSPAPER_YEARS='1850 1875' to limit sync/processing to selected years"

help-clean::
	@echo "  clean-sync-canonical # Remove local canonical input sync stamp files"

# STAMPED-FILE-RULE: $(LOCAL_PATH_CANONICAL_PAGES).last_synced
#: Sync canonical pages data from S3 and create synchronization stamp
#
# Persistent marker updated after successful synchronization. Used by
# downstream targets for dependency/timestamp tracking. Requesting this marker,
# sync-canonical, or sync-canonical-pages ensures the selected sync markers
# exist; use -B to force a fresh S3 query.
sync-canonical-pages: $(LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)

$(LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE):
	# creating $@
	$(call sync_year_aware_per_directory_stamps,$(S3_PATH_CANONICAL_PAGES),$@,$(CANONICAL_SYNC_TITLE),--directory-level 1 --remove-dangling-stamps --log-level $(LOGGING_LEVEL))

# Creates directory-level stamp files (with .stamp suffix) to track synchronization
# of yearly page collections. One stamp file is created per year (e.g., AATA-1846.stamp),
# with its modification timestamp set to the most recent modification time among all
# page files within that year's directory on S3. This allows Make to detect updates
# without downloading actual page data - the langident processing reads pages directly
# from S3 using the year directory as a prefix pattern.
  $(call log.debug,LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)

# STAMPED-FILE-RULE: $(LOCAL_PATH_CANONICAL_AUDIOS).last_synced
#: Sync canonical audio data from S3 and create synchronization stamp
#
# Persistent marker updated after successful synchronization. Used by
# downstream targets for dependency/timestamp tracking. Requesting this marker,
# sync-canonical, or sync-canonical-audios ensures the selected sync markers
# exist; use -B to force a fresh S3 query.
sync-canonical-audios: $(LOCAL_CANONICAL_AUDIOS_SYNC_STAMP_FILE)

$(LOCAL_CANONICAL_AUDIOS_SYNC_STAMP_FILE):
	# creating $@
	$(call sync_year_aware_per_directory_stamps,$(S3_PATH_CANONICAL_AUDIOS),$@,$(CANONICAL_SYNC_TITLE),--directory-level 1 --remove-dangling-stamps --log-level $(LOGGING_LEVEL))

# Creates directory-level stamp files (with .stamp suffix) to track synchronization
# of yearly audio record collections.
  $(call log.debug,LOCAL_CANONICAL_AUDIOS_SYNC_STAMP_FILE)

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_canonical.mk)
