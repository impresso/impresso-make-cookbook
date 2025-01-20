$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_lingproc.mk)

###############################################################################
# SETUP TARGETS
# Targets for setting up the linguistic processing environment
###############################################################################

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

# TARGET: setup
# Prepares local directories and validates dependencies
setup:
	# Create the local directory
	mkdir -p $(LOCAL_PATH_REBUILT)
	mkdir -p $(LOCAL_PATH_LINGPROC)
	$(MAKE) newspaper-list-target
	$(MAKE) check-spacy-pipelines

# TARGET: check-spacy-pipelines
# Validates spacy pipeline installations
check-spacy-pipelines:
	$(MAKE_SILENCE_RECIPE)python3 -m spacy validate || \
	{ echo "Spacy pipelines are not properly installed! Please install the required pipelines." ; exit 1; }

PHONY_TARGETS += check-spacy-pipelines


PHONY_TARGETS += setup



check-python-installation:
	#
	# TEST PYTHON INSTALLATION FOR mallet topic inference ...
	python3 lib/test_jpype_installation.py || \
	{ echo "Double check whether the required python packages are installed! or you running in the correct python environment!" ; exit 1; }
	# OK: PYTHON ENVIRONMENT IS FINE!

PHONY_TARGETS +=  check-python-installation
$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_lingproc.mk)
