ifndef COOKBOOK_COMPLETENESS_INCLUDED
COOKBOOK_COMPLETENESS_INCLUDED := 1
$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/completeness.mk)

###############################################################################
# READ-ONLY COLLECTION COMPLETENESS
# Include after the parent has selected COMPLETENESS_TASK and task settings.
# No sync, processing, stamp invalidation, or remote mutation dependencies.
###############################################################################

# USER-VARIABLE: COMPLETENESS_REPORT_DIR
# Use distinct directories for concurrent audits.
COMPLETENESS_REPORT_DIR ?= $(BUILD_DIR)/reports/completeness/$(COMPLETENESS_TASK)
  $(call log.info, COMPLETENESS_REPORT_DIR)
# USER-VARIABLE: COMPLETENESS_CONCURRENCY
COMPLETENESS_CONCURRENCY ?= 16
  $(call log.debug, COMPLETENESS_CONCURRENCY)
# USER-VARIABLE: COMPLETENESS_STREAMS
# Empty follows CANONICAL_INPUT_KIND; otherwise comma-separated issues,pages,audios.
COMPLETENESS_STREAMS ?=
  $(call log.debug, COMPLETENESS_STREAMS)

# Resolve the checked-out CLI, rather than an older installed module.
COMPLETENESS_SCRIPT := $(dir $(lastword $(MAKEFILE_LIST)))lib/check_collection_completeness.py
# Quote each argument for the recipe shell, including paths containing spaces.
completeness.quote = '$(subst ','"'"',$(1))'
COMPLETENESS_ARGS = --task $(call completeness.quote,$(COMPLETENESS_TASK)) \
 --canonical-bucket $(call completeness.quote,$(S3_BUCKET_CANONICAL)) \
 --consolidated-bucket $(call completeness.quote,$(S3_BUCKET_CONSOLIDATEDCANONICAL)) \
 --run-version $(call completeness.quote,$(RUN_VERSION_CONSOLIDATEDCANONICAL)) \
 --langident-root $(call completeness.quote,s3://$(S3_BUCKET_LANGIDENT)/$(PROCESS_LABEL_LANGIDENT)/$(RUN_ID_LANGIDENT)) \
 --has-provider $(call completeness.quote,$(NEWSPAPER_HAS_PROVIDER)) \
 --canonical-input-kind $(call completeness.quote,$(CANONICAL_INPUT_KIND)) \
 --wip-max-age $(call completeness.quote,$(CONSOLIDATEDCANONICAL_WIP_MAX_AGE)) \
 --concurrency $(call completeness.quote,$(COMPLETENESS_CONCURRENCY)) \
 --output-dir $(call completeness.quote,$(COMPLETENESS_REPORT_DIR)) \
 --log-level $(call completeness.quote,$(LOGGING_LEVEL)) \
 $(if $(strip $(COMPLETENESS_STREAMS)),--check-streams $(call completeness.quote,$(COMPLETENESS_STREAMS)))

.PHONY: check-collection-completeness check-newspaper-completeness help-completeness

# Audit the existing list; deliberately do not regenerate it or synchronize S3.
check-collection-completeness::
	$(PYTHON) $(call completeness.quote,$(COMPLETENESS_SCRIPT)) $(COMPLETENESS_ARGS) \
	  --newspaper-list $(call completeness.quote,$(NEWSPAPERS_TO_PROCESS_FILE))

check-newspaper-completeness::
	$(PYTHON) $(call completeness.quote,$(COMPLETENESS_SCRIPT)) $(COMPLETENESS_ARGS) \
	  --newspaper $(call completeness.quote,$(NEWSPAPER)) \
	  $(if $(strip $(PROVIDER)),--provider $(call completeness.quote,$(PROVIDER))) \
	  $(if $(strip $(NEWSPAPER_YEARS)),--years $(call completeness.quote,$(strip $(NEWSPAPER_YEARS))))

# Advertise only when this fragment is included, including in parent help indexes.
help::
	@echo "  make help-completeness    # Read-only S3 artifact coverage audits"

help-completeness::
	@echo "READ-ONLY COMPLETENESS AUDITS:"
	@echo "  make check-collection-completeness                      # Audit the existing collection list"
	@echo "  make check-newspaper-completeness PROVIDER=BL NEWSPAPER=WTCH # Audit one newspaper"
	@echo "  make check-newspaper-completeness PROVIDER=BL NEWSPAPER=WTCH NEWSPAPER_YEARS=1900 # Audit one year"
	@echo "  Add CFG=configs/your-run.mk to use the processing run configuration."
	@echo ""
	@printf '%s\n' $(call completeness.quote,  COMPLETENESS_TASK=$(COMPLETENESS_TASK)) \
	  $(call completeness.quote,  COMPLETENESS_REPORT_DIR=$(COMPLETENESS_REPORT_DIR)) \
	  $(call completeness.quote,  COMPLETENESS_CONCURRENCY=$(COMPLETENESS_CONCURRENCY)) \
	  $(call completeness.quote,  COMPLETENESS_STREAMS=$(COMPLETENESS_STREAMS)) \
	  $(call completeness.quote,  NEWSPAPERS_TO_PROCESS_FILE=$(NEWSPAPERS_TO_PROCESS_FILE)) \
	  $(call completeness.quote,  CANONICAL_INPUT_KIND=$(CANONICAL_INPUT_KIND)) \
	  $(call completeness.quote,  CONSOLIDATEDCANONICAL_WIP_MAX_AGE=$(CONSOLIDATEDCANONICAL_WIP_MAX_AGE))
	@echo ""
	@echo "Checks artifact presence/nonzero sizes, prerequisites, and locks; not record/schema validity."
	@echo "Writes JSON/TSV locally. Does not sync, process, or repair. Use distinct report directories for concurrent audits."
	@echo "A failing Make command does not distinguish audit gaps from audit errors; inspect the JSON exit_code (0/1/2)."

$(call log.debug, COOKBOOK END INCLUDE: cookbook/completeness.mk)
endif
