$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_python.mk)

###############################################################################
# PYTHON SETUP TARGETS
# Targets for setting up the Python environment including pip and pipenv
###############################################################################

# DOUBLE COLON TARGET specifications

setup:: setup-python-env

setup-python-env: setup-python setup-pip setup-pipenv check-venv-filesystem

help-setup::
	@echo "  setup-python-env # Set up the Python environment including pip and pipenv"

# USER-VARIABLE: SYSTEM_PYTHON
# System interpreter used to bootstrap the environment. Only a plain python3 is
# assumed; no specific minor version is required.
SYSTEM_PYTHON ?= python3
  $(call log.debug, SYSTEM_PYTHON)

PYTHON ?= $(if $(wildcard .venv/bin/python),.venv/bin/python,$(SYSTEM_PYTHON))
  $(call log.info, PYTHON)

# Export PYTHON so it's available in recursive make calls and subshells
export PYTHON


# TARGET: setup-python
#: Check that the system python3 is available
setup-python:
	@if ! command -v $(SYSTEM_PYTHON) > /dev/null; then \
		echo "ERROR: $(SYSTEM_PYTHON) not found; install Python 3 or set SYSTEM_PYTHON." >&2 ; \
		exit 1 ; \
	fi
	@$(SYSTEM_PYTHON) --version

.PHONY: setup-python


# TARGET: setup-pip
#: Check that pip works for $(PYTHON) (the project .venv if present)
# Nothing is installed into the system Python (externally managed on recent
# Debian/Ubuntu); create a venv with plain python3 instead.
setup-pip:
	@if ! $(PYTHON) -m pip --version > /dev/null 2>&1; then \
		echo "ERROR: pip is not available for $(PYTHON). Create the project venv:" >&2 ; \
		echo "  $(SYSTEM_PYTHON) -m venv .venv && .venv/bin/pip install -r requirements.txt" >&2 ; \
		exit 1 ; \
	fi
	@$(PYTHON) -m pip --version

.PHONY: setup-pip

help-setup::
	@echo "  setup-python     # Check that $(SYSTEM_PYTHON) is available"
	@echo "  setup-pip        # Check that pip works for $(PYTHON)"


# TARGET: setup-pipenv
#: Report whether pipenv is available (only needed for update-pip-requirements-file)
setup-pipenv:
	@if $(PYTHON) -m pipenv --version > /dev/null 2>&1; then \
		$(PYTHON) -m pipenv --version ; \
	else \
		echo "NOTE: pipenv is not available for $(PYTHON); it is only needed to regenerate requirements.txt" \
		     "($(PYTHON) -m pip install pipenv)." ; \
	fi

.PHONY: setup-pipenv

help-setup::
	@echo "  setup-pipenv     # Report pipenv availability (needed only to regenerate requirements.txt)"


# TARGET: check-venv-filesystem
#: Checks if virtual environment is on a network filesystem and warns about PyTorch issues
check-venv-filesystem:
ifeq ($(OS),Linux)
	@VENV_DIR="$(VENV_PATH)"; \
	if [ ! -d "$$VENV_DIR" ]; then \
		VENV_DIR="$$(dirname "$$VENV_DIR")"; \
	fi; \
	FS_TYPE=$$(df -T "$$VENV_DIR" 2>/dev/null | tail -1 | awk '{print $$2}'); \
	case "$$FS_TYPE" in \
		nfs|nfs4|cifs|smb|smbfs|fuse.sshfs) \
			echo ""; \
			echo "WARNING: Virtual environment path is on a network filesystem ($$FS_TYPE)"; \
			echo "         Path: $$VENV_DIR"; \
			echo ""; \
			echo "         PyTorch and other libraries with shared objects may fail with:"; \
			echo "         'OSError: failed to map segment from shared object'"; \
			echo ""; \
			echo "         RECOMMENDED SOLUTIONS:"; \
			echo "         1. Create venv on local disk:"; \
			echo "            $(SYSTEM_PYTHON) -m venv /tmp/.venv-impresso"; \
			echo "            /tmp/.venv-impresso/bin/pip install -r requirements.txt"; \
			echo "            gmake VENV_PATH=/tmp/.venv-impresso ..."; \
			echo ""; \
			echo "         2. Or add to .env or config.local.mk:"; \
			echo "            VENV_PATH = /tmp/.venv-impresso"; \
			echo ""; \
			echo "         3. Or use symlink:"; \
			echo "            mv $(VENV_PATH) /tmp/.venv-impresso"; \
			echo "            ln -s /tmp/.venv-impresso $(VENV_PATH)"; \
			echo ""; \
			;; \
	esac
endif

.PHONY: check-venv-filesystem

help-setup::
	@echo "  check-venv-filesystem # Check if venv is on network filesystem (Linux only)"


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

# TARGET: update-pip-requirements-file
#: Lock dependencies and regenerate requirements.txt using the project root Pipfile
#
# Overrides the cookbook/setup.mk version to use the project root Pipfile so the
# target works correctly regardless of the directory make is invoked from.
update-pip-requirements-file:
	PIPENV_PIPFILE="$(CURDIR)/Pipfile" pipenv lock
	PIPENV_PIPFILE="$(CURDIR)/Pipfile" pipenv requirements > "$(CURDIR)/requirements.txt"

.PHONY: update-pip-requirements-file

help-setup::
	@echo "  update-pip-requirements-file # Lock deps and regenerate requirements.txt"


# TARGET: clean-setup
#: Remove local Python setup/cache artifacts
clean-setup::
	# Removing Python bytecode caches...
	rm -rvf lib/__pycache__ || true

.PHONY: clean-setup

help-setup::
	@echo "  clean-setup     # Remove local Python setup/cache artifacts"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_python.mk)
