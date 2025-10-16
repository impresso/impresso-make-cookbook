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
langident-target : impresso-lid-systems-target impresso-lid-statistics-target  impresso-lid-ensemble-target # impresso-lid-statistics impresso-lid-eval

.PHONY: langident-target


# === USER-VARIABLES (Common to all stages) ====================================

# USER-VARIABLE: LANGIDENT_LOGGING_LEVEL
# Option to specify logging level for language identification.
# Uses the global LOGGING_LEVEL as default, can be overridden for langident-specific logging.
LANGIDENT_LOGGING_LEVEL ?= $(LOGGING_LEVEL)
  $(call log.debug, LANGIDENT_LOGGING_LEVEL)


# USER-VARIABLE: LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify a default minimal text length for all stages.
# The different stages can override this value as needed.
# If the text length is below this threshold, the language identification will not be
# performed or included in statistics or ensemble predictions. The default language will
# be used instead.
# The following USER-VARIABLES default to this value if not set explicitly:
# - LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION
# - LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION
# - LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION

LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION ?= 100
  $(call log.debug, LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION)


# === USER-VARIABLES (SYSTEMS stage, excluding statistics) =====================

# USER-VARIABLE: LANGIDENT_SYSTEMS_LIDS_OPTION
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
LANGIDENT_SYSTEMS_LIDS_OPTION ?= langid impresso_ft wp_ft impresso_langident_pipeline lingua
  $(call log.info, LANGIDENT_SYSTEMS_LIDS_OPTION)

# USER-VARIABLE: LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION
# Option to specify the Impresso FastText model for language identification.
# This variable allows the user to set the path to the Impresso FastText model
# that will be used in the language identification processing.
LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION ?= models/fasttext/impresso-lid.bin
  $(call log.debug, LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION)

# USER-VARIABLE: LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION
# Option to specify the Wikipedia FastText model for language identification.
# This variable allows the user to set the path to the Wikipedia FastText model
# that will be used in the language identification processing.
LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION ?= models/fasttext/lid.176.bin
  $(call log.debug, LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION)


# USER-VARIABLE: LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for systems language identification.
# This variable sets the minimum length of text that will be considered for
# language identification in systems processing.
# If the text length is below this threshold, the language identification will not be
# performed.

LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION ?= $(LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION)
  $(call log.debug, LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION)

# USER-VARIABLE: LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for statistics language identification.
# This variable sets the minimum length of text that will be considered for
# language identification in statistics processing.
# If the text length is below this threshold, the language identification will not be
# performed.
# This is used to filter out very short texts that may not provide enough context for
# accurate language identification.
LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION ?= $(LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION)
  $(call log.debug, LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION)


# === USER-VARIABLES (ENSEMBLE stage) =====================


# USER-VARIABLE: LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for ensemble language identification.
# This variable sets the minimum length of text that will be considered for
# language identification in ensemble processing.
# If the text length is below this threshold, the language identification will not be
# performed.
# This is used to ensure that only sufficiently long texts are processed in ensemble,
LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION ?= $(LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION)
  $(call log.debug, LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION)

# USER-VARIABLE: LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION
# Option to specify the threshold for the ratio of alphabetical characters in systems.
# This variable sets the minimum ratio of alphabetical characters required for a text to
# be considered for language identification in systems processing.
# If the ratio of alphabetical characters is below this threshold, the text will not be
# processed for language identification.
# This is used to filter out texts that may not be suitable for language identification
# due to a low proportion of alphabetical content.
LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION)

# USER-VARIABLE: LANGIDENT_STATISTICS_BOOST_FACTOR_OPTION
# Option to specify the boost factor for language identification scoring.
# This variable sets the factor by which the scores of certain languages are boosted
# during the language identification process.
# It is used to adjust the influence of specific languages in the scoring mechanism,
# allowing for more flexibility in how languages are prioritized based on their scores.
LANGIDENT_STATISTICS_BOOST_FACTOR_OPTION ?= 1.5
  $(call log.debug, LANGIDENT_STATISTICS_BOOST_FACTOR_OPTION)

# USER-VARIABLE: LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION
# Option to specify the minimal vote score for statistics generation.
LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION)

# === USER-VARIABLES (ENSEMBLE stage) ==========================================
# USER-VARIABLE: LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION
# Option to specify the weight for the Impresso FastText model in language identification.
# This variable sets the weight assigned to the Impresso FastText model when scoring
# languages during the language identification process.
LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION ?= 3
  $(call log.debug, LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION)

