$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync.mk)

###############################################################################
# GENERAL SYNC TARGETS
# Targets for synchronizing data between S3 and local storage
# Must be included before any specific sync targets
###############################################################################

# VARIABLE: LOCAL_STAMP_SUFFIX
LOCAL_STAMP_SUFFIX ?= ''
  $(call log.debug, LOCAL_STAMP_SUFFIX)


# DOUBLE-COLON-TARGET: sync
#: Synchronize local files with S3 (input and output) without deleting local files
sync:: sync-output

sync:: sync-input

PHONY_TARGETS += sync


# DOUBLE-COLON-TARGET: sync-input
#: Synchronize input files with S3 without deleting local files
sync-input:: | $(BUILD_DIR)

PHONY_TARGETS += sync-input


# DOUBLE-COLON-TARGET: sync-output
#: Synchronize output files with S3 without deleting local files
sync-output:: | $(BUILD_DIR)

PHONY_TARGETS += sync-output


$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync.mk)
