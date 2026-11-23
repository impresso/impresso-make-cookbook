$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_mediaagencies.mk)

###############################################################################
# SYNC mediaagencies processing TARGETS
###############################################################################


LOCAL_MEDIAAGENCIES_SYNC_STAMP_FILE := $(call newspaper_sync_stamp_targets,$(LOCAL_PATH_MEDIAAGENCIES))
$(call expand_newspaper_year_sync_targets,$(LOCAL_PATH_MEDIAAGENCIES))
  $(call log.debug, LOCAL_MEDIAAGENCIES_SYNC_STAMP_FILE)

help-sync::
	@echo ""
	@echo "MEDIA-AGENCIES SYNC TARGETS:"
	@echo "  sync-mediaagencies       # Sync media-agency output stamps from S3"
	@echo "  clean-sync-mediaagencies # Remove local media-agency sync state for the selected scope"


# Record the last successful check without caching the remote inventory forever.
.PHONY: force-mediaagencies-sync
force-mediaagencies-sync:

$(LOCAL_MEDIAAGENCIES_SYNC_STAMP_FILE): force-mediaagencies-sync
	$(call sync_year_aware_per_file_stamps,$(S3_PATH_MEDIAAGENCIES),$@,)


# TARGET: sync-mediaagencies
#: Synchronize media-agency processing data from S3
sync-mediaagencies: $(LOCAL_MEDIAAGENCIES_SYNC_STAMP_FILE)

.PHONY: sync-mediaagencies


clean-sync:: clean-sync-mediaagencies


# TARGET: clean-sync-mediaagencies
#: Remove local synchronization stamp files for media-agency processing
clean-sync-mediaagencies:
	rm -vrf $(call newspaper_sync_clean_files,$(LOCAL_PATH_MEDIAAGENCIES)) $(if $(strip $(NEWSPAPER_YEARS)),,$(LOCAL_PATH_MEDIAAGENCIES)) || true

.PHONY: clean-sync-mediaagencies

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_mediaagencies.mk)
