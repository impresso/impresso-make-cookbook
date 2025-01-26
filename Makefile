# Load all the necessary Makefile fragments for the newspaper processing pipeline
# Just for checking for undefined variables and functions

# Include logging functions
include log.mk

# Include general setup targets
include setup.mk

# Include setup targets for linguistic processing environment
include setup_lingproc.mk

# Include newspaper list management
include newspaper_list.mk

# Include S3 path conversion utilities
include local_to_s3.mk

# Include main processing targets
include main_targets.mk

# Include path definitions for rebuilt content
include paths_rebuilt.mk

# Include targets for synchronizing rebuilt data from S3 to local storage
include sync_rebuilt.mk

# Include path definitions for language identification
include paths_langident.mk

# Include path definitions for linguistic processing
include paths_lingproc.mk

# Include targets for synchronizing processed linguistic data between S3 and local storage
include sync_lingproc.mk

# Include targets for processing newspaper content with linguistic analysis
include processing_lingproc.mk

# Include targets for manual inspection of processing results
include test_eyeball_lingproc.mk

# Include cleanup targets
include clean.mk

# Include AWS configuration targets
include aws.mk


help::
	@echo "Available targets:"
	@echo "  help                            # Display this help message"
	@echo "  LOGGING_LEVEL=DEBUG make help   # Setup for more verbose output"

.DEFAULT_GOAL := help
PHONY_TARGETS += help
