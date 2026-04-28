# Contributing to resolve-linux

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Be respectful and inclusive. We welcome contributions from developers of all experience levels.

## How to Contribute

### Reporting Bugs

Found a bug? Please report it by opening a GitHub issue with:

1. **Clear title** — briefly describe the problem
2. **Steps to reproduce** — how to trigger the bug
3. **Expected behavior** — what should happen
4. **Actual behavior** — what actually happened
5. **Environment** — OS, ffmpeg version, bash version
6. **Logs/output** — relevant error messages (use dry-run with `-n` if helpful)

Example:
```
Title: Video conversion fails with MKV files containing subtitles

Steps:
1. Run: ./resolve_convert.sh /path/to/mkv/files
2. Script processes video but skips audio

Expected: Both video and audio converted
Actual: Only video converted, audio stream ignored

Environment: Ubuntu 22.04, ffmpeg 4.4.2, GNU bash 5.1.16
```

### Suggesting Enhancements

Have an idea? Open an issue with:

1. **Clear title** — summarize the feature
2. **Description** — explain what and why
3. **Use case** — how would this help your workflow?
4. **Alternatives** — any existing workarounds?

Example:
```
Title: Add support for preserving original audio codec

Description:
Currently, all audio is converted to PCM WAV. Some users want to preserve
the original codec (AAC, FLAC, etc.) while still standardizing sample rate.

Use case:
Archival workflows where original codec fidelity matters.

Workaround:
Run ffmpeg manually on audio files before converting video.
```

### Submitting Changes

1. **Fork the repository** — create your own copy
2. **Create a branch** — use a descriptive name:
   ```bash
   git checkout -b fix/mkv-audio-handling
   git checkout -b feature/quality-presets
   ```
3. **Make changes** — edit `resolve_convert.sh` (or related files)
4. **Test thoroughly**:
   ```bash
   # Dry-run with various file formats
   ./resolve_convert.sh -n /path/to/test/media
   
   # Dry-run with different quality levels
   ./resolve_convert.sh -n -q lb /path/to/test/media
   ./resolve_convert.sh -n -q hqx /path/to/test/media
   
   # Actually convert a small test file
   ./resolve_convert.sh -o /tmp/resolve_test /path/to/one/file
   ```
5. **Commit with clear messages**:
   ```bash
   git commit -m "Fix: handle MKV audio streams correctly

   - Added separate audio stream detection for MKV format
   - Fixes issue #42 where MKV subtitles interfered with audio conversion
   - Tested with 20+ MKV files from various sources"
   ```
6. **Push and create a Pull Request**:
   ```bash
   git push origin fix/mkv-audio-handling
   ```

## Development Guidelines

### Bash Best Practices

- Use `set -euo pipefail` at the top of scripts
- Quote variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals, not `[ ]`
- Avoid `grep | awk` chains; prefer awk alone
- Comment complex logic
- Use meaningful variable names

### Code Style

- Indentation: 2 spaces (not tabs)
- Line length: Keep under 100 characters where reasonable
- Function names: lowercase with underscores (`convert_video`, not `convertVideo`)
- Comments: Use `#` for inline, `# ──` for section headers (matching existing style)

### Testing

Before submitting, test with:

1. **Various file types**: MP4, MKV, MOV, WebM, AVI
2. **Different audio**: mono, stereo, 5.1 surround
3. **Different framerates**: 24p, 25p, 30p, 60p
4. **Edge cases**: Very short clips, very long files, corrupted files
5. **All quality levels**: `lb`, `sq`, `hq`, `hqx`, `444`
6. **Parallel mode**: `-j 2`, `-j 4`
7. **Dry-run**: Verify output paths are correct

Example test script:
```bash
#!/bin/bash
set -e

TEST_DIR="/tmp/resolve_test_input"
mkdir -p "$TEST_DIR"

# Create test files (or copy real media)
cp /path/to/sample.mp4 "$TEST_DIR/"
cp /path/to/sample.mkv "$TEST_DIR/"

# Test dry-run
./resolve_convert.sh -n "$TEST_DIR"

# Test each quality level
for q in lb sq hq hqx 444; do
  echo "Testing quality: $q"
  ./resolve_convert.sh -q "$q" -n "$TEST_DIR"
done

echo "All tests passed!"
```

### Documentation

If adding features, update:

- **README.md** — add usage examples, new options, troubleshooting
- **In-script comments** — document complex sections
- **Help text** — update the `-h` usage output

## Pull Request Process

1. **Describe your changes** — clear summary of what was fixed/added
2. **Link related issues** — reference bug reports with `Fixes #42`
3. **Include test results** — mention which file types you tested
4. **Be responsive** — address feedback promptly

Example PR description:
```markdown
## Description
Fix issue where MKV files with subtitle streams caused audio conversion to fail.

## Changes
- Detect video/audio streams separately from subtitle streams
- Filter subtitle stream (-map 0:v:0 -map 0:a:0) to exclude subtitles
- Add debug logging for stream detection

## Testing
- ✅ Tested with 15 MKV files (various codecs)
- ✅ Tested with MP4, MOV, AVI (no regression)
- ✅ Parallel mode: `-j 4` works correctly
- ✅ Dry-run validates correct output paths

Fixes #42
```

## Questions?

- Open a GitHub Discussion
- Create an issue with `[QUESTION]` prefix
- Check existing issues and README for common questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for helping improve resolve-linux! 🎬
