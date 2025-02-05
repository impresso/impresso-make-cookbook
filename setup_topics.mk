$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_topics.mk)

# DOUBLE COLON TARGET specifications

setup:: setup-topics


# TARGET: setup-topics
#: Sets up the topic inference environment
setup-topics: | $(BUILD_DIR)
	# install the following OS level dependencies
	cat < lib/install_$(INSTALLER).sh
	# Install the OS level dependencies
	# lib/install_$(INSTALLER).sh
	# Create the local directories
	mkdir -p $(OUT_LOCAL_PATH_PROCESSED_DATA_TOPICS)
	mkdir -p $(IN_LOCAL_PATH_PROCESSED_DATA_LINGPROC)
	# check the python environment
	$(MAKE) check-python-installation
	# Sync the newspaper media list to process (testing s3 connectivity as well)
	$(MAKE) newspaper-list-target

 PHONY_TARGETS += setup-topics


setup:: setup-topics

check-python-installation:
	#
	# TEST PYTHON INSTALLATION FOR mallet topic inference ...
	python3 lib/test_jpype_installation.py || \
	{ echo "Double check whether the required python packages are installed! or you running in the correct python environment!" ; exit 1; }
	# OK: PYTHON ENVIRONMENT IS FINE!

PHONY_TARGETS +=  check-python-installation

help::
	@#
	#
	# HELP from cookbook/setup_topics.mk
	# make  check-python-installation # Prepare the local directories and check the python environment


$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_topics.mk)
