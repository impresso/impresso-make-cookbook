$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/newspaper_list.mk)

###############################################################################
# NEWSPAPER LIST MANAGEMENT
# Configuration and generation of newspaper processing lists
###############################################################################

# Default to some newspaper if none is specified
NEWSPAPER ?= actionfem
  $(call log.debug, NEWSPAPER)

# Configuration file containing space-separated newspapers to process
NEWSPAPERS_TO_PROCESS_FILE ?= $(BUILD_DIR)/newspapers.txt
  $(call log.debug, NEWSPAPERS_TO_PROCESS_FILE)

# Processing order configuration
# Set to 'shuf' for random order or 'cat' for chronological
NEWSPAPER_YEAR_SORTING ?= shuf
  $(call log.debug, NEWSPAPER_YEAR_SORTING)

# TARGET: newspaper-list-target
# Generates list of newspapers to process from S3 bucket
newspaper-list-target: $(NEWSPAPERS_TO_PROCESS_FILE)
PHONY_TARGETS += newspaper-list-target

# Rule to generate the file containing the newspapers to process
# we shuffle the newspapers to avoid recomputations by different machines working on the dataset
$(NEWSPAPERS_TO_PROCESS_FILE): | $(BUILD_DIR)
	python -c \
	"import boto3, os, random; \
	s3 =boto3.resource( \
        "s3",\
        aws_secret_access_key= os.getenv('SE_SECRET_KEY'),\
        aws_access_key_id=os.getenv('SE_ACCESS_KEY'),\
        endpoint_url=os.getenv('SE_HOST_URL'))\
	bucket = s3.Bucket('$(S3_BUCKET_REBUILT)'); \
    result = bucket.meta.client.list_objects_v2(Bucket=bucket.name, Delimiter='/'); \
	l = [prefix['Prefix'][:-1] for prefix in result.get('CommonPrefixes', [])]; \
	random.shuffle(l); \
    print(*l)" \
	> $@


$(call log.debug, COOKBOOK END INCLUDE: cookbook/newspaper_list.mk)
