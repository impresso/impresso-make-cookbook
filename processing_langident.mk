$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_langident.mk)
###############################################################################
# Orchestrating Language Identification and OCR Quality Assessment
# Makefile for processing impresso language identification (and optionally OCR QA)
#
# === Language Identification Processing Pipeline ===
#
# The language identification pipeline consists of three stages that must execute
# in strict sequence to ensure data dependencies are satisfied:
#
# Stage 1 (Systems): langident-systems-target
#   - Applies multiple LID systems (langid, impresso_ft, wp_ft, etc.) to each content item
#   - Generates stage1 files: $(LOCAL_PATH_LANGIDENT_STAGE1)/NEWSPAPER-YEAR.jsonl.bz2
#   - Each file contains predictions from all configured LID systems
#
# Stage 2 (Statistics): langident-statistics-target
#   - Aggregates statistics across all stage1 files per newspaper
#   - Generates: $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json
#   - Contains dominant language, language distributions, and confidence metrics
#   - **Depends on Stage 1**: Requires all stage1 files to compute statistics
#
# Stage 3 (Ensemble): langident-ensemble-target
#   - Makes final language decisions using ensemble voting across LID systems
#   - Generates final output: $(LOCAL_PATH_LANGIDENT)/NEWSPAPER-YEAR.jsonl.bz2
#   - **Depends on Stages 1 & 2**: Each ensemble file requires both:
#     * Its corresponding stage1 file (NEWSPAPER-YEAR.jsonl.bz2)
#     * The newspaper statistics file (stats.json)
#
# === Parallel Processing and Sequential Dependencies ===
#
# When running with parallel jobs (e.g., make -j 8), Make will attempt to build
# all targets concurrently unless explicit dependencies prevent it. The phony
# targets (langident-*-target) enforce sequential execution:
#
#   langident-ensemble-target depends on langident-statistics-target
#   langident-statistics-target depends on langident-systems-target
#
# This ensures that even with parallel execution at the file level (processing
# multiple newspapers simultaneously), the three stages complete in order:
#   1. All stage1 files are created
#   2. Statistics file is generated from stage1 files
#   3. Ensemble files are created from stage1 files + statistics
#
# File-level dependencies (e.g., ensemble file depends on stage1 file) ensure
# correct ordering within each stage, while phony target dependencies ensure
# correct ordering between stages.
###############################################################################


# === INTEGRATION HOOKS ========================================================

# USER-VARIABLE: USE_CANONICAL
# Flag to use canonical input instead of rebuilt input.
#
# Set to 1 to use canonical input, empty or 0 for rebuilt input.
USE_CANONICAL ?= 1
  $(call log.debug, USE_CANONICAL)


# Conditional input synchronization based on format
ifeq ($(USE_CANONICAL),1)

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes canonical data when USE_CANONICAL=1.
sync-input :: sync-canonical

else

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes rebuilt data when USE_CANONICAL != 1.
sync-input :: sync-rebuilt

endif


# DOUBLE-COLON-TARGET: sync-output
# Synchronizes processed output language identification data.
#
# This target ensures that language identification output data is
# retrieved from S3 and stored locally for further analysis.
sync-output :: sync-langident


# DOUBLE-COLON-TARGET: clean-sync-output
# Needed for resync-output target to sync fresh output from other machines.
clean-sync-output :: clean-sync-langident


# DOUBLE-COLON-TARGET: processing-target
# Hook target for language identification.
processing-target :: langident-target


# === USER-CONFIGURABLE VARIABLES (Common to all stages) ======================

# USER-VARIABLE: LANGIDENT_LOGGING_LEVEL
# Option to specify logging level for language identification.
#
# Uses the global LOGGING_LEVEL as default, can be overridden for langident-specific logging.
LANGIDENT_LOGGING_LEVEL ?= $(LOGGING_LEVEL)
  $(call log.debug, LANGIDENT_LOGGING_LEVEL)


# USER-VARIABLE: LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify a default minimal text length for all stages.
#
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


# USER-VARIABLE: LANGIDENT_ROUND_NDIGITS_OPTION
# Option to specify the number of decimal places for probability rounding in language identification.
#
# This variable sets the number of decimal places to which language identification probabilities
# will be rounded in the output.
LANGIDENT_ROUND_NDIGITS_OPTION ?= 3
  $(call log.debug, LANGIDENT_ROUND_NDIGITS_OPTION)


