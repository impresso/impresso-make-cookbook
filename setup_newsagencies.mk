$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_newsagencies.mk)

###############################################################################
# SETUP TARGETS
# Targets for setting up the newsagencies environment
###############################################################################


setup:: check-newsagencies-dummy


# TARGET: check-template-dummy
check-newsagencies-dummy:
	@echo "newsagencies setup done"
.PHONY: check-template-dummy

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_newsagencies.mk)
