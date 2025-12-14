$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_consolidatedcanonical.mk)

###############################################################################
# SYNC consolidatedcanonical processing TARGETS
# Targets for synchronizing data for consolidatedcanonical processing
#
# This module synchronizes three types of data:
# 1. Canonical input data (issues and pages) from s3://112-canonical-final/CANONICAL_PATH_SEGMENT/
#    (synced via sync-canonical target from sync_canonical.mk)
# 2. Langident/OCRQA enrichment data from s3://115-canonical-processed-final/langident/RUN_ID/CANONICAL_PATH_SEGMENT/
#    (synced via sync-langident target from sync_langident.mk)
# 3. Consolidated output data from s3://118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/
#    (synced via sync-consolidatedcanonical target below - both issues and pages)
#
# PATH STRUCTURE:
# ==============
# The consolidated canonical structure mirrors the canonical structure with a VERSION prefix:
#
# Canonical input:  s3://112-canonical-final/CANONICAL_PATH_SEGMENT/issues/
#                   s3://112-canonical-final/CANONICAL_PATH_SEGMENT/pages/
# Enrichment:       s3://115-canonical-processed-final/langident/RUN_ID/CANONICAL_PATH_SEGMENT/
# Consolidated out: s3://118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/issues/
#                   s3://118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/pages/
#
# Where CANONICAL_PATH_SEGMENT can be:
#   - PROVIDER/NEWSPAPER (e.g., BL/WTCH) when NEWSPAPER_HAS_PROVIDER=1
#   - NEWSPAPER (e.g., WTCH) when NEWSPAPER_HAS_PROVIDER=0
###############################################################################


# VARIABLE: LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed consolidatedcanonical processing data
LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE := $(LOCAL_PATH_CONSOLIDATEDCANONICAL).last_synced
  $(call log.debug, LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE)

# VARIABLE: LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of consolidated pages data
LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE := $(LOCAL_PATH_CONSOLIDATEDCANONICAL_PAGES).last_synced
  $(call log.debug, LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE)


# STAMPED-FILE-RULE: $(LOCAL_PATH_CONSOLIDATEDCANONICAL).last_synced
#: Synchronizes consolidated issues output data from S3 to the local directory (for resume scenarios)
#: Creates directory stamps with .stamp suffix (hard-coded) to avoid conflicts with mkdir
$(LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE):
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_CONSOLIDATEDCANONICAL) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-directory \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& \
	touch $@


# STAMPED-FILE-RULE: $(LOCAL_PATH_CONSOLIDATEDCANONICAL_PAGES).last_synced
#: Synchronizes consolidated pages output data from S3 to the local directory (for resume scenarios)
#: Creates directory stamps with .stamp suffix (hard-coded) for yearly page directories
$(LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE):
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_CONSOLIDATEDCANONICAL_PAGES) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-directory \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& \
	touch $@


# TARGET: sync-consolidatedcanonical-input
#: Synchronizes input data (canonical + langident enrichments) required for consolidation
sync-consolidatedcanonical-input: sync-canonical sync-langident

.PHONY: sync-consolidatedcanonical-input


# TARGET: sync-consolidatedcanonical
#: Synchronizes consolidatedcanonical processing data from/to S3
sync-consolidatedcanonical: $(LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE) $(LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE)

.PHONY: sync-consolidatedcanonical

# TARGET: clean-sync
#: Cleans up synchronized consolidatedcanonical processing data
clean-sync:: clean-sync-consolidatedcanonical

# TARGET: clean-sync-consolidatedcanonical
#: Removes local synchronization stamp files for consolidatedcanonical processing
#: Note: Enrichment data cleanup is handled by sync_langident.mk
clean-sync-consolidatedcanonical:
	rm -vrf $(LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE) $(LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE) $(LOCAL_PATH_CONSOLIDATEDCANONICAL) || true

.PHONY: clean-sync-consolidatedcanonical

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_consolidatedcanonical.mk)
