$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync.mk)

###############################################################################
# GENERAL SYNC TARGETS
# Targets for synchronizing data between S3 and local storage
# Must be included before any specific sync targets
###############################################################################


# DOUBLE-COLON-TARGET: sync
#: Synchronize local files with S3 (input and output) without deleting local files
#
# This target ensures that both input and output files are synchronized
# with S3 while preserving local files.
sync:: sync-output

sync:: sync-input

PHONY_TARGETS += sync


# DOUBLE-COLON-TARGET: sync-input
#: Synchronize input files with S3 without deleting local files
#
# This target syncs input files from S3 to the local machine
# without removing any existing local files.
sync-input:: | $(BUILD_DIR)

PHONY_TARGETS += sync-input


# DOUBLE-COLON-TARGET: sync-output
#: Synchronize output files with S3 without deleting local files
#
# This target ensures that output files are synchronized from the
# local machine to S3 while keeping existing local files intact.
sync-output:: | $(BUILD_DIR)

PHONY_TARGETS += sync-output


# DOUBLE-COLON-TARGET: resync-output
#: Synchronize local files with S3 output by deleting all local files first
#
# This target ensures that both input and output files are freshly synchronized
resync-output: clean-sync-output
	$(MAKE) sync-output

PHONY_TARGETS += resync-output


# DOUBLE-COLON-TARGET: resync-input
#: Synchronize local input with S3 by deleting all local files first
#
# This target ensures that both input and output files are freshly synchronized
resync-input: clean-sync-input
	$(MAKE) sync-input

PHONY_TARGETS += resync-input

# TARGET: resync
#: Forces complete resynchronization with remote server
resync: resync-input resync-output

PHONY_TARGETS += resync


# USER-VARIABLE: LOCAL_STAMP_SUFFIX
#: Suffix used for local stamp files to track sync status
#
# This variable can be overridden to provide a specific suffix
# for local stamp files to differentiate sync operations.
LOCAL_STAMP_SUFFIX ?= ''
  $(call log.debug, LOCAL_STAMP_SUFFIX)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync.mk)
