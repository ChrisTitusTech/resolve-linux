# Development Guide

This guide will help you set up a development environment and contribute to resolve-linux.

## Prerequisites

### Required
- **bash** 4.0 or newer
- **ffmpeg** with DNxHD/DNxHR encoder support
- **git**

### Optional (but recommended)
- **GNU parallel** (for testing parallel features)
- **ShellCheck** (for linting)
- **ffprobe** (included with ffmpeg)

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/ChrisTitusTech/resolve-linux.git
cd resolve-linux
```

### 2. Install Dependencies

**Arch Linux:**
```bash
sudo pacman -S bash ffmpeg shellcheck
```

**Debian/Ubuntu:**
```bash
sudo apt install bash ffmpeg shellcheck
```

**With parallel support:**
```bash
# Arch
sudo pacman -S parallel

# Debian/Ubuntu
sudo apt install parallel
```

### 3. Verify Setup

```bash
# Check bash version
bash --version

# Verify ffmpeg has DNxHR support
ffmpeg -encoders | grep dnxhr

# Test the script
./resolve_convert.sh -h
```

## Project Structure

```
resolve-linux/
├── resolve_convert.sh          # Main script
├── README.md                   # User documentation
├── DEVELOPMENT.md             # This file
├── CHANGELOG.md               # Release notes
├── LICENSE                    # MIT License
├── .gitignore                 # Git ignore patterns
├── .editorconfig              # Editor configuration
└── .github/
   ├── CONTRIBUTING.md        # Contribution guidelines
   ├── CODE_OF_CONDUCT.md     # Community standards
   ├── SECURITY.md            # Security policy
    ├── ISSUE_TEMPLATE/        # Issue templates
    │   ├── bug_report.md
    │   └── feature_request.md
    ├── pull_request_template.md
    └── workflows/
        └── linter.yml         # CI/CD linting
```

## Making Changes

### 1. Create a Branch

```bash
# Bug fix
git checkout -b fix/descriptive-name

# Feature
git checkout -b feature/descriptive-name

# Documentation
git checkout -b docs/descriptive-name
```

### 2. Make Your Changes

Edit `resolve_convert.sh` or relevant documentation files.

### 3. Test Your Changes

#### Basic Testing
```bash
# Dry-run to verify logic
./resolve_convert.sh -n /path/to/test/files

# Test with specific quality
./resolve_convert.sh -n -q hqx /path/to/test/files

# Actual conversion of one file
mkdir -p /tmp/resolve_test_out
./resolve_convert.sh -o /tmp/resolve_test_out /path/to/one/file.mp4
```

#### Comprehensive Testing
```bash
#!/bin/bash
# test_resolve.sh - Comprehensive test script

set -e

TEST_DIR="/tmp/resolve_test_input"
OUT_DIR="/tmp/resolve_test_output"

# Prepare test directory
mkdir -p "$TEST_DIR"
rm -rf "$OUT_DIR"

# Copy sample media files (or create minimal test files)
# For quick testing, you can use small media clips

echo "=== Testing dry-run ==="
./resolve_convert.sh -n "$TEST_DIR"

echo "=== Testing all quality levels ==="
for quality in lb sq hq hqx 444; do
    echo "Quality: $quality"
    ./resolve_convert.sh -n -q "$quality" "$TEST_DIR"
done

echo "=== Testing with custom output ==="
./resolve_convert.sh -o "$OUT_DIR" -n "$TEST_DIR"

echo "=== Testing actual conversion ==="
./resolve_convert.sh -o "$OUT_DIR" "$TEST_DIR"

echo "=== All tests passed! ==="
```

### 4. Lint Your Code

If ShellCheck is installed:
```bash
shellcheck resolve_convert.sh
```

Address any warnings or errors it reports.

### 5. Commit Your Changes

```bash
git add resolve_convert.sh README.md  # Add files you changed
git commit -m "Fix: descriptive message about what changed

- Detailed explanation of the fix
- References issue #123 if applicable
- Mentions testing performed"
```

**Commit message guidelines:**
- Start with type: `Fix:`, `Feature:`, `Docs:`, `Refactor:`
- First line: max 50 characters, imperative mood
- Blank line, then detailed explanation
- Reference issues: `Fixes #123` or `Related to #456`

### 6. Push and Create a Pull Request

```bash
git push origin fix/descriptive-name
```

Then go to GitHub and create a PR with:
- Clear title
- Description of changes
- Reference to related issues
- Test results

## Testing Edge Cases

### Test File Scenarios

1. **Different container formats:**
   - MP4, MKV, MOV, AVI, WebM, FLV

2. **Different video codecs:**
   - H.264, H.265/HEVC, ProRes, DNxHD, VP9

3. **Different audio:**
   - Mono, stereo, 5.1 surround
   - Various sample rates: 44.1kHz, 48kHz, 96kHz

4. **Edge cases:**
   - Files with no audio stream
   - Files with multiple audio tracks
   - Very short clips (< 1 second)
   - Very long files (> 1 hour)
   - Corrupted or partially damaged files
   - Files with subtitles

### Performance Testing

```bash
# Create a large directory with many files
mkdir -p /tmp/large_test/{a,b,c,d,e}
for i in {1..20}; do
    cp sample.mp4 /tmp/large_test/a/file_$i.mp4
    cp sample.mkv /tmp/large_test/b/file_$i.mkv
done

# Test sequential
time ./resolve_convert.sh /tmp/large_test

# Test parallel (if available)
time ./resolve_convert.sh -j 4 /tmp/large_test
```

## Common Development Tasks

### Debugging a Conversion Failure

1. **Check input file:**
   ```bash
   ffprobe input_file
   ```

2. **Manual ffmpeg conversion:**
   ```bash
   ffmpeg -i input.mp4 -c:v dnxhd -profile:v dnxhr_hq \
     -pix_fmt yuv422p -c:a pcm_s24le -ar 48000 -ac 2 output.mov
   ```

3. **Enable verbose mode in script:**
   Add `set -x` after `set -euo pipefail` to see every command

### Adding a New Feature

1. Plan the feature (open an issue first)
2. Add command-line option handling (around line 100)
3. Implement the feature logic
4. Update help text and comments
5. Test thoroughly
6. Update README.md and CHANGELOG.md

### Updating Documentation

- **README.md** — User-facing documentation
- **DEVELOPMENT.md** — Developer documentation
- **.github/CONTRIBUTING.md** — Contribution process
- **CHANGELOG.md** — Release notes

## Useful Commands

```bash
# Show script statistics
wc -l resolve_convert.sh

# Find potential issues
grep -n "TODO\|FIXME\|HACK" resolve_convert.sh

# Test bash syntax without running
bash -n resolve_convert.sh

# Format shell script (requires shfmt)
shfmt -i 2 -w resolve_convert.sh
```

## Getting Help

- **Questions:** Open a GitHub Discussion
- **Bug report:** Check .github/CONTRIBUTING.md
- **Feature request:** Check .github/CONTRIBUTING.md

## Code Review Standards

When reviewing code or PRs:
1. Does it work as intended?
2. Are there any edge cases missed?
3. Is error handling adequate?
4. Is the code readable and documented?
5. Does it follow the existing code style?
6. Are there any performance concerns?

---

Happy coding! 🚀
