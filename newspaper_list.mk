$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/newspaper_list.mk)

###############################################################################
# NEWSPAPER LIST MANAGEMENT
# Configuration and generation of newspaper processing lists
#
# This Makefile sets up the configuration and processing order of newspaper
# lists retrieved from an S3 bucket. The list is either shuffled or kept in
# chronological order, based on user settings.
###############################################################################


help::
	@echo "  newspaper-list-target  # Generate newspaper list to process from the S3 bucket content: '$(NEWSPAPERS_TO_PROCESS_FILE)'"


setup:: newspaper-list-target

# USER-VARIABLE: NEWSPAPER
# Default newspaper selection if none is specified
NEWSPAPER ?= actionfem
  $(call log.debug, NEWSPAPER)


# USER-VARIABLE: NEWSPAPERS_TO_PROCESS_FILE
# Configuration file containing space-separated newspapers to process
NEWSPAPERS_TO_PROCESS_FILE ?= $(BUILD_DIR)/newspapers.txt
  $(call log.debug, NEWSPAPERS_TO_PROCESS_FILE)


# USER-VARIABLE: NEWSPAPER_YEAR_SORTING
# Determines the order of newspaper processing
# - 'shuf' for random order
# - 'cat' for chronological order
NEWSPAPER_YEAR_SORTING ?= shuf
  $(call log.debug, NEWSPAPER_YEAR_SORTING)


# USER-VARIABLE: S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET
# S3 bucket prefix containing newspapers for processing
S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET ?= 22-rebuilt-final
  $(call log.debug, S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET)


# TARGET: newspaper-list-target
#: Generates a list of newspapers to process from the S3 bucket
newspaper-list-target: $(NEWSPAPERS_TO_PROCESS_FILE)
.PHONY: newspaper-list-target


# FILE-RULE: $(NEWSPAPERS_TO_PROCESS_FILE)
#: Generates the file containing the newspapers to process
#
# This rule retrieves the list of available newspapers from an S3 bucket,
# shuffles them to distribute processing evenly, and writes them to a file.
$(NEWSPAPERS_TO_PROCESS_FILE): | $(BUILD_DIR)
	python -c \
	"import boto3, os, random; from dotenv import load_dotenv; load_dotenv() ; \
	s3 = boto3.resource( \
        's3',\
        aws_secret_access_key=os.getenv('SE_SECRET_KEY'),\
        aws_access_key_id=os.getenv('SE_ACCESS_KEY'),\
        endpoint_url=os.getenv('SE_HOST_URL')) ; \
	bucket = s3.Bucket('$(S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET)'); \
    result = bucket.meta.client.list_objects_v2(Bucket=bucket.name, Delimiter='/'); \
	l = [prefix['Prefix'][:-1] for prefix in result.get('CommonPrefixes', [])]; \
	random.shuffle(l); \
    print(*l)" \
	> $@

$(call log.debug, COOKBOOK END INCLUDE: cookbook/newspaper_list.mk)
