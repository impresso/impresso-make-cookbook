$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_langident.mk)
###############################################################################
# Processing Language Identification
# Makefile for processing impresso language identification
#
# This file defines the processing rules for language identification tasks.
###############################################################################

# USER-VARIABLE: USE_CANONICAL
# Flag to use canonical format instead of rebuilt format
# Set to 1 or true to use canonical format, empty or 0 for rebuilt format
USE_CANONICAL ?= 
  $(call log.debug, USE_CANONICAL)

# Conditional input synchronization based on format
ifeq ($(USE_CANONICAL),1)
# DOUBLE-COLON-TARGET: sync-input
# Synchronizes canonical data when using canonical format.
sync-input :: sync-canonical

# USER-VARIABLE: LANGIDENT_FORMAT_OPTION  
# Format option for language identification processing
LANGIDENT_FORMAT_OPTION := --format=canonical
  $(call log.debug, Using canonical format)

else
# DOUBLE-COLON-TARGET: sync-input
# Synchronizes rebuilt data when using rebuilt format.
sync-input :: sync-rebuilt

# USER-VARIABLE: LANGIDENT_FORMAT_OPTION
# Format option for language identification processing  
LANGIDENT_FORMAT_OPTION := --format=rebuilt
  $(call log.debug, Using rebuilt format)

endif

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes processed output language identification data.
#
# This target ensures that language identification output data is
# retrieved from S3 and stored locally for further analysis.
sync-output :: sync-langident

# DOUBLE-COLON-TARGET: langident-target
# Processing target for language identification.
#
processing-target :: langident-target

# TARGET: langident-target
#: Processes language identification tasks.#
langident-target : impresso-lid-stage1a-target impresso-lid-stage1b-target  impresso-lid-stage2-target # impresso-lid-statistics impresso-lid-eval

.PHONY: langident-target

# USER-VARIABLE: LANGIDENT_LID_SYSTEMS_OPTION
# Option to specify language identification systems to use.
## This variable allows the user to select which language identification systems
# will be used in the processing.
# Available systems:
# - langid: Original langid.py library (supports many languages including 'lb')
# - langdetect: Python port of Google's language-detection library (many languages, no 'lb')
# - wp_ft: Wikipedia FastText model (supports many languages including 'lb')
# - impresso_ft: Custom Impresso FastText model (supports fr/de/lb/en/it)
# - impresso_langident_pipeline: Impresso-specific pipeline from impresso-pipelines
# - lingua: Lingua language detector (high accuracy, supports many languages including 'lb')
# The user can modify this variable to include or exclude specific systems as needed.
LANGIDENT_LID_SYSTEMS_OPTION ?= langid impresso_ft wp_ft impresso_langident_pipeline lingua
  $(call log.info, LANGIDENT_LID_SYSTEMS_OPTION)

# USER-VARIABLE: LANGIDENT_IMPPRESSO_FASTTEXT_MODEL_OPTION
# Option to specify the Impresso FastText model for language identification.
# This variable allows the user to set the path to the Impresso FastText model
# that will be used in the language identification processing.
LANGIDENT_IMPPRESSO_FASTTEXT_MODEL_OPTION ?= models/fasttext/impresso-lid.bin
  $(call log.debug, LANGIDENT_IMPPRESSO_FASTTEXT_MODEL_OPTION)

# USER-VARIABLE: LANGIDENT_WIKIPEDIA_FASTTEXT_MODEL_OPTION
# Option to specify the Wikipedia FastText model for language identification.
# This variable allows the user to set the path to the Wikipedia FastText model
# that will be used in the language identification processing.
LANGIDENT_WIKIPEDIA_FASTTEXT_MODEL_OPTION ?= models/fasttext/lid.176.bin
  $(call log.debug, LANGIDENT_WIKIPEDIA_FASTTEXT_MODEL_OPTION)

# minimal text length threshold for automatic LID in stage 1 and 2
# USER-VARIABLE: LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for stage 1a language identification.
# This variable sets the minimum length of text that will be considered for
# language identification in stage 1a processing.
# If the text length is below this threshold, the language identification will not be
# performed.

LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION ?= 100
  $(call log.debug, LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION)

# USER-VARIABLE: LANGIDENT_STAGE1B_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for stage 1b language identification.
# This variable sets the minimum length of text that will be considered for
# language identification in stage 1b processing.
# If the text length is below this threshold, the language identification will not be
# performed.
# This is used to filter out very short texts that may not provide enough context for
# accurate language identification.
LANGIDENT_STAGE1B_MINIMAL_TEXT_LENGTH_OPTION ?= 200
  $(call log.debug, LANGIDENT_STAGE1B_MINIMAL_TEXT_LENGTH_OPTION)

