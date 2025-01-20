$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup.mk)

###############################################################################
# GENERAL SETUP TARGETS
# Basic setup functionality and directory management
###############################################################################

# TARGET: %.d
# Creates directory if it doesn't exist
%.d:
	mkdir -p $@

# TARGET: update-requirements
# Updates Python package requirements from Pipenv
update-requirements:
	pipenv requirements > requirements.txt

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup.mk)
