$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_topics.mk)

###############################################################################
# Processing Topics
# Mapping local processed linguistic data to topics and handling S3 updates
#
# This Makefile defines rules for transforming linguistic processing outputs
# into topic-based representations. It also includes settings for managing
# interactions with S3 storage, including dry-run options, retention policies,
# and conditional execution based on S3 file existence.
###############################################################################


# FUNCTION: LocalLingprocToTopicsFile
# Maps local processed linguistic data to corresponding topic files
#
define LocalLingprocToTopicsFile
$(1:$(LOCAL_PATH_LINGPROC)/%.jsonl.bz2=$(LOCAL_PATH_TOPICS)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_LINGPROC_FILES
# List of all locally available linguistic processing output files.
# Used for dependency tracking of the build process. Errors are discarded
# as files or directories may not exist initially.
LOCAL_LINGPROC_FILES := \
    $(shell ls -r $(LOCAL_PATH_LINGPROC)/*.jsonl.bz2 2> /dev/null \
      | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))

$(call log.debug, LOCAL_LINGPROC_FILES)


# VARIABLE: LOCAL_TOPICS_FILES
# List of all locally processed topic files corresponding to linguistic outputs.
LOCAL_TOPICS_FILES := \
    $(call LocalLingprocToTopicsFile,$(LOCAL_LINGPROC_FILES))

$(call log.debug, LOCAL_TOPICS_FILES)


# TARGET: topics-target
#: Generates topic files from linguistic processing outputs.
topics-target: $(LOCAL_TOPICS_FILES)


# FILE-RULE: Process topics from linguistic processing output
#: Converts linguistic output into topic-based JSONL files.
$(LOCAL_PATH_TOPICS)/%.jsonl.bz2: $(LOCAL_PATH_LINGPROC)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE)\
	mkdir -p $(@D) && \
	{ set +e ; \
	  python lib/mallet_topic_inferencer.py \
	    --input $(call LocalToS3,$<,'') \
	    --input-format impresso \
	    --output $@ \
	    --output-format jsonl \
	    --min-p 0.05 \
	    --languages de fr lb \
	    --de_config models/tm/tm-de-all-v2.0.config.json \
	    --fr_config models/tm/tm-fr-all-v2.0.config.json \
	    --lb_config models/tm/tm-lb-all-v2.1.config.json \
	    $(PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION) \
	    $(PROCESSING_S3_OUTPUT_DRY_RUN) \
	    $(PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION) \
	    --git-version $(GIT_VERSION) \
	    --lingproc-run_id $(RUN_ID_LINGPROC) \
	    --impresso-model-id $(MODEL_ID_TOPICS) \
	    --inferencer-random-seed $(MALLET_RANDOM_SEED) \
	    --s3-output-path $(call LocalToS3,$@,'') \
	    --log-file $@.log.gz ; \
	  EXIT_CODE=$$? ; \
	  echo "Processing exit code: $$EXIT_CODE" ; \
	  if [ $$EXIT_CODE -eq 0 ] ; then \
	    echo "Processing completed successfully. Uploading logfile..." ; \
	    python3 lib/s3_to_local_stamps.py \
	      $(call LocalToS3,$@,'').log.gz \
	      --upload-file $@.log.gz \
	      --force-overwrite ; \
	  elif [ $$EXIT_CODE -eq 3 ]; then \
	    echo "Processing skipped (output exists on S3). Not uploading logfile." ; \
	    rm -f $@ ; \
	    exit 0 ; \
	  else \
	    echo "An error occurred during processing. Exit code: $$EXIT_CODE" ; \
	    rm -f $@ ; \
	    exit $$EXIT_CODE ; \
	  fi ; \
	}

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_topics.mk)