# USER-VARIABLE: LANGIDENT_STAGE2_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for stage 2 language identification.
# This variable sets the minimum length of text that will be considered for
# language identification in stage 2 processing.
# If the text length is below this threshold, the language identification will not be
# performed.
# This is used to ensure that only sufficiently long texts are processed in stage 2,
LANGIDENT_STAGE2_MINIMAL_TEXT_LENGTH_OPTION ?= 50
  $(call log.debug, LANGIDENT_STAGE2_MINIMAL_TEXT_LENGTH_OPTION)

# USER-VARIABLE: LANGIDENT_STAGE1A_ALPHABETICAL_THRESHOLD_OPTION
# Option to specify the threshold for the ratio of alphabetical characters in stage 1a.
# This variable sets the minimum ratio of alphabetical characters required for a text to
# be considered for language identification in stage 1a processing.
# If the ratio of alphabetical characters is below this threshold, the text will not be
# processed for language identification.
# This is used to filter out texts that may not be suitable for language identification
# due to a low proportion of alphabetical content.
LANGIDENT_STAGE1A_ALPHABETICAL_THRESHOLD_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_STAGE1A_ALPHABETICAL_THRESHOLD_OPTION)

# hyperparameters for scoring the languages
# USER-VARIABLE: LANGIDENT_BOOST_FACTOR_OPTION
# Option to specify the boost factor for language identification scoring.
# This variable sets the factor by which the scores of certain languages are boosted
# during the language identification process.
# It is used to adjust the influence of specific languages in the scoring mechanism,
# allowing for more flexibility in how languages are prioritized based on their scores.
LANGIDENT_BOOST_FACTOR_OPTION ?= 1.5
  $(call log.debug, LANGIDENT_BOOST_FACTOR_OPTION)

# USER-VARIABLE: LANGIDENT_WEIGHT_LB_IMPRESSO_OPTION
# Option to specify the weight for the Impresso FastText model in language identification.
# This variable sets the weight assigned to the Impresso FastText model when scoring
# languages during the language identification process.
LANGIDENT_WEIGHT_LB_IMPRESSO_OPTION ?= 3
  $(call log.debug, LANGIDENT_WEIGHT_LB_IMPRESSO_OPTION)

# USER-VARIABLE: LANGIDENT_MINIMAL_VOTING_SCORE_OPTION
# Option to specify the minimal voting score for language identification.
# This variable sets the minimum score required for a language to be considered as a
# valid identification in the language identification process.
LANGIDENT_MINIMAL_VOTE_SCORE_OPTION ?= 1
  $(call log.debug, LANGIDENT_MINIMAL_VOTE_SCORE_OPTION)

# USER-VARIABLE: LANGIDENT_OCRQA_OPTION
# Option to enable OCR quality assessment using impresso_pipelines.ocrqa
# Set to --ocrqa to enable OCR QA, or leave empty to disable
LANGIDENT_OCRQA_OPTION ?= 
  $(call log.debug, LANGIDENT_OCRQA_OPTION)

# FUNCTION: LocalRebuiltToLangIdentStage1File
# Converts a local rebuilt file name to a local langident stage1 file name
define LocalRebuiltToLangIdentStage1File
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX)=$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2)
endef

# FUNCTION: LocalCanonicalToLangIdentStage1File
# Converts a canonical stamp file name to a local langident stage1 file name
define LocalCanonicalToLangIdentStage1File
$(1:$(LOCAL_PATH_CANONICAL_PAGES)/%.stamp=$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2)
endef

# VARIABLE: LOCAL_LANGIDENT_STAGE1_FILES
# Stores the list of language identification stage1 files based on rebuilt or canonical stamp files
ifeq ($(USE_CANONICAL),1)
LOCAL_LANGIDENT_STAGE1_FILES := \
    $(call LocalCanonicalToLangIdentStage1File,$(LOCAL_CANONICAL_PAGES_STAMP_FILES))
else
LOCAL_LANGIDENT_STAGE1_FILES := \
    $(call LocalRebuiltToLangIdentStage1File,$(LOCAL_REBUILT_STAMP_FILES))
endif

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
ifeq ($(USE_CANONICAL),1)

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 (canonical version)
#: Rule to process a single newspaper from canonical format
$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2: $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	python3 lib/language_identification.py \
		$(LANGIDENT_FORMAT_OPTION) \
		--infile $(call LocalToS3,$(basename $<),'') \
		--issue-file $(call LocalToS3,$(call CanonicalPagesToIssuesPath,$(basename $<)),'') \
		--outfile $@ \
		--lids $(LANGIDENT_LID_SYSTEMS_OPTION) \
		--impresso-ft $(LANGIDENT_IMPPRESSO_FASTTEXT_MODEL_OPTION) \
		--wp-ft $(LANGIDENT_WIKIPEDIA_FASTTEXT_MODEL_OPTION) \
		--minimal-text-length $(LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION) \
		--alphabetical-ratio-threshold $(LANGIDENT_STAGE1A_ALPHABETICAL_THRESHOLD_OPTION) \
		--round-ndigits 3 \
		--git-describe $(GIT_VERSION) \
		--logfile $@.log.gz \
		$(LANGIDENT_OCRQA_OPTION) \
	&& python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp \
		$@ $(call LocalToS3,$@,'') \
		$@.log.gz $(call LocalToS3,$@,'').log.gz \
	|| { rm -vf $@ ; exit 1 ; }

