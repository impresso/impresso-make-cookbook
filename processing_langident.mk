$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_langident.mk)
###############################################################################
# Processing Language Identification
# Makefile for processing impresso language identification
#
# This file defines the processing rules for language identification tasks.
###############################################################################

processing-target :: langident-target

langident-target :: impresso-lid-stage1a-target # impresso-lid-stage1b-target impresso-lid-stage2-target impresso-lid-statistics impresso-lid-eval
# VARIBALE: 

# all LID systems to use 
LANGIDENT_LID_SYSTEMS_OPTION ?= langid impresso_ft wp_ft impresso_langident_pipeline lin

# fast text models
LANGIDENT_IMPPRESSO_FASTTEXT_MODEL_OPTION ?= models/fasttext/impresso-lid.bin
LANGIDENT_WIKIPEDIA_FASTTEXT_MODEL_OPTION ?= models/fasttext/lid.176.bin

# minimal text length threshold for automatic LID in stage 1 and 2
LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION ?= 100
LANGIDENT_STAGE1B_MINIMAL_TEXT_LENGTH_OPTION ?= 200
LANGIDENT_STAGE2_MINIMAL_TEXT_LENGTH_OPTION ?= 50

LANGIDENT_STAGE1A_ALPHABETICAL_THRESHOLD_OPTION ?= 0.5

# hyperparameters for scoring the languages
LANGIDENT_BOOST_FACTOR_OPTION ?= 1.5
LANGIDENT_WEIGHT_LB_IMPRESSO_OPTION ?= 6
LANGIDENT_MINIMAL_VOTING_SCORE_OPTION ?= 0.5
LANGIDENT_STAGE1_MINIMAL_LID_PROBABILITY_OPTION ?= 0.20
LANGIDENT_STAGE2_MINIMAL_LID_PROBABILITY_OPTION ?= 0.5
LANGIDENT_MINIMAL_VOTE_SCORE_OPTION ?= 1.5


# FUNCTION: LocalRebuiltToLangIdentStage1File
# Converts a local rebuilt file name to a local langident stage1 file name
define LocalRebuiltToLangIdentStage1File
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX)=$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2)
endef

# VARIABLE: LOCAL_LANGIDENT_STAGE1_FILES
# Stores the list of BBOX quality assessment files based on canonical stamp files
LOCAL_LANGIDENT_STAGE1_FILES := \
    $(call LocalRebuiltToLangIdentStage1File,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_LANGIDENT_STAGE1_FILES)


# TARGET: impresso-lid-stage1a-target
# Apply language identification classification tools
#
# Processes initial language identification for each content item.
impresso-lid-stage1a-target : $(LOCAL_LANGIDENT_STAGE1_FILES)

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2
#: Rule to process a single newspaper





$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX) 
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{  set +e ; \
     python3 lib/language_identification.py \
        --infile $(call LocalToS3,$<,$(LOCAL_REBUILT_STAMP_SUFFIX)) \
        --outfile $@ \
        --lids $(LANGIDENT_LID_SYSTEMS_OPTION) \
        --impresso-ft $(LANGIDENT_IMPPRESSO_FASTTEXT_MODEL_OPTION) \
        --wp-ft $(LANGIDENT_WIKIPEDIA_FASTTEXT_MODEL_OPTION) \
        --minimal-text-length $(LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION) \
		--alphabetical-ratio-threshold $(LANGIDENT_STAGE1A_ALPHABETICAL_THRESHOLD_OPTION) \
		--round-ndigits 3 \
		--git-describe $(GIT_VERSION) \
          --logfile $@.log.gz ; \
    EXIT_CODE=$$? ; \
    echo "Processing exit code: $$EXIT_CODE" ; \
      if [ $$EXIT_CODE -eq 0 ] ; then \
          echo "Processing completed successfully. Uploading logfile..." ; \
          python3 -m impresso_cookbook.s3_to_local_stamps \
              $(call LocalToS3,$@,'').log.gz \
              --upload-file $@.log.gz \
        --force-overwrite ; \
	        python3 -m impresso_cookbook.s3_to_local_stamps\
              $(call LocalToS3,$@,'') \
              --upload-file $@ \
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

# DOUBLE-COLON-TARGET: impresso-lid-stage1b-target
# Collect language identification statistics
#
# Summarizes statistics from Stage 1a results.
#impresso-lid-stage1b-target ::
#    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-stage1b-files



# DOUBLE-COLON-TARGET: impresso-lid-stage2-target
# Finalize language decisions and diagnostics
#
# Processes Stage 2 results and generates diagnostics.
#impresso-lid-stage2-target ::
#    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-stage2-files

# DOUBLE-COLON-TARGET: impresso-lid-statistics
# Generate statistics
#
# Produces statistics from processed data.
#impresso-lid-statistics ::
#    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-stage2-diagnostics-files-manifest-target

# DOUBLE-COLON-TARGET: impresso-lid-eval
# Evaluate against gold standard
#
# Compares results with a gold standard for evaluation.
#impresso-lid-eval ::
#    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-stage2-eval

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_langident.mk)