# USER-VARIABLE: LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION
# Option to specify the threshold for the ratio of alphabetical characters in systems.
#
# This variable sets the minimum ratio of alphabetical characters required for a text to
# be considered for language identification in systems processing.
# If the ratio of alphabetical characters is below this threshold, the text will not be
# processed for language identification.
# This is used to filter out texts that may not be suitable for language identification
# due to a low proportion of alphabetical content.
LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION)


# === USER-CONFIGURABLE VARIABLES (Stage 1: Systems) ==========================

# USER-VARIABLE: LANGIDENT_SYSTEMS_LIDS_OPTION
# Option to specify language identification systems to use.
#
# This variable allows the user to select which language identification systems
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
#
# This variable allows the user to set the path to the Impresso FastText model
# that will be used in the language identification processing.
LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION ?= models/fasttext/impresso-lid.bin
  $(call log.debug, LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION)


# USER-VARIABLE: LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION
# Option to specify the Wikipedia FastText model for language identification.
#
# This variable allows the user to set the path to the Wikipedia FastText model
# that will be used in the language identification processing.
LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION ?= models/fasttext/lid.176.bin
  $(call log.debug, LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION)


# USER-VARIABLE: LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for systems language identification.
#
# This variable sets the minimum length of text that will be considered for
# language identification in systems processing.
# If the text length is below this threshold, the language identification will not be
# performed.
LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION ?= $(LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION)
  $(call log.debug, LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION)


# USER-VARIABLE: LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION
# Minimal probability for a LID decision to be considered in systems processing.
LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION)


# === USER-CONFIGURABLE VARIABLES (Stage 2: Statistics) =======================

# USER-VARIABLE: LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for statistics language identification.
#
# This variable sets the minimum length of text that will be considered for
# language identification in statistics processing.
# If the text length is below this threshold, the language identification will not be
# performed.
# This is used to filter out very short texts that may not provide enough context for
# accurate language identification.
LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION ?= $(LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION)
  $(call log.debug, LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION)


# USER-VARIABLE: LANGIDENT_STATISTICS_BOOST_FACTOR_OPTION
# Option to specify the boost factor for language identification scoring.
#
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


# === USER-CONFIGURABLE VARIABLES (Stage 3: Ensemble) =========================

