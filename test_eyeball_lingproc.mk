###############################################################################
# TESTING AND INSPECTION TARGETS
# Targets for manual inspection of processing results
###############################################################################

$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/test_eyeball_lingproc.mk)

# TARGET: test-eyeball
# Generate sample output for manual inspection
test-eyeball: build.d/test_eyeball.txt
	# ls -l $<

# Generate test sample from processed files
build.d/test_eyeball.txt: 
	python lib/sample_eyeball_output.py 4 --no-pos $(BUILD_DIR)/$(S3_BUCKET_LINGPROC)/$(PROCESS_LABEL_LINGPROC)$(PROCESS_SUBTYPE_LABEL_LINGPROC)/$(RUN_ID_LINGPROC)/*/*.jsonl.bz2 > $@

build.d/test_eyeball.tsv: 
	python lib/sample_eyeball_output.py --no-pos -o $@ $(BUILD_DIR)/$(S3_BUCKET_LINGPROC)/$(PROCESS_LABEL_LINGPROC)$(PROCESS_SUBTYPE_LABEL_LINGPROC)/$(RUN_ID_LINGPROC)/*/*.jsonl.bz2 > $@


$(call log.debug, COOKBOOK END INCLUDE: cookbook/test_eyeball_lingproc.mk)
