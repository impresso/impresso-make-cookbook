$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_langident.mk)
###############################################################################
# Processing Language Identification
# Makefile for processing impresso language identification
#
# This file defines the processing rules for language identification tasks.
###############################################################################

processing-target :: langident-target

langident-target :: impresso-lid-stage1a-target impresso-lid-stage1b-target impresso-lid-stage2-target impresso-lid-statistics impresso-lid-eval

# all LID systems to use 
LANGIDENT_LID_SYSTEMS_OPTION ?= langid langdetect impresso_ft wp_ft

# fast text models
LANGIDENT_IMPPRESSO_FASTTEXT_MODEL_OPTION ?= models/fasttext/impresso-lid.bin
LANGIDENT_WIKIPEDIA_FASTTEXT_MODEL_OPTION ?= models/fasttext/lid.176.bin

# minimal text length threshold for automatic LID in stage 1 and 2
LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION ?= 40
LANGIDENT_STAGE1B_MINIMAL_TEXT_LENGTH_OPTION ?= 200
LANGIDENT_STAGE2_MINIMAL_TEXT_LENGTH_OPTION ?= 50

# hyperparameters for scoring the languages
LANGIDENT_BOOST_FACTOR_OPTION ?= 1.5
LANGIDENT_WEIGHT_LB_IMPRESSO_OPTION ?= 6
LANGIDENT_MINIMAL_VOTING_SCORE_OPTION ?= 0.5
LANGIDENT_STAGE1_MINIMAL_LID_PROBABILITY_OPTION ?= 0.20
LANGIDENT_STAGE2_MINIMAL_LID_PROBABILITY_OPTION ?= 0.5
LANGIDENT_MINIMAL_VOTE_SCORE_OPTION ?= 1.5

# DOUBLE-COLON-TARGET: impresso-lid-stage1a-target
# Apply language identification classification
#
# Processes initial language identification for each content item.
impresso-lid-stage1a-target ::
    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-stage1a-files

# DOUBLE-COLON-TARGET: impresso-lid-stage1b-target
# Collect language identification statistics
#
# Summarizes statistics from Stage 1a results.
impresso-lid-stage1b-target ::
    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-stage1b-files


python lib/language_identification.py \
	    --lids $(LID_SYSTEMS) \
	    --impresso-ft $(IMPPRESSO_FASTTEXT_MODEL) \
	    --wp-ft $(WIKIPEDIA_FASTTEXT_MODEL) \
	    --minimal-text-length $(STAGE1A_MINIMAL_TEXT_LENGTH) \
	    --round-ndigits 3 \
		--git-describe $$(git describe) \
	    --infile $< \
	    --outfile $@.$${HOSTNAME}.working.jsonl.bz2 \
	    $(DEBUG_OPTION) \
	    $(TARGET_LOG_MACRO) 1>&2 \

# DOUBLE-COLON-TARGET: impresso-lid-stage2-target
# Finalize language decisions and diagnostics
#
# Processes Stage 2 results and generates diagnostics.
impresso-lid-stage2-target ::
    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-stage2-files

# DOUBLE-COLON-TARGET: impresso-lid-statistics
# Generate statistics
#
# Produces statistics from processed data.
impresso-lid-statistics ::
    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-stage2-diagnostics-files-manifest-target

# DOUBLE-COLON-TARGET: impresso-lid-eval
# Evaluate against gold standard
#
# Compares results with a gold standard for evaluation.
impresso-lid-eval ::
    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-stage2-eval

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_langident.mk)

$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX) $(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{  set +e ; \
     python3 lib/language_identification.py \
          --lid-systems $(LANGIDENT_LID_SYSTEMS_OPTION) \
          --impresso-ft-model $(LANGIDENT_IMPPRESSO_FASTTEXT_MODEL_OPTION) \
          --wikipedia-ft-model $(LANGIDENT_WIKIPEDIA_FASTTEXT_MODEL_OPTION) \
          --stage1a-minimal-text-length $(LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION) \
          --stage1b-minimal-text-length $(LANGIDENT_STAGE1B_MINIMAL_TEXT_LENGTH_OPTION) \
          --stage2-minimal-text-length $(LANGIDENT_STAGE2_MINIMAL_TEXT_LENGTH_OPTION) \
          --boost-factor $(LANGIDENT_BOOST_FACTOR_OPTION) \
          --weight-lb-impresso $(LANGIDENT_WEIGHT_LB_IMPRESSO_OPTION) \
          --minimal-voting-score $(LANGIDENT_MINIMAL_VOTING_SCORE_OPTION) \
          --stage1-minimal-lid-probability $(LANGIDENT_STAGE1_MINIMAL_LID_PROBABILITY_OPTION) \
          --stage2-minimal-lid-probability $(LANGIDENT_STAGE2_MINIMAL_LID_PROBABILITY_OPTION) \
          --minimal-vote-score $(LANGIDENT_MINIMAL_VOTE_SCORE_OPTION) \
          --input $(call LocalToS3,$<,$(LOCAL_REBUILT_STAMP_SUFFIX)) \
          --output $@ \
          --log-file $@.log.gz ; \
    EXIT_CODE=$$? ; \
    echo "Processing exit code: $$EXIT_CODE" ; \
      if [ $$EXIT_CODE -eq 0 ] ; then \
          echo "Processing completed successfully. Uploading logfile..." ; \
          python3 lib/s3_to_local_stamps.py \
              $(call LocalToS3,$@,.stamp).log.gz \
              --upload-file $@.log.gz \
        --force-overwrite ; \
      elif [ $$EXIT_CODE -eq 3 ] ; then \
          echo "Processing skipped (output exists on S3). Not uploading logfile." ; \
          rm -f $@ ; \
          exit 0 ; \
      else \
          echo "An error occurred during processing. Exit code: $$EXIT_CODE" ; \
          rm -f $@ ; \
          exit $$EXIT_CODE ; \
      fi ; }
