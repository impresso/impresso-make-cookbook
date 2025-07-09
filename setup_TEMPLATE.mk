$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_TEMPLATE.mk)

###############################################################################
# SETUP TARGETS
# Targets for setting up the TEMPLATE environment
###############################################################################


setup:: check-python-installation-hf


# TARGET: check-template-dummy
check-template-dummy:
	@echo "TEMPLATE setup done"
.PHONY: check-template-dummy

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_TEMPLATE.mk)
