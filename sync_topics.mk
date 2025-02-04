$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_topics.mk)



LOCAL_TOPICS_SYNC_STAMP_FILE := $(LOCAL_PATH_TOPICS).last_synced
  $(call log.debug, LOCAL_TOPICS_SYNC_STAMP_FILE)

clean-sync-input:
	rm -vf $(IN_LOCAL_PROCESSED_DATA_LINGPROC_LAST_SYNCED_FILE) || true
	rm -rfv $(LOCAL_PATH_LINGPROC) || true

PHONY_TARGETS += clean-sync-input


#### SYNCING THE OUTPUT DATA FROM S3 TO LOCAL DIRECTORY
sync-output:: sync-output-topics
PHONY_TARGETS += sync-output-topics

# the suffix of for the local stamp files (added to the input paths on s3)
OUT_LOCAL_TOPICS_STAMP_SUFFIX ?= ''
  $(call log.debug, OUT_LOCAL_TOPICS_STAMP_SUFFIX)

# Rule to sync the output data from the S3 bucket to the local directory
$(LOCAL_TOPICS_SYNC_STAMP_FILE):
	mkdir -p $(@D) && \
	python lib/s3_to_local_stamps.py \
	   $(S3_PATH_TOPICS) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(OUT_LOCAL_TOPICS_STAMP_SUFFIX) \
	   --logfile $@.log.gz && \
	touch $@

sync-output-topics: $(LOCAL_TOPICS_SYNC_STAMP_FILE)

PHONY_TARGETS += sync-output-topics


### CLEANING THE SYNC OUTPUT

clean-sync:: clean-sync-topics

PHONY_TARGETS += clean-sync-topics

clean-sync-topics:
	rm -vf $(LOCAL_TOPICS_SYNC_STAMP_FILE) || true

PHONY_TARGETS += clean-sync-topics


resync-output: clean-sync-output
	$(MAKE) sync-output

PHONY_TARGETS += resync-output


resync-input: clean-sync-input
	$(MAKE) sync-input

PHONY_TARGETS += resync-input

# Remove the local synchronization file stamp and redoes everything, ensuring a full sync with the remote server.
resync: resync-input resync-output

PHONY_TARGETS += resync



$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_topics.mk)
