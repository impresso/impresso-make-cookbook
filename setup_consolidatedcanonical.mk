$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_consolidatedcanonical.mk)

###############################################################################
# SETUP TARGETS
# Targets for setting up the consolidatedcanonical environment
###############################################################################


setup:: check-consolidatedcanonical-dummy


# TARGET: check-template-dummy
check-consolidatedcanonical-dummy:
	@echo "consolidatedcanonical setup done"
.PHONY: check-template-dummy

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_consolidatedcanonical.mk)
