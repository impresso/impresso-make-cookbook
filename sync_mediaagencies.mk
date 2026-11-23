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

# Stage-1 and stage-2 parquet buffers of the staged pipeline
#------------------------------------------------------------------------------

LOCAL_MEDIAAGENCIES_STAGE1_SYNC_STAMP_FILE := $(call newspaper_sync_stamp_targets,$(LOCAL_PATH_MEDIAAGENCIES_STAGE1))
$(call expand_newspaper_year_sync_targets,$(LOCAL_PATH_MEDIAAGENCIES_STAGE1))

LOCAL_MEDIAAGENCIES_STAGE2_SYNC_STAMP_FILE := $(call newspaper_sync_stamp_targets,$(LOCAL_PATH_MEDIAAGENCIES_STAGE2))
$(call expand_newspaper_year_sync_targets,$(LOCAL_PATH_MEDIAAGENCIES_STAGE2))

help-sync::
	@echo "  sync-mediaagencies-stage1 # Sync stage-1 parquet stamps from S3"
	@echo "  sync-mediaagencies-stage2 # Sync stage-2 parquet stamps from S3"

$(LOCAL_MEDIAAGENCIES_STAGE1_SYNC_STAMP_FILE): force-mediaagencies-sync
	$(call sync_year_aware_per_file_stamps,$(S3_PATH_MEDIAAGENCIES_STAGE1),$@,)

$(LOCAL_MEDIAAGENCIES_STAGE2_SYNC_STAMP_FILE): force-mediaagencies-sync
	$(call sync_year_aware_per_file_stamps,$(S3_PATH_MEDIAAGENCIES_STAGE2),$@,)

# TARGET: sync-mediaagencies-stage1
#: Synchronize stage-1 parquet stamps from S3
sync-mediaagencies-stage1: $(LOCAL_MEDIAAGENCIES_STAGE1_SYNC_STAMP_FILE)

# TARGET: sync-mediaagencies-stage2
#: Synchronize stage-2 parquet stamps from S3
sync-mediaagencies-stage2: $(LOCAL_MEDIAAGENCIES_STAGE2_SYNC_STAMP_FILE)

.PHONY: sync-mediaagencies-stage1 sync-mediaagencies-stage2

clean-sync:: clean-sync-mediaagencies-stages

# TARGET: clean-sync-mediaagencies-stages
#: Remove local synchronization stamp files for the stage-1 and stage-2 buffers
clean-sync-mediaagencies-stages:
	rm -vrf $(call newspaper_sync_clean_files,$(LOCAL_PATH_MEDIAAGENCIES_STAGE1)) $(if $(strip $(NEWSPAPER_YEARS)),,$(LOCAL_PATH_MEDIAAGENCIES_STAGE1)) || true
	rm -vrf $(call newspaper_sync_clean_files,$(LOCAL_PATH_MEDIAAGENCIES_STAGE2)) $(if $(strip $(NEWSPAPER_YEARS)),,$(LOCAL_PATH_MEDIAAGENCIES_STAGE2)) || true

.PHONY: clean-sync-mediaagencies-stages


$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_mediaagencies.mk)
