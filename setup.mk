$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup.mk)

###############################################################################
# GENERAL SETUP TARGETS
# Basic setup functionality and directory management
###############################################################################


# USER-VARIABLE: BUILD_DIR
# The build directory where all local input and output files are stored
# The content of BUILD_DIR can be removed anytime without issues regarding s3
BUILD_DIR ?= build.d


# USER-VARIABLE: OS
# Detect the operating system if not set from outside
OS ?= $(shell uname -s)
  $(call log.debug, OS)


# VARIABLE: INSTALLER
# Defines the package manager for the software installation on operating system level

# If Linux, check the distribution
ifeq ($(OS),Linux)
  DISTRO := $(shell grep -Ei 'debian|ubuntu' /etc/os-release 2>/dev/null)
  ifneq ($(DISTRO),)
    INSTALLER := apt
  endif

# If macOS, use Homebrew
else ifeq ($(OS),Darwin)
  INSTALLER := brew
endif

# If not set, let make complain about an undefined variable here
  $(call log.debug, INSTALLER)


# PATTERN-RULE: %.d
#: Creates a directory if it doesn't exist
%.d:
	mkdir -p $@


# DOUBLE-COLON-TARGET: setup
#: Sets up the build directory and runs the active setup-<TARGET> targets
setup:: | $(BUILD_DIR)

PHONY_TARGETS += setup

# TARGET: update-pip-requirements-file
#: Updates pip package requirements.txt by pipenv
update-pip-requirements-file:
	pipenv requirements > requirements.txt

PHONY_TARGETS += update-pip-requirements-file


$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup.mk)
