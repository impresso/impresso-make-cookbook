$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_langident.mk)
###############################################################################
# Processing Language Identification
# Makefile for processing impresso language identification
#
# This file defines the processing rules for language identification tasks.
###############################################################################

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes processed input language identification data.
#
# This target ensures that language identification input data is
# retrieved from S3 and stored locally for further processing.
sync-input :: sync-rebuilt


# DOUBLE-COLON-TARGET: sync-output
# Synchronizes processed output language identification data.
#
# This target ensures that language identification output data is
# retrieved from S3 and stored locally for further analysis.
sync-output :: sync-langident


processing-target :: langident-target

langident-target :: impresso-lid-stage1a-target impresso-lid-stage1b-target  impresso-lid-stage2-target # impresso-lid-statistics impresso-lid-eval
# VARIBALE: 

# all LID systems to use 
LANGIDENT_LID_SYSTEMS_OPTION ?= langid impresso_ft wp_ft impresso_langident_pipeline lingua

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
LANGIDENT_WEIGHT_LB_IMPRESSO_OPTION ?= 3
LANGIDENT_MINIMAL_VOTING_SCORE_OPTION ?= 0.5
LANGIDENT_STAGE1_MINIMAL_LID_PROBABILITY_OPTION ?= 0.20
LANGIDENT_STAGE2_MINIMAL_LID_PROBABILITY_OPTION ?= 0.5
LANGIDENT_MINIMAL_VOTE_SCORE_OPTION ?= 1


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


# FUNCTION: LocalLangIdentStage1ToStage1bFile
# Converts a local langident stage1 file name to a local langident stage1b stats file name
define LocalLangIdentStage1ToStage1bFile
$(1:$(LOCAL_PATH_LANGIDENT_STAGE1)/$(NEWSPAPER)-%.jsonl.bz2=$(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json)
endef

# VARIABLE: LOCAL_LANGIDENT_STAGE1B_FILES
# Stores the list of langident stage1b statistics files based on stage1 files
LOCAL_LANGIDENT_STAGE1B_FILES := \
    $(sort $(call LocalLangIdentStage1ToStage1bFile,$(LOCAL_LANGIDENT_STAGE1_FILES)))

$(call log.debug, LOCAL_LANGIDENT_STAGE1B_FILES)

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
        --logfile $@.log.gz  \
    && python3 -m impresso_cookbook.local_to_s3 \
      $@ $(call LocalToS3,$@,'') \
      $@.log.gz $(call LocalToS3,$@,'').log.gz \
    || { rm -vf $@ ; exit 1 ; }

# DOUBLE-COLON-TARGET: impresso-lid-stage1b-target
# Collect language identification statistics
#
# Summarizes statistics from Stage 1a results.
impresso-lid-stage1b-target : $(LOCAL_LANGIDENT_STAGE1B_FILES)

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1B)/%.stats.json
# Rule to generate statistics for a single newspaper from stage1 results
$(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json: $(LOCAL_PATH_LANGIDENT_STAGE1)/
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	python3 lib/newspaper_statistics.py \
        --lids $(LANGIDENT_LID_SYSTEMS_OPTION) \
        --boosted-lids orig_lg impresso_ft \
        --minimal-text-length $(LANGIDENT_STAGE1B_MINIMAL_TEXT_LENGTH_OPTION) \
        --boost-factor $(LANGIDENT_BOOST_FACTOR_OPTION) \
        --minimal-vote-score $(LANGIDENT_MINIMAL_VOTE_SCORE_OPTION) \
        --minimal-lid-probability $(LANGIDENT_STAGE1_MINIMAL_LID_PROBABILITY_OPTION) \
        --git-describe $(GIT_VERSION) \
        --logfile $@.log.gz \
        --outfile $@ \
        $(call LocalToS3,$<,'') \
    && python3 -m impresso_cookbook.local_to_s3 \
      $@ $(call LocalToS3,$@,'') \
      $@.log.gz $(call LocalToS3,$@,'').log.gz \
    || { rm -vf $@ ; exit 1 ; }


# FUNCTION: LocalRebuiltToLangIdentFile
# Converts a local rebuilt file name to a local langident file name
define LocalRebuiltToLangIdentFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX)=$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2)
endef

# VARIABLE: LOCAL_LANGIDENT_FILES
# Stores the list of BBOX quality assessment files based on canonical stamp files
LOCAL_LANGIDENT_FILES := \
    $(call LocalRebuiltToLangIdentFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_LANGIDENT_FILES)

impresso-lid-stage2-target :: $(LOCAL_LANGIDENT_FILES)


# rule for building all stage 2 files


$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2 $(LOCAL_PATH_LANGIDENT)/%.diagnostics.json: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
     python3 lib/impresso_ensemble_lid.py \
        --lids $(LANGIDENT_LID_SYSTEMS_OPTION) \
        --weight-lb-impresso-ft $(LANGIDENT_WEIGHT_LB_IMPRESSO_OPTION) \
        --minimal-lid-probability $(LANGIDENT_STAGE2_MINIMAL_LID_PROBABILITY_OPTION) \
        --minimal-voting-score $(LANGIDENT_MINIMAL_VOTING_SCORE_OPTION) \
        --minimal-text-length $(LANGIDENT_STAGE2_MINIMAL_TEXT_LENGTH_OPTION) \
        --newspaper-stats-filename $(call LocalToS3,$(word 2,$^),'') \
        --git-describe $(GIT_VERSION) \
        --alphabetical-ratio-threshold  $(LANGIDENT_STAGE1A_ALPHABETICAL_THRESHOLD_OPTION) \
        --diagnostics-json $(patsubst %.jsonl.bz2,%.diagnostics.json,$@) \
        --infile $< \
        --outfile $@ \
        --log-level $(LOGGING_LEVEL) \
        --log-file $@.log.gz \
    && python3 -m impresso_cookbook.local_to_s3 \
      $@    $(call LocalToS3,$@,'') \
      $(patsubst %.jsonl.bz2,%.diagnostics.json,$@)    $(call LocalToS3,$(patsubst %.jsonl.bz2,%.diagnostics.json,$@),'') \
      $@.log.gz    $(call LocalToS3,$@,'').log.gz \
    || { rm -vf $@ ; exit 1 ; }

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