# USER-VARIABLE: LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for ensemble language identification.
#
# This variable sets the minimum length of text that will be considered for
# language identification in ensemble processing.
# If the text length is below this threshold, the language identification will not be
# performed.
# This is used to ensure that only sufficiently long texts are processed in ensemble.
LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION ?= $(LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION)
  $(call log.debug, LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION
# Option to specify the weight for the Impresso FastText model in language identification.
#
# This variable sets the weight assigned to the Impresso FastText model when scoring
# languages during the language identification process.
LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION ?= 3
  $(call log.debug, LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION
# Option to specify the minimal voting score for language identification.
#
# This variable sets the minimum score required for a language to be considered as a
# valid identification in the language identification process.
LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION
# Confidence threshold for trusting original language metadata.
LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION ?= 0.75
  $(call log.debug, LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION
# Dominance ratio threshold above which non-dominant languages are penalized.
LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION ?= 0.9
  $(call log.debug, LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION
# Minimal probability for a LID decision to be considered a vote in ensemble stage.
LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION)


# USER-VARIABLE: LANGIDENT_VALIDATE_OPTION
# Option to enable JSON schema validation for ensemble output.
#
# Set to --validate to enable validation against impresso schema, or leave empty to disable.
LANGIDENT_VALIDATE_OPTION ?=
  $(call log.debug, LANGIDENT_VALIDATE_OPTION)


# USER-VARIABLE: LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION
# Option to specify admissible languages for ensemble decisions.
#
# Space-separated list of language codes to restrict ensemble decisions to, or leave empty for no restrictions.
LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION ?=
  $(call log.debug, LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION
# Option to specify newspapers that should exclude Luxembourgish language predictions in the ensemble stage.
#
# Space-separated list of newspaper acronym prefixes, or leave empty for no exclusions.
LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION ?=
  $(call log.debug, LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION)


# === USER-CONFIGURABLE VARIABLES (OCR Quality Assessment) ====================

# USER-VARIABLE: LANGIDENT_OCRQA_OPTION
# Option to enable OCR quality assessment using impresso_pipelines.ocrqa
#
# Set to --ocrqa to enable OCR QA, or leave empty to disable.
LANGIDENT_OCRQA_OPTION ?=
  $(call log.debug, LANGIDENT_OCRQA_OPTION)


# USER-VARIABLE: LANGIDENT_OCRQA_REPO_OPTION
# Option to specify the Hugging Face repository for OCR QA models.
#
# Example: impresso-project/OCR-quality-assessment-unigram
LANGIDENT_OCRQA_REPO_OPTION ?=
  $(call log.debug, LANGIDENT_OCRQA_REPO_OPTION)


# USER-VARIABLE: LANGIDENT_OCRQA_VERSION_OPTION
# Option to specify the version/revision of OCR QA models (branch, tag, or commit hash).
#
# Example: main, v2.0.0, or a commit hash
LANGIDENT_OCRQA_VERSION_OPTION ?=
  $(call log.debug, LANGIDENT_OCRQA_VERSION_OPTION)


# === USER-CONFIGURABLE VARIABLES (Work-In-Progress Management) ===============

# USER-VARIABLE: LANGIDENT_WIP_ENABLED
# Option to enable work-in-progress (WIP) file management to prevent concurrent processing.
#
# Set to 1 to enable WIP checks, or leave empty to disable
# When enabled, the system will:
# - Check for existing WIP files on S3 before starting processing
# - Create WIP files to signal work in progress
# - Remove stale WIP files (older than LANGIDENT_WIP_MAX_AGE)
# - Remove WIP files after successful completion
LANGIDENT_WIP_ENABLED ?= 1
  $(call log.debug, LANGIDENT_WIP_ENABLED)


# USER-VARIABLE: LANGIDENT_WIP_MAX_AGE
# Maximum age in hours for WIP files before considering them stale.
#
# If a WIP file is older than this value, it will be removed and processing can proceed.
# Can be fractional (e.g., 0.1 for 6 minutes, useful for testing).
# Default: 1 hour
LANGIDENT_WIP_MAX_AGE ?= 1
  $(call log.debug, LANGIDENT_WIP_MAX_AGE)


# === INTERNAL COMPUTED VARIABLES ==============================================

# Conditional format option based on USE_CANONICAL
ifeq ($(USE_CANONICAL),1)

# VARIABLE: LANGIDENT_FORMAT_OPTION
# Format option for language identification processing.
LANGIDENT_FORMAT_OPTION := --format=canonical
  $(call log.debug, LANGIDENT_FORMAT_OPTION)

else

# VARIABLE: LANGIDENT_FORMAT_OPTION
# Format option for language identification processing.
LANGIDENT_FORMAT_OPTION := --format=rebuilt
  $(call log.debug, LANGIDENT_FORMAT_OPTION)

endif


# === PATH TRANSFORMATION FUNCTIONS ============================================

# FUNCTION: LocalRebuiltToLangidentStage1File
# Converts a local rebuilt stamp file name to a local langident stage1 file name.
#
# Rebuilt stamps match S3 file names exactly (no suffix).
define LocalRebuiltToLangidentStage1File
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2)
endef


# FUNCTION: LocalCanonicalStampToLangidentSystemsFile
# Converts a canonical stamp file name to a local langident stage1 file name.
#
# Canonical stamps have hard-coded .stamp suffix for yearly directories.
define LocalCanonicalStampToLangidentSystemsFile
$(1:$(LOCAL_PATH_CANONICAL_PAGES)/%.stamp=$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2)
endef

# FUNCTION: CanonicalPagesToIssuesPath
# Converts a canonical pages path to the corresponding issues metadata path.
#
# Example: build.d/112-canonical-final/BL/AATA/pages/AATA-1846 -> build.d/112-canonical-final/BL/AATA/issues/AATA-1846-issues.jsonl.bz2
define CanonicalPagesToIssuesPath
$(subst /pages/,/issues/,$(1))-issues.jsonl.bz2
endef


# FUNCTION: LocalLangIdentSystemsToStatisticsFile
# Converts a local langident systems file name to a local langident statistics file name.
#
# Takes any systems .jsonl.bz2 file and maps it to the stats.json file in the same directory.
define LocalLangIdentSystemsToStatisticsFile
$(dir $(1))stats.json
endef

# FUNCTION: LocalCanonicalStampToLangidentStatsFile
# Converts a canonical stamp file name to a local langident stats file name.
# E.g. LOCAL_PATH_CANONICAL_PAGES = build.d/112-canonical-final/SNL/EDA/pages
# E.g. LOCAL_PATH_LANGIDENT_STAGE1 = build.d/115-canonical-processed-final/langident/langident-lid_stage1-ensemble_multilingual_v2-0-2/SNL/EDA
# E.g. build.d/112-canonical-final/SNL/EDA/pages/{EDA-1843}.stamp -> build.d/115-canonical-processed-final/langident/langident-lid_stage1-ensemble_multilingual_v2-0-2/SNL/EDA/stats.json
define LocalCanonicalStampToLangidentStatsFile
$(1:$(LOCAL_PATH_CANONICAL_PAGES)/%.stamp=$(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json)
endef


# FUNCTION: LocalLangIdentSystemsToEnsembleFile
# Converts a local langident systems file name to a local langident ensemble file name.
#
# Takes systems file path and changes stage1 directory to final output directory.
define LocalLangIdentSystemsToEnsembleFile
$(1:$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2=$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2)
endef

# FUNCTION: LocalLangIdentSystemsToDiagnosticsFile
# Converts a local langident systems file name to a local langident diagnostics file name.
#
# Takes systems file path and changes stage1 directory to final output directory.
define LocalLangIdentSystemsToDiagnosticsFile
$(1:$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2=$(LOCAL_PATH_LANGIDENT)/%.diagnostics.json)
endef



# === COMPUTED FILE LISTS ======================================================

# VARIABLE: LOCAL_LANGIDENT_SYSTEMS_FILES
# Stores the list of language identification stage1 files based on rebuilt or canonical stamp files.
ifeq ($(USE_CANONICAL),1)
LOCAL_LANGIDENT_SYSTEMS_FILES := \
    $(call LocalCanonicalStampToLangidentSystemsFile,$(LOCAL_CANONICAL_PAGES_STAMP_FILE_LIST))
else
LOCAL_LANGIDENT_SYSTEMS_FILES := \
    $(call LocalRebuiltToLangidentStage1File,$(LOCAL_REBUILT_STAMP_FILES))
endif

  $(call log.debug,LOCAL_LANGIDENT_SYSTEMS_FILES)



# VARIABLE: LOCAL_LANGIDENT_STATISTICS_FILES
# Stores the list of langident stage1b statistics files based on stage1 files.
LOCAL_LANGIDENT_STATISTICS_FILES := \
    $(sort $(call LocalLangIdentSystemsToStatisticsFile,$(LOCAL_LANGIDENT_SYSTEMS_FILES)))

  $(call log.debug, LOCAL_LANGIDENT_STATISTICS_FILES)


# VARIABLE: LOCAL_LANGIDENT_ENSEMBLE_FILES
# Stores the list of final langident ensemble files based on systems files.
#
# Transforms systems files from LOCAL_PATH_LANGIDENT_STAGE1 to LOCAL_PATH_LANGIDENT.
LOCAL_LANGIDENT_ENSEMBLE_FILES := \
    $(call LocalLangIdentSystemsToEnsembleFile,$(LOCAL_LANGIDENT_SYSTEMS_FILES)) \
    $(call LocalLangIdentSystemsToDiagnosticsFile,$(LOCAL_LANGIDENT_SYSTEMS_FILES))

  $(call log.debug, LOCAL_LANGIDENT_ENSEMBLE_FILES)


# === MAIN PROCESSING PIPELINE =================================================

# TARGET: langident-target
#: Processes language identification tasks in three sequential stages.
#
# Overall processing target for language identification.
langident-target : langident-ensemble-target

.PHONY: langident-target


# TARGET: langident-systems-target
# Apply different language identification systems.
#
# Uses recursive make to recompute file lists after sync creates new stamp files.
ifeq ($(USE_CANONICAL),1)

langident-systems-target : $(LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) langident-systems-files-target

else

langident-systems-target : $(LOCAL_REBUILT_SYNC_STAMP_FILE)
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) langident-systems-files-target

endif

.PHONY: langident-systems-target


# TARGET: langident-systems-files-target
# Internal target that builds the actual language identification system files.
#
# This is called recursively after sync to ensure stamp files are available.
langident-systems-files-target : $(LOCAL_LANGIDENT_SYSTEMS_FILES)

.PHONY: langident-systems-files-target


# TARGET: langident-statistics-target
# Collect language identification statistics from all stage1 files.
#
# This target generates newspaper-level statistics (dominant language, language
# distributions, confidence metrics) by aggregating data from all stage1 files
# for the current newspaper.
#
# Dependencies:
#   - langident-systems-target: Ensures all stage1 files are created first
#
# Uses recursive make to ensure stage1 output exists before building statistics.
#
# Output:
#   - $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json: Newspaper statistics file
langident-statistics-target : langident-systems-target
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) langident-statistics-files-target

.PHONY: langident-statistics-target


# TARGET: langident-statistics-files-target
# Internal target that builds the actual statistics file.
#
# This is called recursively after systems stage to ensure files are available.
langident-statistics-files-target : $(LOCAL_LANGIDENT_STATISTICS_FILES)

.PHONY: langident-statistics-files-target


# TARGET: langident-ensemble-target
# Generate final language identification decisions using ensemble voting.
#
# This target creates the final output files by combining predictions from
# multiple LID systems using ensemble decision-making algorithms.
#
# Dependencies:
#   - langident-statistics-target: Ensures statistics are computed first
#
# Uses recursive make to ensure statistics exist before building ensemble files.
#
# Each ensemble file depends on (via file-level rule below):
#   - $(LOCAL_PATH_LANGIDENT_STAGE1)/NEWSPAPER-YEAR.jsonl.bz2: Stage1 predictions
#   - $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json: Newspaper statistics
#
# The explicit dependency on langident-statistics-target ensures that when
# running with parallel jobs, the statistics stage completes before any ensemble
# processing begins, preventing race conditions.
langident-ensemble-target : langident-statistics-target
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) langident-ensemble-files-target

.PHONY: langident-ensemble-target


# TARGET: langident-ensemble-files-target
# Internal target that builds the actual ensemble files.
#
# This is called recursively after statistics stage to ensure files are available.
langident-ensemble-files-target : $(LOCAL_LANGIDENT_ENSEMBLE_FILES)

.PHONY: langident-ensemble-files-target


# === STAGE 1: SYSTEMS FILE RULES ==============================================

ifeq ($(USE_CANONICAL),1)

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 (canonical version)
#: Rule to process a single newspaper from canonical format.
$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2: $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	$(if $(LANGIDENT_WIP_ENABLED), \
	python3 -m impresso_cookbook.local_to_s3 \
		--s3-file-exists $(call LocalToS3,$@) \
		--create-wip --wip-max-age $(LANGIDENT_WIP_MAX_AGE) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		$@ $(call LocalToS3,$@) \
		$@.log.gz $(call LocalToS3,$@).log.gz \
	|| { test $$? -eq 2 && exit 0; exit 1; } \
	&& , ) \
	python3 lib/impresso_langident_systems.py \
		$(LANGIDENT_FORMAT_OPTION) \
		--infile $(call LocalToS3,$(basename $<)) \
		--issue-file $(call LocalToS3,$(call CanonicalPagesToIssuesPath,$(basename $<))) \
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
		$(if $(LANGIDENT_OCRQA_REPO_OPTION),--ocrqa-repo $(LANGIDENT_OCRQA_REPO_OPTION),) \
		$(if $(LANGIDENT_OCRQA_VERSION_OPTION),--ocrqa-version $(LANGIDENT_OCRQA_VERSION_OPTION),) \
	&& python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp --log-level $(LANGIDENT_LOGGING_LEVEL) \
		$(if $(LANGIDENT_WIP_ENABLED),--remove-wip,) \
		$@ $(call LocalToS3,$@) \
		$@.log.gz $(call LocalToS3,$@).log.gz \
	|| { rm -vf $@ ; \
	     $(if $(LANGIDENT_WIP_ENABLED), \
	     python3 -m impresso_cookbook.local_to_s3 --remove-wip \
	         --log-level $(LANGIDENT_LOGGING_LEVEL) \
	         $@ $(call LocalToS3,$@) \
	         $@.log.gz $(call LocalToS3,$@).log.gz || true ; , ) \
	     exit 1 ; }

else

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 (rebuilt version)
#: Rule to process a single newspaper from rebuilt format.
#
# Rebuilt stamps match S3 file names exactly (no suffix to strip).
$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	$(if $(LANGIDENT_WIP_ENABLED), \
	python3 -m impresso_cookbook.local_to_s3 \
		--s3-file-exists $(call LocalToS3,$@) \
		--create-wip --wip-max-age $(LANGIDENT_WIP_MAX_AGE) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		$@ $(call LocalToS3,$@) \
		$@.log.gz $(call LocalToS3,$@).log.gz \
	|| { test $$? -eq 2 && exit 0; exit 1; } \
	&& , ) \
	python3 lib/impresso_langident_systems.py \
		$(LANGIDENT_FORMAT_OPTION) \
		--infile $(call LocalToS3,$<) \
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
		$(if $(LANGIDENT_OCRQA_REPO_OPTION),--ocrqa-repo $(LANGIDENT_OCRQA_REPO_OPTION),) \
		$(if $(LANGIDENT_OCRQA_VERSION_OPTION),--ocrqa-version $(LANGIDENT_OCRQA_VERSION_OPTION),) \
	&& python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp --log-level $(LANGIDENT_LOGGING_LEVEL) \
		--keep-timestamp-only \
		$(if $(LANGIDENT_WIP_ENABLED),--remove-wip,) \
		$@ $(call LocalToS3,$@) \
		$@.log.gz $(call LocalToS3,$@).log.gz \
	|| { rm -vf $@ ; \
	     $(if $(LANGIDENT_WIP_ENABLED), \
	     python3 -m impresso_cookbook.local_to_s3 --remove-wip \
	         --log-level $(LANGIDENT_LOGGING_LEVEL) \
	         $@ $(call LocalToS3,$@) \
	         $@.log.gz $(call LocalToS3,$@).log.gz || true ; , ) \
	     exit 1 ; }

endif


# === STAGE 2: STATISTICS FILE RULES ===========================================

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json
# Rule to generate statistics for a single newspaper from systems results.
#
# If stats.json stamp already exists (from sync), this rule won't run.
# Otherwise generates new statistics from systems files.
# Uses stamp file for stats.json to track S3 synchronization state.
$(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json: $(LOCAL_LANGIDENT_SYSTEMS_FILES)
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(dir $@) && \
	python3 lib/newspaper_statistics.py \
		--newspaper $(notdir $(NEWSPAPER)) \
		--lids $(LANGIDENT_SYSTEMS_LIDS_OPTION) \
		--boosted-lids orig_lg impresso_ft \
		--minimal-text-length $(LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION) \
		--boost-factor $(LANGIDENT_STATISTICS_BOOST_FACTOR_OPTION) \
		--minimal-vote-score $(LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION) \
		--minimal-lid-probability $(LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION) \
		--git-describe $(GIT_VERSION) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		--log-file $(dir $@)stats.json.log.gz \
		--outfile $(dir $@)stats.json \
		$(call LocalToS3,$(dir $<)) \
	&& \
	python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp --log-level $(LANGIDENT_LOGGING_LEVEL) \
		--keep-timestamp-only --upload-if-newer \
		$(if $(LANGIDENT_WIP_ENABLED),--remove-wip,) \
		$(dir $@)stats.json $(call LocalToS3,$(dir $@)stats.json) \
		$(dir $@)stats.json.log.gz $(call LocalToS3,$(dir $@)stats.json.log.gz) \
	|| { rm -vf $@ ; \
		$(if $(LANGIDENT_WIP_ENABLED), \
		python3 -m impresso_cookbook.local_to_s3 \
			--remove-wip \
			--log-level $(LANGIDENT_LOGGING_LEVEL) \
			$(dir $@)stats.json $(call LocalToS3,$(dir $@)stats.json) \
			$(dir $@)stats.json.log.gz $(call LocalToS3,$(dir $@)stats.json.log.gz) || true ; , ) \
		exit 1 ; }


# === STAGE 3: ENSEMBLE FILE RULES =============================================

# PATTERN-FILE-RULE: $(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2
#: Rule to build ensemble decisions with diagnostics.
#
# Each ensemble file depends on:
#   1. Its corresponding Stage 1a file (with predictions from all LID systems)
#   2. The newspaper-level stats.json file (Stage 1b statistics)
#
# Note: File stamps match S3 names exactly (no suffix), so stats.json is just stats.json.
$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2 $(LOCAL_PATH_LANGIDENT)/%.diagnostics.json: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) \
  && \
  $(if $(LANGIDENT_WIP_ENABLED), \
  python3 -m impresso_cookbook.local_to_s3 \
    --s3-file-exists $(call LocalToS3,$@) \
    --create-wip --wip-max-age $(LANGIDENT_WIP_MAX_AGE) \
    --log-level $(LANGIDENT_LOGGING_LEVEL) \
    $@ $(call LocalToS3,$@) \
    $@.log.gz $(call LocalToS3,$@).log.gz \
    $(patsubst %.jsonl.bz2,%.diagnostics.json,$@) $(call LocalToS3,$(patsubst %.jsonl.bz2,%.diagnostics.json,$@)) \
  || { test $$? -eq 2 && exit 0; exit 1; } \
  && , ) \
  python3 lib/impresso_ensemble_lid.py \
    --lids $(LANGIDENT_SYSTEMS_LIDS_OPTION) \
    --weight-lb-impresso-ft $(LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION) \
    --minimal-lid-probability $(LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION) \
    --minimal-voting-score $(LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION) \
    --minimal-text-length $(LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION) \
    --threshold_confidence_orig_lg $(LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION) \
    --newspaper-stats-filename $(call LocalToS3,$(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json) \
    --git-describe $(GIT_VERSION) \
    --alphabetical-ratio-threshold  $(LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION) \
    --dominant-language-threshold $(LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION) \
    --diagnostics-json $(patsubst %.jsonl.bz2,%.diagnostics.json,$@) \
    --infile $(call LocalToS3,$<) \
    --outfile $@ \
    --log-level $(LANGIDENT_LOGGING_LEVEL) \
    --log-file $@.log.gz \
    $(LANGIDENT_VALIDATE_OPTION) \
    $(if $(LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION),--admissible-languages $(LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION),) \
    $(if $(LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION),--exclude-lb $(LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION),) \
  && \
  python3 -m impresso_cookbook.local_to_s3 \
    --set-timestamp --upload-if-newer  \
	--log-level $(LANGIDENT_LOGGING_LEVEL) \
    $(if $(LANGIDENT_WIP_ENABLED),--remove-wip,) \
    $@    $(call LocalToS3,$@) \
    $@.log.gz    $(call LocalToS3,$@).log.gz \
    $(patsubst %.jsonl.bz2,%.diagnostics.json,$@)    $(call LocalToS3,$(patsubst %.jsonl.bz2,%.diagnostics.json,$@)) \
  || { rm -vf $@ $(patsubst %.jsonl.bz2,%.diagnostics.json,$@) ; \
       $(if $(LANGIDENT_WIP_ENABLED), \
       python3 -m impresso_cookbook.local_to_s3 --remove-wip \
           --log-level $(LANGIDENT_LOGGING_LEVEL) \
           $@ $(call LocalToS3,$@) \
           $@.log.gz $(call LocalToS3,$@).log.gz \
           $(patsubst %.jsonl.bz2,%.diagnostics.json,$@) $(call LocalToS3,$(patsubst %.jsonl.bz2,%.diagnostics.json,$@)) || true ; , ) \
       exit 1 ; }

# DOUBLE-COLON-TARGET: langident-ensemble-target
# Finalize language decisions and diagnostics
#
# Processes ensemble results and generates diagnostics.
#langident-ensemble-target ::
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
