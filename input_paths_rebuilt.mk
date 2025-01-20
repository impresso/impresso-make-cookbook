###############################################################################
# INPUT PATHS FOR REBUILT CONTENT
# Defines paths and variables for accessing rebuilt newspaper content from S3
###############################################################################

$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/input_paths_rebuilt.mk)

# Variable naming conventions:
# - Input paths start with IN_
# - S3 paths use _S3_ prefix
# - Local paths use _LOCAL_ prefix

# The input bucket for rebuilt content
IN_S3_BUCKET_REBUILT ?= 22-rebuilt-final
  $(call log.debug, IN_S3_BUCKET_REBUILT)

# The input path
IN_S3_PATH_REBUILT := s3://$(IN_S3_BUCKET_REBUILT)/$(NEWSPAPER)
  $(call log.debug, IN_S3_PATH_REBUILT)

# The local path
IN_LOCAL_PATH_REBUILT := $(BUILD_DIR)/$(IN_S3_BUCKET_REBUILT)/$(NEWSPAPER)
  $(call log.debug, IN_LOCAL_PATH_REBUILT)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/input_paths_rebuilt.mk)
