# Impresso Make-Based Offline (NLP) Processing Cookbook

Welcome to the Impresso Make-Based Offline (NLP) Processing Cookbook! This repository provides a comprehensive guide and set of tools for processing newspaper content. The build system leverages Makefiles to orchestrate complex workflows, ensuring efficient and scalable data processing. By utilizing S3 for data storage and local stamp files for tracking progress, this system supports distributed processing across multiple machines without conflicts.

## Table of Contents

- [Build System Structure](#build-system-structure)
- [Uploading to impresso S3 bucket](#uploading-to-impresso-s3-bucket)
- [Processing Workflow Overview](#processing-workflow-overview)
  - [Key Features](#key-features)
    - [Data Storage on S3](#data-storage-on-s3)
    - [Local Stamp Files](#local-stamp-files)
    - [Makefile and Build Dependencies](#makefile-and-build-dependencies)
    - [Running Local Commands](#running-local-commands)
    - [Uploading Results to S3](#uploading-results-to-s3)
    - [Handling Large Datasets on Small Machines](#handling-large-datasets-on-small-machines)
    - [Parallelization](#parallelization)
    - [Multi-Machine Build Isolation](#multi-machine-build-isolation)
- [Setup Guide](#setup-guide)
  - [Dependencies](#dependencies)
  - [Installation](#installation)
- [Makefile Targets](#makefile-targets)
- [Usage Examples](#usage-examples)
- [Contributing](#contributing)
- [License](#license)

## Build System Structure

The build system is organized into several make include files:

- `config.local.mk`: Local configuration overrides (not in the repository)

## Uploading to impresso S3 bucket

Ensure that the environment variables `SE_ACCESS_KEY` and `SE_SECRET_KEY` for access to the S3 impresso infrastructure are set, e.g., by setting them in a local `.env` file.

The build process uploads the processed data to the impresso S3 bucket.

## Processing Workflow Overview

This overview explains the impresso linguistic preprocessing pipeline, focusing on efficient data processing, distributed scalability, and minimizing interference between machines.

### Key Features

#### Data Storage on S3

All input and output data reside on S3, allowing multiple machines to access shared data without conflicts. Processing directly from S3 reduces the need for local storage.

#### Local Stamp Files

Local **stamp files** mirror S3 metadata, enabling machines to independently track and manage processing tasks without downloading full datasets. This prevents interference between machines, as builds are verified against S3 before processing starts, ensuring no overwrites or duplicate results.

#### Makefile and Build Dependencies

The Makefile orchestrates the pipeline by defining independent targets and dependencies based on stamp files. Each machine maintains its local state, ensuring stateless and conflict-free builds.

#### Running Local Commands

Processing scripts operate independently, handling data in a randomized order. Inputs are read from S3, outputs are uploaded back to S3, and no synchronization is required between machines. Additional machines can join or leave without disrupting ongoing tasks.

#### Uploading Results to S3

Processed files are validated locally and uploaded to S3 with integrity checks (e.g., JSON schema validation and md5sum). Results are never overwritten, ensuring consistency even with concurrent processing.

#### Handling Large Datasets on Small Machines

By leveraging S3 and stamp files, machines with limited storage (e.g., 100GB) can process large datasets efficiently without downloading entire files.

#### Parallelization

- **Local Parallelization**: Each machine uses Make's parallel build feature to maximize CPU utilization.
- **Distributed Parallelization**: Machines process separate subsets of data independently (e.g., by newspaper or date range) and write results to S3 without coordination.

#### Multi-Machine Build Isolation

- **Stateless Processing**: Scripts rely only on S3 and local configurations, avoiding shared state.
- **Custom Configurations**: Each machine uses local configuration files or environment variables to tailor processing behavior.

## Setup Guide

### Dependencies

- Python 3.11
- AWS CLI
- Git
- Make, `remake`
- Additional tools: `git-lfs`, `coreutils`, `parallel`

### 📌 Terminology and Cookbook Documentation

| Case                                          | Recipe? | Our Comment Terminology      | **GNU Make Terminology**                                 |
| --------------------------------------------- | ------- | ---------------------------- | -------------------------------------------------------- |
| User-configurable variable (`?=`)             | ❌      | **USER-VARIABLE**            | **"Recursive Variable (User-Overridable)"**              |
| Internal computed variable (`:=`)             | ❌      | **VARIABLE**                 | **"Simply Expanded Variable"**                           |
| Transformation function (`define … endef`)    | ❌      | **FUNCTION**                 | **"Multiline Variable (Make Function)"**                 |
| Target without a recipe (`.PHONY`)            | ❌      | **TARGET**                   | **"Phony Target (Dependency-Only Target)"**              |
| Target with a recipe that creates a file      | ✅      | **FILE-RULE**                | **"File Target (Explicit Rule)"**                        |
| Target that creates a timestamp file          | ✅      | **STAMPED-FILE-RULE**        | **"File Target (Explicit Rule with Timestamp Purpose)"** |
| **Double-colon target with no recipe** (`::`) | ❌      | **DOUBLE-COLON-TARGET**      | **"Double-Colon Target (Dependency-Only Target)"**       |
| **Double-colon target with a recipe** (`::`)  | ✅      | **DOUBLE-COLON-TARGET-RULE** | **"Double-Colon Target (Explicit Rule)"**                |

---

### 🚀 Explanation of GNU Make Terms

- **Recursive Variable (User-Overridable)** → Defined using `?=`, allowing users to override it.
- **Simply Expanded Variable** → Defined using `:=`, evaluated only once.
- **Multiline Variable (Make Function)** → A `define … endef` construct that acts as a function or script snippet.
- **Phony Target (Dependency-Only Target)** → A `.PHONY` target that does not create an actual file.
- **File Target (Explicit Rule)** → A normal rule that produces a file.
- **File Target (Explicit Rule with Timestamp Purpose)** → A special case of an explicit rule where the file primarily serves as a timestamp.
- **Double-Colon Target (Dependency-Only Target)** → A dependency-only target using `::`, allowing multiple independent rules.
- **Double-Colon Target (Explicit Rule)** → A `::` target that executes independently from others of the same name.

## About Impresso

### Impresso project

[Impresso - Media Monitoring of the Past](https://impresso-project.ch) is an interdisciplinary research project that aims to develop and consolidate tools for processing and exploring large collections of media archives across modalities, time, languages and national borders. The first project (2017-2021) was funded by the Swiss National Science Foundation under grant No. [CRSII5_173719](http://p3.snf.ch/project-173719) and the second project (2023-2027) by the SNSF under grant No. [CRSII5_213585](https://data.snf.ch/grants/grant/213585) and the Luxembourg National Research Fund under grant No. 17498891.

### Copyright

Copyright (C) 2024 The Impresso team.

### License

This program is provided as open source under the [GNU Affero General Public License](https://github.com/impresso/impresso-pyindexation/blob/master/LICENSE) v3 or later.

---

<p align="center">
  <img src="https://github.com/impresso/impresso.github.io/blob/master/assets/images/3x1--Yellow-Impresso-Black-on-White--transparent.png?raw=true" width="350" alt="Impresso Project Logo"/>
</p>