else

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 (rebuilt version)  
#: Rule to process a single newspaper from rebuilt format
$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX) 
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	python3 lib/language_identification.py \
		$(LANGIDENT_FORMAT_OPTION) \
		--infile $(call LocalToS3,$<,$(LOCAL_REBUILT_STAMP_SUFFIX)) \
		--outfile $@ \
		--lids $(LANGIDENT_LID_SYSTEMS_OPTION) \
		--impresso-ft $(LANGIDENT_IMPPRESSO_FASTTEXT_MODEL_OPTION) \
		--wp-ft $(LANGIDENT_WIKIPEDIA_FASTTEXT_MODEL_OPTION) \
		--minimal-text-length $(LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION) \
		--alphabetical-ratio-threshold $(LANGIDENT_STAGE1A_ALPHABETICAL_THRESHOLD_OPTION) \
		--round-ndigits 3 \
		--git-describe $(GIT_VERSION) \
		--logfile $@.log.gz \
		$(LANGIDENT_OCRQA_OPTION) \
	&& python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp \
		$@ $(call LocalToS3,$@,'') \
		$@.log.gz $(call LocalToS3,$@,'').log.gz \
	|| {
		--outfile $@ \
		--lids $(LANGIDENT_LID_SYSTEMS_OPTION) \
		--impresso-ft $(LANGIDENT_IMPPRESSO_FASTTEXT_MODEL_OPTION) \
		--wp-ft $(LANGIDENT_WIKIPEDIA_FASTTEXT_MODEL_OPTION) \
		--minimal-text-length $(LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION) \
		--alphabetical-ratio-threshold $(LANGIDENT_STAGE1A_ALPHABETICAL_THRESHOLD_OPTION) \
		--round-ndigits 3 \
		--git-describe $(GIT_VERSION) \
		--logfile $@.log.gz \
	&& python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp \
		$@ $(call LocalToS3,$@,'') \
		$@.log.gz $(call LocalToS3,$@,'').log.gz \
	|| { rm -vf $@ ; exit 1 ; }

endif

# DOUBLE-COLON-TARGET: impresso-lid-stage1b-target
# Collect language identification statistics
#
# Summarizes statistics from Stage 1a results.
impresso-lid-stage1b-target : $(LOCAL_LANGIDENT_STAGE1B_FILES)

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1B)/%.stats.json
# Rule to generate statistics for a single newspaper from stage1 results
$(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json: $(LOCAL_LANGIDENT_STAGE1_FILES) 
	$(MAKE_SILENCE_RECIPE) \
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
    $(call LocalToS3,$(dir $<),'') \
  && \
  python3 -m impresso_cookbook.local_to_s3 \
    --set-timestamp \
    $@ $(call LocalToS3,$@,'') \
    $@.log.gz $(call LocalToS3,$@,'').log.gz \
  || { rm -vf $@ ; exit 1 ; }


# FUNCTION: LocalRebuiltToLangIdentFile
# Converts a local rebuilt file name to a local langident file name
define LocalRebuiltToLangIdentFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2$(LOCAL_REBUILT_STAMP_SUFFIX)=$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2)
endef

# FUNCTION: LocalCanonicalToLangIdentFile
# Converts a canonical stamp file name to a local langident file name
define LocalCanonicalToLangIdentFile
$(1:$(LOCAL_PATH_CANONICAL_PAGES)/%.stamp=$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2)
endef

# VARIABLE: LOCAL_LANGIDENT_FILES
# Stores the list of final langident files based on rebuilt or canonical stamp files
ifeq ($(USE_CANONICAL),1)
LOCAL_LANGIDENT_FILES := \
    $(call LocalCanonicalToLangIdentFile,$(LOCAL_CANONICAL_PAGES_STAMP_FILES))
else
LOCAL_LANGIDENT_FILES := \
    $(call LocalRebuiltToLangIdentFile,$(LOCAL_REBUILT_STAMP_FILES))
endif

  $(call log.debug, LOCAL_LANGIDENT_FILES)

impresso-lid-stage2-target :: $(LOCAL_LANGIDENT_FILES)


# rule for building all stage 2 files


$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2 $(LOCAL_PATH_LANGIDENT)/%.diagnostics.json: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) \
  && \
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
  && \
  python3 -m impresso_cookbook.local_to_s3 \
    --set-timestamp \
    $@    $(call LocalToS3,$@,'') \
    $@.log.gz    $(call LocalToS3,$@,'').log.gz \
    $(patsubst %.jsonl.bz2,%.diagnostics.json,$@)    $(call LocalToS3,$(patsubst %.jsonl.bz2,%.diagnostics.json,$@),'') \
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
