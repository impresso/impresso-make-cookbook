$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_mediasources.mk)

###############################################################################
# SETUP TARGETS
###############################################################################


setup:: check-mediasources-dummy

help-setup::
	@echo ""
	@echo "MEDIA-SOURCES SETUP:"
	@echo "  check-mediasources-dummy # Check that media-source setup is included"


# TARGET: check-mediasources-dummy
#: Check that media-source setup is included
check-mediasources-dummy:
	@echo "mediasources setup done"
.PHONY: check-mediasources-dummy

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_mediasources.mk)
