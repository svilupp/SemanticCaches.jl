# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Fixed

## [0.2.0]

### Fixed
- Remove statements that automatically allow DATADEPS downloading. Now simply catches the error and prints a message to the user. For users, remember to set `ENV["DATADEPS_ALWAYS_ACCEPT"] = true` before running the package.

## [0.1.0]

### Added
- Initial release