# USER-VARIABLE: LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION
# Option to specify the minimal voting score for language identification.
# This variable sets the minimum score required for a language to be considered as a
# valid identification in the language identification process.
LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION)

# USER-VARIABLE: LANGIDENT_OCRQA_OPTION
# Option to enable OCR quality assessment using impresso_pipelines.ocrqa
# Set to --ocrqa to enable OCR QA, or leave empty to disable
LANGIDENT_OCRQA_OPTION ?= 
  $(call log.debug, LANGIDENT_OCRQA_OPTION)

# USER-VARIABLE: LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION
# Confidence threshold for trusting original language metadata.
LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION ?= 0.75
  $(call log.debug, LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION)

# USER-VARIABLE: LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION
# Dominance ratio threshold above which non-dominant languages are penalized.
LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION ?= 0.9
  $(call log.debug, LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION)

# USER-VARIABLE: LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION
# Minimal probability for a LID decision to be considered a vote in stage 2.
LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION)

# USER-VARIABLE: LANGIDENT_ROUND_NDIGITS_OPTION
# Option to specify the number of decimal places for probability rounding in language identification.
# This variable sets the number of decimal places to which language identification probabilities
# will be rounded in the output.
LANGIDENT_ROUND_NDIGITS_OPTION ?= 3
  $(call log.debug, LANGIDENT_ROUND_NDIGITS_OPTION)

# USER-VARIABLE: LANGIDENT_LOGGING_LEVEL
# Option to specify logging level for language identification.
# Uses the global LOGGING_LEVEL as default, can be overridden for langident-specific logging
LANGIDENT_LOGGING_LEVEL ?= $(LOGGING_LEVEL)
  $(call log.debug, LANGIDENT_LOGGING_LEVEL)

# USER-VARIABLE: LANGIDENT_VALIDATE_OPTION
# Option to enable JSON schema validation for ensemble output.
# Set to --validate to enable validation against impresso schema, or leave empty to disable
LANGIDENT_VALIDATE_OPTION ?= 
  $(call log.debug, LANGIDENT_VALIDATE_OPTION)

# USER-VARIABLE: LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION
# Option to specify admissible languages for ensemble decisions.
# Space-separated list of language codes to restrict ensemble decisions to, or leave empty for no restrictions
LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION ?= 
  $(call log.debug, LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION
# Option to specify newspapers that should exclude Luxembourgish language predictions in the ensemble stage.
# Space-separated list of newspaper acronym prefixes, or leave empty for no exclusions
LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION ?= 
  $(call log.debug, LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION)

# Missing variables for statistics generation that are referenced in the statistics rule
# USER-VARIABLE: LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION
# Option to specify the minimal vote score for statistics generation.
LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION)

# USER-VARIABLE: LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION
# Minimal probability for a LID decision to be considered in systems processing.
LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION)

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
impresso-lid-systems-target : $(LOCAL_LANGIDENT_STAGE1_FILES)

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2
#: Rule to process a single newspaper
ifeq ($(USE_CANONICAL),1)

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 (canonical version)
#: Rule to process a single newspaper from canonical format
$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2: $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	python3 lib/impresso_langident_systems.py \
		$(LANGIDENT_FORMAT_OPTION) \
		--infile $(call LocalToS3,$(basename $<),'') \
		--issue-file $(call LocalToS3,$(call CanonicalPagesToIssuesPath,$(basename $<)),'') \
		--outfile $@ \
		--lids $(LANGIDENT_SYSTEMS_LIDS_OPTION ?= langid impresso_ft wp_ft impresso_langident_pipeline lingua
) \
		--impresso-ft $(LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION) \
		--wp-ft $(LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION) \
		--minimal-text-length $(LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION) \
		--alphabetical-ratio-threshold $(LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION) \
		--round-ndigits $(LANGIDENT_ROUND_NDIGITS_OPTION) \
		--git-describe $(GIT_VERSION) \
		--log-file $@.log.gz \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
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
	python3 lib/impresso_langident_systems.py \
		$(LANGIDENT_FORMAT_OPTION) \
		--infile $(call LocalToS3,$<,$(LOCAL_REBUILT_STAMP_SUFFIX)) \
		--outfile $@ \
		--lids $(LANGIDENT_SYSTEMS_LIDS_OPTION) \
		--impresso-ft $(LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION) \
		--wp-ft $(LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION) \
		--minimal-text-length $(LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION) \
		--alphabetical-ratio-threshold $(LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION) \
		--round-ndigits $(LANGIDENT_ROUND_NDIGITS_OPTION) \
		--git-describe $(GIT_VERSION) \
		--log-file $@.log.gz \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		$(LANGIDENT_OCRQA_OPTION) \
	&& python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp \
		$@ $(call LocalToS3,$@,'') \
		$@.log.gz $(call LocalToS3,$@,'').log.gz \
	|| { rm -vf $@ ; exit 1 ; }

