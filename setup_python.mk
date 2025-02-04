# USER_VARIABLE: PYTHON_MAJOR_VERSION
PYTHON_MINOR_VERSION ?= 11

# Target: setup-python
# Sets up the Python environment
setup-python: install-python install-pip install-pipenv

PHONY_TARGETS += setup-python

install-pip:
	# Install pip if not available
	if ! python3.$(PYTHON_MINOR_VERSION) -mpip help > /dev/null; then \
		curl -sS https://bootstrap.pypa.io/get-pip.py | python3.$(PYTHON_MINOR_VERSION); \
	fi

install-pipenv:
	# Install pipenv if not available
	if ! python3.$(PYTHON_MINOR_VERSION) -mpipenv --version > /dev/null; then \
		python3.$(PYTHON_MINOR_VERSION) -mpip install pipenv ; \
	fi

# TARGET: install-python
# Installs Python 3.$(PYTHON_MINOR_VERSION) based on the operating system
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
