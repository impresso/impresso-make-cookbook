$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/aws.mk)

# Reuse AWS setup rules so parents can include either or both fragments.
include $(dir $(lastword $(MAKEFILE_LIST)))setup_aws.mk

help::
	@echo "  make help-aws             # AWS CLI setup and S3 folder move commands"

###############################################################################
# S3 CROSS-BUCKET FOLDER MOVE
#
# Moves (copies then deletes) a folder from one S3 bucket to another.
# There is no atomic rename across S3 buckets; `aws s3 mv --recursive` copies
# each object individually and then deletes the source objects.
#
# Always dry-run first to verify paths, then run the actual move.
#
# --- Direct AWS CLI commands (set credentials env vars first) ---
#
# Export credentials once:
#   export AWS_CONFIG_FILE=.aws/config
#   export AWS_SHARED_CREDENTIALS_FILE=.aws/credentials
#
# 1. Dry-run — lists all objects that would be moved, no data transferred:
#   aws s3 mv --recursive --dryrun \
#     s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \
#     s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS
#
# 2. Actual move:
#   aws s3 mv --recursive \
#     s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \
#     s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS
#
# To move an entire run across buckets (all providers):
#   aws s3 mv --recursive --dryrun \
#     s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/ \
#     s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/
#
# --- Make targets (see below) ---
#
#   make mv-s3-folder-dryrun \
#     S3_MV_SRC=s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \
#     S3_MV_DST=s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS
#
#   make mv-s3-folder \
#     S3_MV_SRC=s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \
#     S3_MV_DST=s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS
###############################################################################

S3_MV_SRC ?=
S3_MV_DST ?=

# TARGET: mv-s3-folder-dryrun
#: Dry-run of a cross-bucket S3 folder move — lists what would be copied/deleted
#
# Set S3_MV_SRC and S3_MV_DST on the command line. No data is transferred.
mv-s3-folder-dryrun:
	@test -n "$(S3_MV_SRC)" || (echo "ERROR: S3_MV_SRC is not set"; exit 1)
	@test -n "$(S3_MV_DST)" || (echo "ERROR: S3_MV_DST is not set"; exit 1)
	@echo "DRY RUN: $(S3_MV_SRC) -> $(S3_MV_DST)"
	AWS_CONFIG_FILE=.aws/config AWS_SHARED_CREDENTIALS_FILE=.aws/credentials \
	aws s3 mv --recursive --dryrun \
	  "$(S3_MV_SRC)" \
	  "$(S3_MV_DST)"

# TARGET: mv-s3-folder
#: Move a folder across S3 buckets (copy + delete source). Run dryrun first.
#
# Set S3_MV_SRC and S3_MV_DST on the command line.
# This copies all objects to the destination and then removes the source objects.
mv-s3-folder:
	@test -n "$(S3_MV_SRC)" || (echo "ERROR: S3_MV_SRC is not set"; exit 1)
	@test -n "$(S3_MV_DST)" || (echo "ERROR: S3_MV_DST is not set"; exit 1)
	@echo "MOVING: $(S3_MV_SRC) -> $(S3_MV_DST)"
	AWS_CONFIG_FILE=.aws/config AWS_SHARED_CREDENTIALS_FILE=.aws/credentials \
	aws s3 mv --recursive \
	  "$(S3_MV_SRC)" \
	  "$(S3_MV_DST)"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/aws.mk)

.PHONY: help-aws

help-aws::
	@echo ""
	@echo "AWS / S3 TARGETS:"
	@echo ""
	@echo "  INSTALLATION"
	@echo "    make install-aws          # Install AWS CLI via pipenv"
	@echo ""
	@echo "  CONFIGURATION"
	@echo "    make aws-setup            # Generate .aws/config and .aws/credentials from .env"
	@echo "    make create-aws-config    # Generate .aws/config and .aws/credentials from .env"
	@echo "    Required .env variables:"
	@echo "      SE_HOST_URL        S3-compatible endpoint URL"
	@echo "      SE_ACCESS_KEY      AWS access key ID"
	@echo "      SE_SECRET_KEY      AWS secret access key"
	@echo ""
	@echo "  TESTING"
	@echo "    make test-aws             # List S3 bucket contents to verify credentials"
	@echo ""
	@echo "  MOVING FOLDERS ACROSS BUCKETS"
	@echo "    Run dry-run first, then the actual move:"
	@echo ""
	@echo "    make mv-s3-folder-dryrun \\"
	@echo "      S3_MV_SRC=s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \\"
	@echo "      S3_MV_DST=s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS"
	@echo ""
	@echo "    make mv-s3-folder \\"
	@echo "      S3_MV_SRC=s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \\"
	@echo "      S3_MV_DST=s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS"
	@echo ""
	@echo "    Or directly with the AWS CLI (after exporting credentials):"
	@echo "      export AWS_CONFIG_FILE=.aws/config"
	@echo "      export AWS_SHARED_CREDENTIALS_FILE=.aws/credentials"
	@echo ""
	@echo "      # dry-run (single provider):"
	@echo "      aws s3 mv --recursive --dryrun \\"
	@echo "        s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \\"
	@echo "        s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS"
	@echo ""
	@echo "      # dry-run (entire run, all providers):"
	@echo "      aws s3 mv --recursive --dryrun \\"
	@echo "        s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/ \\"
	@echo "        s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/"
	@echo ""
	@echo "      # actual move:"
	@echo "      aws s3 mv --recursive \\"
	@echo "        s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \\"
	@echo "        s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS"
	@echo ""
