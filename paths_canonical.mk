$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_canonical.mk)

###############################################################################
# INPUT PATHS FOR CANONICAL FILES FOR PAGES OF A SPECIFIC NEWSPAPER
#
# Defines paths and variables for accessing newspaper files on S3 in the impresso
# canonical format that are used for local synchronization and processing.
###############################################################################

# USER-VARIABLE: S3_BUCKET_CANONICAL
# The bucket for canonical content.
# This variable specifies the S3 bucket where the canonical newspaper files is stored.
S3_BUCKET_CANONICAL ?= 12-canonical-final
  $(call log.debug, S3_BUCKET_CANONICAL)

# VARIABLE: S3_PATH_CANONICAL_PAGES
# The full S3 path for the canonical pages files of a specific newspaper.

S3_PATH_CANONICAL_PAGES := s3://$(S3_BUCKET_CANONICAL)/$(NEWSPAPER)/pages
  $(call log.debug, S3_PATH_CANONICAL_PAGES)

# VARIABLE: LOCAL_PATH_CANONICAL_PAGES
# The corresponding local path for canonical newspaper pages files.
# This local directory mirrors the S3 path structure for local builds and processing.
LOCAL_PATH_CANONICAL_PAGES := $(BUILD_DIR)/$(S3_BUCKET_CANONICAL)/$(NEWSPAPER)/pages
  $(call log.debug, LOCAL_PATH_CANONICAL_PAGES)

# USER-VARIABLE: LOCAL_CANONICAL_PAGES_STAMP_SUFFIX
# The suffix (typically $(EMPTY) or .stamp) of the local stamp files.
LOCAL_CANONICAL_PAGES_STAMP_SUFFIX ?= .stamp
  $(call log.debug, LOCAL_CANONICAL_PAGES_STAMP_SUFFIX)

# VARIABLE: LOCAL_CANONICAL_PAGES_STAMP_FILE_LIST
# Stores all locally available canonical pages stamp files for dependency tracking
# Note: Canonical pages use yearly issue-level stamps (e.g., AATA-1846.stamp), not pages-level stamps
LOCAL_CANONICAL_PAGES_STAMP_FILE_LIST := \
    $(shell ls -r $(LOCAL_PATH_CANONICAL_PAGES)/*$(LOCAL_CANONICAL_PAGES_STAMP_SUFFIX) 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_CANONICAL_PAGES_STAMP_FILE_LIST)

$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_canonical.mk)
