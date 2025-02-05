$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/LocalToS3.mk)

###############################################################################
# S3 PATH CONVERSION UTILITIES
# Functions for converting between local and S3 paths
###############################################################################

# FUNCTION: LocalToS3
# Converts local file paths to their S3 equivalents
# Args:
#   1: Local file path
#   2: Optional suffix to remove
define LocalToS3
$(subst $(2),,$(subst $(BUILD_DIR),s3:/,$(1)))
endef

# TARGET: test-LocalToS3
# Runs test cases for the LocalToS3 function
test-LocalToS3:
	@echo "Running tests for LocalToS3 function..."
	@echo "Test 1: Convert local path to S3 path without stripping any suffix"
	@echo "Input: build.d/22-rebuilt-final/marieclaire/file.txt"
	@echo "Expected Output: s3://22-rebuilt-final/marieclaire/file.txt"
	@echo "Actual Output  : $(call LocalToS3,build.d/22-rebuilt-final/marieclaire/file.txt)"
	@echo
	@echo "Test 2: Convert local path to S3 path and strip the .txt suffix"
	@echo "Input: build.d/22-rebuilt-final/marieclaire/file.txt, .txt"
	@echo "Expected Output: s3://22-rebuilt-final/marieclaire/file"
	@echo "Actual Output  : $(call LocalToS3,build.d/22-rebuilt-final/marieclaire/file.txt,.txt)"
	@echo
	@echo "Test 3: Convert local path to S3 path and strip a custom suffix"
	@echo "Input: build.d/22-rebuilt-final/marieclaire/file.custom, .custom"
	@echo "Expected Output: s3://22-rebuilt-final/marieclaire/file"
	@echo "Actual Output  : $(call LocalToS3,build.d/22-rebuilt-final/marieclaire/file.custom,.custom)"
	@echo

$(call log.debug, COOKBOOK END INCLUDE: cookbook/LocalToS3.mk)
