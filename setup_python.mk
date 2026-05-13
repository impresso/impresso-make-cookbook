$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_python.mk)

###############################################################################
# PYTHON SETUP TARGETS
# Targets for setting up the Python environment including pip and pipenv
###############################################################################

# DOUBLE COLON TARGET specifications

setup:: setup-python-env

setup-python-env: setup-python setup-pip setup-pipenv

help-setup::
	@echo "  setup-python-env # Set up the Python environment including pip and pipenv"

# USER-VARIABLE: PYTHON_MAJOR_VERSION
PYTHON_MINOR_VERSION ?= 11
  $(call log.debug, PYTHON_MINOR_VERSION)

PYTHON ?= $(if $(wildcard .venv/bin/python),.venv/bin/python,python3.$(PYTHON_MINOR_VERSION))
  $(call log.info, PYTHON)


# TARGET: setup-python
#: Installs Python 3.$(PYTHON_MINOR_VERSION) based on the operating system
setup-python:
ifeq ($(OS),Linux)
	# Install Python 3.$(PYTHON_MINOR_VERSION) if not available
	if ! which python3.$(PYTHON_MINOR_VERSION) > /dev/null; then \
		sudo add-apt-repository ppa:deadsnakes/ppa && \
		sudo apt update && \
		sudo apt install -y python3.$(PYTHON_MINOR_VERSION) python3.$(PYTHON_MINOR_VERSION)-distutils ; \
	fi
else ifeq ($(OS),Darwin)
	# Install Python 3.$(PYTHON_MINOR_VERSION) if not available
	if ! which python3.$(PYTHON_MINOR_VERSION) > /dev/null; then \
		brew install python@3.$(PYTHON_MINOR_VERSION); \
	fi
endif

.PHONY: setup-python


# TARGET: setup-pip
#: Installs pip for the specified Python version if not available
setup-pip:
	# Install pip if not available
	if ! python3.$(PYTHON_MINOR_VERSION) -mpip help > /dev/null; then \
		curl -sS https://bootstrap.pypa.io/get-pip.py | python3.$(PYTHON_MINOR_VERSION); \
	fi

.PHONY: setup-pip

help-setup::
	@echo "  setup-python     # Install Python 3.$(PYTHON_MINOR_VERSION) if not available"
	@echo "  setup-pip        # Install pip for Python 3.$(PYTHON_MINOR_VERSION) if not available"


# TARGET: setup-pipenv
#: Installs pipenv for the specified Python version if not available
setup-pipenv:
	# Install pipenv if not available
	if ! python3.$(PYTHON_MINOR_VERSION) -mpipenv --version > /dev/null; then \
		python3.$(PYTHON_MINOR_VERSION) -mpip install pipenv ; \
	fi

.PHONY: setup-pipenv

help-setup::
	@echo "  setup-pipenv     # Install pipenv for Python 3.$(PYTHON_MINOR_VERSION) if not available"


# TARGET: setup-pip-requirements
#: Updates pip package requirements.txt by pipenv
#
# We want requirements.txt to be more flexible for development.
# Pipfile.lock will contain the exact versions that the production system used.
setup-pip-requirements:
	pipenv lock
	pipenv requirements > requirements.txt

.PHONY: setup-pip-requirements

help-setup::
	@echo "  setup-pip-requirements # Update requirements.txt from pipenv lock data"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_python.mk)
