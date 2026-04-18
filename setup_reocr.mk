$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_reocr.mk)
###############################################################################
# SETUP TARGETS
###############################################################################

setup:: check-reocr-tools

check-reocr-tools:
	@command -v tesseract >/dev/null 2>&1 || (echo "Missing required command: tesseract"; exit 1)
	@command -v ssh >/dev/null 2>&1 || (echo "Missing required command: ssh"; exit 1)

.PHONY: check-reocr-tools

check-reocr-tunnel-env:
	@test -n "$$IMPRESSO_CANTALOUPE_USER" || (echo "Missing IMPRESSO_CANTALOUPE_USER"; exit 1)
	@test -n "$$IMPRESSO_CANTALOUPE_PASS" || (echo "Missing IMPRESSO_CANTALOUPE_PASS"; exit 1)
	@test -n "$$IIIF_SSH_USER" || (echo "Missing IIIF_SSH_USER"; exit 1)
	@test -n "$$IIIF_SSH_HOST" || (echo "Missing IIIF_SSH_HOST"; exit 1)

.PHONY: check-reocr-tunnel-env

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_reocr.mk)
