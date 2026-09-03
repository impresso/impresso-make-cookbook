$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_mediasources.mk)

###############################################################################
# SYNC mediasources processing TARGETS
###############################################################################


LOCAL_MEDIASOURCES_SYNC_STAMP_FILE := $(call newspaper_sync_stamp_targets,$(LOCAL_PATH_MEDIASOURCES))
$(call expand_newspaper_year_sync_targets,$(LOCAL_PATH_MEDIASOURCES))
  $(call log.debug, LOCAL_MEDIASOURCES_SYNC_STAMP_FILE)

help-sync::
	@echo ""
	@echo "MEDIA-SOURCES SYNC TARGETS:"
	@echo "  sync-mediasources       # Sync media-source output stamps from S3"
	@echo "  clean-sync-mediasources # Remove local media-source sync state for the selected scope"


$(LOCAL_MEDIASOURCES_SYNC_STAMP_FILE):
	$(call sync_year_aware_per_file_stamps,$(S3_PATH_MEDIASOURCES),$@,)


# TARGET: sync-mediasources
#: Synchronize media-source processing data from S3
sync-mediasources: $(LOCAL_MEDIASOURCES_SYNC_STAMP_FILE)

.PHONY: sync-mediasources


clean-sync:: clean-sync-mediasources


# TARGET: clean-sync-mediasources
#: Remove local synchronization stamp files for media-source processing
clean-sync-mediasources:
	rm -vrf $(call newspaper_sync_clean_files,$(LOCAL_PATH_MEDIASOURCES)) $(if $(strip $(NEWSPAPER_YEARS)),,$(LOCAL_PATH_MEDIASOURCES)) || true

.PHONY: clean-sync-mediasources

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_mediasources.mk)
