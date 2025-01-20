###############################################################################
# INPUT PATHS FOR REBUILT CONTENT
# Defines paths and variables for accessing rebuilt newspaper content from S3
###############################################################################

$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_rebuilt.mk)

# Variable naming conventions:
# - S3 paths use _S3_ prefix
# - Local paths use _LOCAL_ prefix

# The input bucket for rebuilt content
S3_BUCKET_REBUILT ?= 22-rebuilt-final
  $(call log.debug, S3_BUCKET_REBUILT)

# The input path
S3_PATH_REBUILT := s3://$(S3_BUCKET_REBUILT)/$(NEWSPAPER)
  $(call log.debug, S3_PATH_REBUILT)

# The local path
LOCAL_PATH_REBUILT := $(BUILD_DIR)/$(S3_BUCKET_REBUILT)/$(NEWSPAPER)
  $(call log.debug, LOCAL_PATH_REBUILT)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_rebuilt.mk)
