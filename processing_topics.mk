$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_topics.mk)

# Function to map local processed data from linguistic processing to topics
define local_lingproc_to_topics_file
$(1:$(LOCAL_PATH_LINGPROC)/%.jsonl.bz2=$(LOCAL_PATH_TOPICS)/%.jsonl.bz2)
endef

# Variable for all locally available stamp files. Needed for dependency tracking
# of the build process. We discard errors as the path or file might not exist yet.
LOCAL_LINGPROC_FILES := \
    $(shell ls -r $(LOCAL_PATH_LINGPROC)/*.jsonl.bz2 2> /dev/null \
      | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))

  $(call log.debug, LOCAL_LINGPROC_FILES)

# Variable for all locally processed data topic files
LOCAL_TOPICS_FILES := \
 $(call local_lingproc_to_topics_file,$(LOCAL_LINGPROC_FILES))

  $(call log.debug, LOCAL_TOPICS_FILES)

# S3 STORAGE UPDATE SETTINGS

# Prevent any output to S3 even if s3-output-path is set
# TOPICS_S3_OUTPUT_DRY_RUN?= --s3-output-dry-run
# To disable the dry-run mode, comment the line above and uncomment the line below
TOPICS_S3_OUTPUT_DRY_RUN ?=
  $(call log.debug, TOPICS_S3_OUTPUT_DRY_RUN)

# Keep only the local timestamp output files after uploading (only relevant when
# uploading to S3)
TOPICS_KEEP_TIMESTAMP_ONLY_OPTION ?= --keep-timestamp-only
# To disable the keep-timestamp-only mode, comment the line above and uncomment the line below
#TOPICS_KEEP_TIMESTAMP_ONLY_OPTION ?= 
  $(call log.debug, TOPICS_KEEP_TIMESTAMP_ONLY_OPTION)

# Quit the processing if the output file already exists in S3
# Double check if the output file exists in S3 and quit if it does
TOPICS_QUIT_IF_S3_OUTPUT_EXISTS ?= --quit-if-s3-output-exists
# To disable the quit-if-s3-output-exists mode, comment the line above and uncomment the line below
#TOPICS_QUIT_IF_S3_OUTPUT_EXISTS ?=
  $(call log.debug, TOPICS_QUIT_IF_S3_OUTPUT_EXISTS)

# Target for processing topics
topics-target: $(LOCAL_TOPICS_FILES)

# Rule to process topics from linguistic processing data
$(LOCAL_PATH_TOPICS)/%.jsonl.bz2: $(LOCAL_PATH_LINGPROC)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE)\
	mkdir -p $(@D) && \
	{  set +e ; \
	python lib/mallet_topic_inferencer.py \
	  --input $(call local_to_s3,$<,'') \
	  --input-format impresso \
	  --output $@ \
	  --output-format jsonl \
	  --min-p 0.05 \
	  --languages de fr lb \
	  --de_config models/tm/tm-de-all-v2.0.config.json \
	  --fr_config models/tm/tm-fr-all-v2.0.config.json \
	  --lb_config models/tm/tm-lb-all-v2.1.config.json \
	  $(TOPICS_QUIT_IF_S3_OUTPUT_EXISTS) \
	  $(TOPICS_S3_OUTPUT_DRY_RUN) \
	  $(TOPICS_KEEP_TIMESTAMP_ONLY_OPTION) \
	  --git-version $(GIT_VERSION) \
	  --lingproc-run_id $(RUN_ID_LINGPROC) \
	  --impresso-model-id $(MODEL_ID_TOPICS) \
	  --inferencer-random-seed $(MALLET_RANDOM_SEED) \
	  --s3-output-path $(call local_to_s3,$@,'') \
	  --log-file $@.log.gz ; \
	  EXIT_CODE=$$? ; \
		echo "Processing exit code: $$EXIT_CODE" ; \
		if [ $$EXIT_CODE -eq 0 ] ; then \
			echo "Processing completed successfully. Uploading logfile..." ; \
			python3 lib/s3_to_local_stamps.py \
				$(call local_to_s3,$@,'').log.gz \
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
