$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup.mk)

###############################################################################
# GENERAL SETUP TARGETS
# Basic setup functionality and directory management
###############################################################################

# Directory where build artifacts will be stored
BUILD_DIR ?= build.d

# TARGET: %.d
# Creates directory if it doesn't exist
%.d:
	mkdir -p $@


# Detect the operating system
OS ?= $(shell uname -s)
  $(call log.debug, OS)

# Initialize INSTALLER
INSTALLER ?= unknown

# If Linux, check the distribution
ifeq ($(OS),Linux)
    DISTRO := $(shell grep -Ei 'debian|ubuntu' /etc/os-release 2>/dev/null)
    ifneq ($(DISTRO),)
        INSTALLER := apt
    endif
else ifeq ($(OS),Darwin)
    INSTALLER := brew
endif
  $(call log.debug, INSTALLER)


# TARGET: update-requirements
# Updates Python package requirements from Pipenv
update-requirements:
	pipenv requirements > requirements.txt

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup.mk)
