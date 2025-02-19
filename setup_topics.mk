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
	# check the python environment
	$(MAKE) check-python-installation
	# Sync the newspaper media list to process (testing s3 connectivity as well)
	$(MAKE) newspaper-list-target

 PHONY_TARGETS += setup-topics

# TARGET: install-java
#: Installs java
ifeq ($(OS),Linux)
install-java:
	which java ||sudo apt-get install -y openjdk-17-jre-headless 

else ifeq ($(OS),Darwin)
install-java:
	which java || brew install openjdk@17 
	echo "JAVA_HOME=$$(brew --prefix openjdk)" > .env_java
	echo 'PATH=$$JAVA_HOME/bin:$$PATH' >> .env_java
endif

setup:: setup-topics

check-python-installation:
	#
	# TEST PYTHON INSTALLATION FOR mallet topic inference ...
	python3 lib/test_jpype_installation.py || \
	{ echo "Double check whether the required python packages are installed! or you running in the correct python environment!" ; exit 1; }
	# OK: PYTHON ENVIRONMENT IS FINE!

PHONY_TARGETS +=  check-python-installation

help::
	@echo "  check-python-installation    # Check whether the environment is setup correctly"


$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_topics.mk)
