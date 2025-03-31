$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_canonical.mk)

###############################################################################
# INPUT PATHS FOR CANONICAL CONTENT FOR PAGES AND
# Defines paths and variables for accessing canonical newspaper content from S3
###############################################################################

# USER-VARIABLE: S3_BUCKET_CANONICAL
# The bucket for canonical content.
# This variable specifies the S3 bucket where the canonical newspaper content is stored.
S3_BUCKET_CANONICAL ?= 12-canonical-final
  $(call log.debug, S3_BUCKET_CANONICAL)

# VARIABLE: S3_PATH_CANONICAL_PAGES
# The full S3 path for canonical newspaper content.
# This path points to the specific newspaper directory inside the S3 bucket.
S3_PATH_CANONICAL_PAGES := s3://$(S3_BUCKET_CANONICAL)/$(NEWSPAPER)/pages
  $(call log.debug, S3_PATH_CANONICAL_PAGES)

# VARIABLE: LOCAL_PATH_CANONICAL_PAGES
# The corresponding local path for canonical newspaper content.
# This local directory mirrors the S3 path structure for local processing.
LOCAL_PATH_CANONICAL_PAGES := $(BUILD_DIR)/$(S3_BUCKET_CANONICAL)/$(NEWSPAPER)/pages
  $(call log.debug, LOCAL_PATH_CANONICAL_PAGES)

$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_canonical.mk)
