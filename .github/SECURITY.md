# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in resolve-linux, please do **not** open a public GitHub issue.

Instead, please report it responsibly by:

1. **Email** — Send details to the repository maintainer with "SECURITY:" in the subject line
2. **Include details:**
   - Description of the vulnerability
   - Steps to reproduce (if applicable)
   - Potential impact
   - Suggested fix (if available)

3. **Allow time for patching** — We will:
   - Acknowledge receipt within 48 hours
   - Work on a fix privately
   - Prepare a security advisory
   - Release a patch version
   - Credit the reporter (if desired)

## Supported Versions

| Version | Status | Support |
|---------|--------|---------|
| 1.x | Current | Receives security updates |
| < 1.0 | Legacy | Best effort |

## Security Considerations

### What resolve-linux does:
- Executes FFmpeg on local files
- Creates output directories
- Writes temporary files to `/tmp` (cleaned on exit)
- Does not connect to the internet

### What resolve-linux does NOT do:
- Execute untrusted code
- Modify system files
- Require elevated privileges
- Handle network streams or remote files

## Best Practices

When using resolve-linux:

1. **Validate input** — Only process media from trusted sources
2. **Check disk space** — Ensure sufficient free space before conversion
3. **Monitor processes** — DNxHR conversion uses significant CPU/disk I/O
4. **Update ffmpeg** — Keep your FFmpeg installation current for codec security patches
5. **Protect output** — Restrict access to output directories if containing sensitive content

## Dependencies

This script depends on:
- **ffmpeg** — regularly updated with security patches
- **bash** — ensure your system bash is current
- **Standard POSIX utilities** — find, awk, sed, etc.

Keep these dependencies updated for security.

---

Thank you for helping keep resolve-linux secure!
