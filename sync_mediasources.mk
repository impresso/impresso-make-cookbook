$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_mediasources.mk)

###############################################################################
# SYNC mediasources processing TARGETS
###############################################################################


LOCAL_MEDIASOURCES_SYNC_STAMP_FILE := $(LOCAL_PATH_MEDIASOURCES).last_synced
  $(call log.debug, LOCAL_MEDIASOURCES_SYNC_STAMP_FILE)

help-sync::
	@echo ""
	@echo "MEDIA-SOURCES SYNC TARGETS:"
	@echo "  sync-mediasources       # Sync media-source output stamps from S3"
	@echo "  clean-sync-mediasources # Remove local media-source sync state and output"


$(LOCAL_PATH_MEDIASOURCES).last_synced:
	mkdir -p $(@D) \
	&& \
	python -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_MEDIASOURCES) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz \
	&& \
	touch $@


# TARGET: sync-mediasources
#: Synchronize media-source processing data from S3
sync-mediasources: $(LOCAL_MEDIASOURCES_SYNC_STAMP_FILE)

.PHONY: sync-mediasources


clean-sync:: clean-sync-mediasources


# TARGET: clean-sync-mediasources
#: Remove local synchronization stamp files for media-source processing
clean-sync-mediasources:
	rm -vrf $(LOCAL_MEDIASOURCES_SYNC_STAMP_FILE) $(LOCAL_PATH_MEDIASOURCES) || true

.PHONY: clean-sync-mediasources

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_mediasources.mk)
