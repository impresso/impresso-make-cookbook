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

reocr-tunnel: check-reocr-tools check-reocr-tunnel-env
	$(PYTHON) lib/cli_iiif_tunnel.py

.PHONY: reocr-tunnel

check-reocr-tunnel: check-reocr-tools check-reocr-tunnel-env
	$(PYTHON) lib/cli_iiif_tunnel.py --check

.PHONY: check-reocr-tunnel

help-setup::
	@echo "  reocr-tunnel       # Open and keep the IIIF SSH tunnel alive for parallel re-OCR"
	@echo "  check-reocr-tunnel # Check whether the local IIIF tunnel port is already open"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_reocr.mk)
