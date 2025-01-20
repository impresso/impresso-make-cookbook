###############################################################################
# CLEANUP TARGETS
# Targets for cleaning build artifacts and sync status
###############################################################################

$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/clean.mk)

# TARGET: clean-newspaper
# Removes newspaper-specific sync status and artifacts
clean-newspaper: clean-sync
	
PHONY_TARGETS += clean-newspaper

# TARGET: clean-build
# Removes entire build directory and all processed data
clean-build:
	rm -rvf $(BUILD_DIR)

PHONY_TARGETS += clean-build

# TARGET: resync
# Forces complete resynchronization with remote server
# Steps:
# 1. Clean newspaper artifacts
# 2. Perform fresh sync
resync: clean-newspaper
	$(MAKE) sync

PHONY_TARGETS += resync

# TARGET: resync-output
# Forces resynchronization of output data only
resync-output: clean-sync-lingproc
	$(MAKE) sync-output

$(call log.debug, COOKBOOK END INCLUDE: cookbook/clean.mk)
