$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_canonical.mk)
###############################################################################
# Sync Canonical Pages Data
# Targets for synchronizing canonical pages data from S3 to local storage
#
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

# USER-VARIABLE: LOCAL_CANONICAL_STAMP_SUFFIX
# The suffix for the local stamp files (added to the input paths from S3)
#
# This suffix is appended to local stamp files to track synchronization
# status and avoid unnecessary re-downloads of unchanged data.
# Legacy variable - kept for compatibility; default is '.stamp' to avoid file/directory conflicts
LOCAL_CANONICAL_STAMP_SUFFIX ?= .stamp
  $(call log.debug, LOCAL_CANONICAL_STAMP_SUFFIX)


# VARIABLE: LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE
# Local synchronization stamp file for canonical pages input data
#
# This file serves as a timestamp marker indicating when the canonical
# pages data was last successfully synchronized from S3 storage.
LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE := $(LOCAL_PATH_CANONICAL_PAGES).last_synced
  $(call log.debug, LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)


# TARGET: sync-canonical
#: Synchronize canonical pages input data from S3 to local storage
#
# This target ensures that the canonical pages data is available locally
# by triggering the synchronization process if needed. It depends on the
# stamp file to determine if synchronization is required.
sync-canonical: $(LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)

.PHONY: sync-canonical

# STAMPED-FILE-RULE: $(LOCAL_PATH_CANONICAL_PAGES).last_synced
#: Sync canonical pages data from S3 and create synchronization stamp
#
# Downloads canonical pages data from the S3 bucket to the local directory
# using the impresso_cookbook.s3_to_local_stamps module. Creates stamp files
# to track individual file synchronization and a master stamp file upon completion.
$(LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE):
	# creating $@ 
	mkdir -p $(@D) \
	&& \
	python -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_CANONICAL_PAGES) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension '$(LOCAL_CANONICAL_STAMP_SUFFIX)' \
	   --stamp-api v2 \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& \
	touch $@

  $(call log.debug,LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_canonical.mk)