endif

# DOUBLE-COLON-TARGET: impresso-lid-stage1b-target
# Collect language identification statistics
#
# Summarizes statistics from systems results.
impresso-lid-statistics-target : $(LOCAL_LANGIDENT_STATISTICS_FILES)

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STATISTICS)/%.stats.json
# Rule to generate statistics for a single newspaper from systems results
$(LOCAL_PATH_LANGIDENT_SYSTEMS)/stats.json: $(LOCAL_LANGIDENT_SYSTEMS_FILES) 
	$(MAKE_SILENCE_RECIPE) \
	python3 lib/newspaper_statistics.py \
    --lids $(LANGIDENT_SYSTEMS_LIDS_OPTION) \
    --boosted-lids orig_lg impresso_ft \
    --minimal-text-length $(LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION) \
    --boost-factor $(LANGIDENT_STATISTICS_BOOST_FACTOR_OPTION) \
    --minimal-vote-score $(LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION) \
    --minimal-lid-probability $(LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION) \
    --git-describe $(GIT_VERSION) \
    --log-level $(LANGIDENT_LOGGING_LEVEL) \
    --log-file $@.log.gz \
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

impresso-lid-ensemble-target :: $(LOCAL_LANGIDENT_FILES)


# rule for building all ensemble files


$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2 $(LOCAL_PATH_LANGIDENT)/%.diagnostics.json: $(LOCAL_PATH_LANGIDENT_SYSTEMS)/%.jsonl.bz2 $(LOCAL_PATH_LANGIDENT_SYSTEMS)/stats.json
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) \
  && \
  python3 lib/impresso_ensemble_lid.py \
    --lids $(LANGIDENT_SYSTEMS_LIDS_OPTION ?= langid impresso_ft wp_ft impresso_langident_pipeline lingua
) \
    --weight-lb-impresso-ft $(LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION) \
    --minimal-lid-probability $(LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION) \
    --minimal-voting-score $(LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION) \
    --minimal-text-length $(LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION) \
    --threshold_confidence_orig_lg $(LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION) \
    --newspaper-stats-filename $(call LocalToS3,$(word 2,$^),'') \
    --git-describe $(GIT_VERSION) \
    --alphabetical-ratio-threshold  $(LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION) \
    --dominant-language-threshold $(LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION) \
    --diagnostics-json $(patsubst %.jsonl.bz2,%.diagnostics.json,$@) \
    --infile $< \
    --outfile $@ \
    --log-level $(LANGIDENT_LOGGING_LEVEL) \
    --log-file $@.log.gz \
    $(LANGIDENT_VALIDATE_OPTION) \
    $(if $(LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION),--admissible-languages $(LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION),) \
    $(if $(LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION),--exclude-lb $(LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION),) \
  && \
  python3 -m impresso_cookbook.local_to_s3 \
    --set-timestamp \
    $@    $(call LocalToS3,$@,'') \
    $@.log.gz    $(call LocalToS3,$@,'').log.gz \
    $(patsubst %.jsonl.bz2,%.diagnostics.json,$@)    $(call LocalToS3,$(patsubst %.jsonl.bz2,%.diagnostics.json,$@),'') \
    || { rm -vf $@ ; exit 1 ; }

# DOUBLE-COLON-TARGET: impresso-lid-ensemble-target
# Finalize language decisions and diagnostics
#
# Processes ensemble results and generates diagnostics.
#impresso-lid-ensemble-target ::
#    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-ensemble-files

# DOUBLE-COLON-TARGET: impresso-lid-statistics
# Generate statistics
#
# Produces statistics from processed data.
#impresso-lid-statistics ::
#    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-ensemble-diagnostics-files-manifest-target

# DOUBLE-COLON-TARGET: impresso-lid-eval
# Evaluate against gold standard
#
# Compares results with a gold standard for evaluation.
#impresso-lid-eval ::
#    $(MAKE) $(MAKEFILEFLAG) -f $(firstword $(MAKEFILE_LIST)) impresso-lid-ensemble-eval

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_langident.mk)
