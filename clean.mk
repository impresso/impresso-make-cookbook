$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/clean.mk)

###############################################################################
# CLEANUP TARGETS
# Targets for cleaning build artifacts and sync status
###############################################################################


# TARGET: clean-build
#: Removes entire build directory and all processed data
clean-build:
	rm -rvf $(BUILD_DIR) || true

.PHONY: clean-build

# TARGET: clean-sync-input
#: Removes locally synced materials from S3
clean-sync-input ::
	# Removing synchronized input data...

.PHONY: clean-sync-input

# TARGET: clean-sync-output
#: Removes locally synced materials from S3
clean-sync-output ::
	# Removing synchronized output data...

.PHONY: clean-sync-output

$(call log.debug, COOKBOOK END INCLUDE: cookbook/clean.mk)
