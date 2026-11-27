$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_s3aggregation.mk)

###############################################################################
# SETUP TARGETS
# Targets for setting up the s3aggregation environment
###############################################################################


setup:: check-s3aggregation-dummy


# TARGET: check-template-dummy
check-s3aggregation-dummy:
	@echo "s3aggregation setup done"
.PHONY: check-template-dummy

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_s3aggregation.mk)
