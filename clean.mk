$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/clean.mk)

###############################################################################
# CLEANUP TARGETS
# Targets for cleaning build artifacts and sync status
###############################################################################

clean :: clean-build

.PHONY: clean

help::
	@echo "  clean            # Cleans the build directory and all processed data"


# TARGET: clean-build
#: Removes entire build directory and all processed data
clean-build:
	# Removing build directory and all processed data in $(BUILD_DIR)/...
	rm -rvf $(BUILD_DIR) || true
	# Finished cleaning build directory

.PHONY: clean-build

# DOUBLE-COLON-TARGET: clean-sync
#: Removes locally synced materials from S3
clean-sync :: clean-sync-input clean-sync-output

.PHONY: clean-sync

help::
	@echo "  clean-sync         # Removes locally synced materials from S3"


# TARGET: clean-sync-input
#: Removes locally synced materials from S3
clean-sync-input ::
	# Removing synchronized input data in $(BUILD_DIR)/...

.PHONY: clean-sync-input

# TARGET: clean-sync-output
#: Removes locally synced materials from S3
clean-sync-output ::
	# Removing synchronized output data in in $(BUILD_DIR)/...

.PHONY: clean-sync-output

$(call log.debug, COOKBOOK END INCLUDE: cookbook/clean.mk)
