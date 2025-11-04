# Changelog

All notable changes to the Impresso Make Cookbook project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-11-04

### Added

#### Processing Pipelines
- Complete language identification pipeline with multi-system support
- OCR quality assessment pipeline with Bloom filters
- Mallet-based topic modeling pipeline with reproducibility controls
- News agencies data processing pipeline
- Bounding box quality assessment pipeline

#### Python Library
- Comprehensive Python library package (installable via pip)
- `common.py`: Core utilities for newspaper processing (674 lines)
- `list_newspapers.py`: Newspaper discovery and listing (680 lines)
- `local_to_s3.py`: Path conversion utilities (605 lines)
- `s3_aggregator.py`: S3 data aggregation (400 lines)
- `s3_comparer.py`: S3 file comparison tools (527 lines)
- `s3_compiler.py`: S3 data compilation (693 lines)
- `s3_sampler.py`: S3 data sampling utilities (1,175 lines)
- `s3_set_timestamp.py`: Timestamp management (608 lines)
- `s3_to_local_stamps.py`: Stamp file synchronization (729 lines)

#### Build System Features
- `make_settings.mk`: Core Make settings and shell configuration
- `log.mk`: Comprehensive logging with DEBUG/INFO/WARNING/ERROR levels (115 lines)
- `comment_template.mk`: Standardized documentation templates (97 lines)
- Template files for paths, processing, setup, and sync configurations
- Setup automation for Python, AWS, linguistic processing, OCR QA, and topics

#### Data Aggregation
- Language identification statistics aggregator
- Bounding box QA statistics aggregator
- Linguistic processing aggregator with jq utilities (227 lines)
- Page-level and language statistics extraction with jq

#### Documentation
- Expanded README.md with 557 new lines
- Build system structure documentation
- Processing workflow overview
- Setup guide with dependencies
- Makefile targets reference
- Usage examples and configuration guide
- GNU Make terminology explanation
- FAQ section
- `dotenv.sample`: Environment variable configuration template

### Changed
- Unified provider organization flags to integer-based values for consistency
- Updated S3 bucket variable assignments for improved flexibility
- Enhanced `install_apt.sh` for Ubuntu/Debian package installation
- Enhanced `install_brew.sh` for macOS Homebrew installation
- Improved Makefile structure with better documentation

### Fixed
- Removed redundant default assignment in language identification options to ensure user-supplied settings are respected

### Technical Details
- 70 files changed
- 11,243 lines added
- 50 new files created
- 18 files modified

## [1.0.0] - 2025-02-03

### Added
- Initial release of Impresso Make Cookbook
- Basic linguistic preprocessing pipeline
- Makefile-based build system
- S3 integration for data storage
- Local stamp files for progress tracking
- Basic setup and synchronization targets

---

## Version Numbering

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

## Release Types

- **Stable releases**: Fully tested and ready for production use
- **Pre-releases**: Feature-complete but may require additional testing

[1.1.0]: https://github.com/impresso/impresso-make-cookbook/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/impresso/impresso-make-cookbook/releases/tag/v1.0.0
