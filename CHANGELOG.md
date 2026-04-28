# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial public release features

### Fixed
- Parallel job tracking with GNU parallel
- TTY detection for clean log output
- Input directory validation
- Temporary file cleanup on interrupt

### Changed
- Enhanced error handling throughout

## [1.0.0] - 2026-04-28

### Added
- Initial release of resolve_convert.sh
- Recursive media file scanning
- DNxHR video conversion (LB, SQ, HQ, HQX, 444 profiles)
- PCM 24-bit 48 kHz audio conversion
- Folder structure mirroring
- Parallel processing support with GNU parallel
- Dry-run mode for preview
- Comprehensive help documentation
- Support for 40+ video and audio formats
- Error handling and skip-on-existing logic
- Color-coded console output

---

## Guidelines for Updates

When adding changes:
1. Add to [Unreleased] section
2. Use these categories: Added, Changed, Deprecated, Removed, Fixed, Security
3. Link versions: `[1.0.0]: https://github.com/ChrisTitusTech/resolve-linux/releases/tag/v1.0.0`
4. Update on each release by moving [Unreleased] to version number with date

### Example Entry

```markdown
## [1.1.0] - 2026-05-15

### Added
- Support for AAC audio passthrough with `-a` flag

### Fixed
- MKV subtitle stream interference with audio detection
- Permission issues on network-mounted directories

### Changed
- Improved ffprobe error messages for unsupported codecs
```
