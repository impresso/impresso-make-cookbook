$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_rebuilt.mk)

###############################################################################
# INPUT PATHS FOR REBUILT CONTENT
# Defines paths and variables for accessing rebuilt newspaper content from S3
###############################################################################

# USER-VARIABLE: S3_BUCKET_REBUILT
# The input bucket for rebuilt content.
# This variable specifies the S3 bucket where the rebuilt newspaper content is stored.
S3_BUCKET_REBUILT ?= 22-rebuilt-final
  $(call log.debug, S3_BUCKET_REBUILT)

# VARIABLE: S3_PATH_REBUILT
# The full S3 path for rebuilt newspaper content.
# This path points to the specific newspaper directory inside the S3 bucket.
S3_PATH_REBUILT := s3://$(S3_BUCKET_REBUILT)/$(NEWSPAPER)
  $(call log.debug, S3_PATH_REBUILT)

# VARIABLE: LOCAL_PATH_REBUILT
# The corresponding local path for rebuilt newspaper content.
# This local directory mirrors the S3 path structure for local processing.
LOCAL_PATH_REBUILT := $(BUILD_DIR)/$(S3_BUCKET_REBUILT)/$(NEWSPAPER)
  $(call log.debug, LOCAL_PATH_REBUILT)

# the suffix of for the local stamp files (added to the input paths on s3)
LOCAL_REBUILT_STAMP_SUFFIX ?= .stamp
  $(call log.debug, LOCAL_REBUILT_STAMP_SUFFIX)


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_rebuilt.mk)
