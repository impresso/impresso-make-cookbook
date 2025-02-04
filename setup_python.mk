$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_python.mk)

###############################################################################
# PYTHON SETUP TARGETS
# Targets for setting up the Python environment including pip and pipenv
###############################################################################


# USER-VARIABLE: PYTHON_MAJOR_VERSION
PYTHON_MINOR_VERSION ?= 11
  $(call log.debug, PYTHON_MINOR_VERSION)


# TARGET: setup-python
#: Sets up the Python environment including pip and pipenv
setup-python: install-python install-pip install-pipenv

PHONY_TARGETS += setup-python


# TARGET: install-python
#: Installs Python 3.$(PYTHON_MINOR_VERSION) based on the operating system
ifeq ($(OS),Linux)
install-python:
	# Install Python 3.$(PYTHON_MINOR_VERSION) if not available
	if ! which python3.$(PYTHON_MINOR_VERSION) > /dev/null; then \
		sudo apt update && \
		sudo apt install -y python3.$(PYTHON_MINOR_VERSION) python3.$(PYTHON_MINOR_VERSION)-distutils; \
	fi
	if ! python3.$(PYTHON_MINOR_VERSION) -mpip help > /dev/null; then \
		curl -sS https://bootstrap.pypa.io/get-pip.py | sudo python3.$(PYTHON_MINOR_VERSION); \
	fi
else ifeq ($(OS),Darwin)
install-python:
	# Install Python 3.$(PYTHON_MINOR_VERSION) if not available
	if ! which python3.$(PYTHON_MINOR_VERSION) > /dev/null; then \
		brew install python@3.$(PYTHON_MINOR_VERSION); \
	fi
	if ! python3.$(PYTHON_MINOR_VERSION) -mpip help > /dev/null; then \
		curl -sS https://bootstrap.pypa.io/get-pip.py | python3.$(PYTHON_MINOR_VERSION); \
	fi
endif

PHONY_TARGETS += install-python


# TARGET: install-pip
#: Installs pip for the specified Python version if not available
install-pip:
	# Install pip if not available
	if ! python3.$(PYTHON_MINOR_VERSION) -mpip help > /dev/null; then \
		curl -sS https://bootstrap.pypa.io/get-pip.py | python3.$(PYTHON_MINOR_VERSION); \
	fi

PHONY_TARGETS += install-pip


# TARGET: install-pipenv
#: Installs pipenv for the specified Python version if not available
install-pipenv:
	# Install pipenv if not available
	if ! python3.$(PYTHON_MINOR_VERSION) -mpipenv --version > /dev/null; then \
		python3.$(PYTHON_MINOR_VERSION) -mpip install pipenv ; \
	fi

PHONY_TARGETS += install-pipenv


$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_python.mk)
