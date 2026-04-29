# resolve-linux

Batch transcode media to **DaVinci Resolve–friendly formats** on Linux using freely available codecs.

This repository also includes a backup utility for moving DaVinci Resolve setup
to a new Linux machine, including installation files and custom settings.

## Overview

`resolve_convert.sh` recursively scans directories, converts all media files to formats optimized for DaVinci Resolve, and preserves your folder structure in the output directory.

- **Video** → DNxHR (.mov) — Professional intermediate codec, works seamlessly in Resolve
- **Audio** → PCM 24-bit 48 kHz (.wav) — Lossless, universal, zero compatibility issues

## Features

✅ **Recursive directory scanning** — automatically processes all subdirectories  
✅ **Folder structure mirroring** — output preserves your project layout  
✅ **Configurable quality levels** — LB, SQ, HQ, HQX, 444  
✅ **Parallel processing** — speed up conversions with GNU parallel  
✅ **Dry-run mode** — preview conversions before committing  
✅ **Error handling** — skip existing files, report failures  
✅ **Linux-native** — no proprietary software required  

## Resolve Backup Script

Use `resolve_backup.sh` to create a single archive that can be restored on a new
PC. It captures:

- `/opt/resolve` (application install)
- `/usr/share/fonts`, `/usr/local/share/fonts`, `/etc/fonts` (system fonts/fontconfig)
- `~/.local/share/DaVinciResolve` (LUTs, Fusion templates, scripts, macros)
- `~/.config/Blackmagic Design/DaVinci Resolve` (preferences, hotkeys)
- `~/.local/share/BlackmagicDesign/DaVinci Resolve` (additional user data)
- `~/.local/share/fonts`, `~/.fonts`, `~/.config/fontconfig` (user fonts/fontconfig)

### Backup Exclusions

The backup intentionally excludes the following inside `/opt/resolve`:

- `/opt/resolve/plugins`
- `/opt/resolve/LUT`

### Backup Usage

```bash
chmod +x resolve_backup.sh
./resolve_backup.sh --output-dir ~/backups
```

Dry-run preview:

```bash
./resolve_backup.sh --dry-run
```

Run built-in end-to-end self-test:

```bash
./resolve_backup.sh --self-test
```

Skip system font paths (useful for smaller backup/testing):

```bash
./resolve_backup.sh --no-system-fonts
```

The script is verbose by default and validates archive integrity after creation.

### Restore Usage

Restore directly from an archive file:

```bash
./resolve_backup.sh --restore inputfile.tar.gz
```

Restore to custom target paths (useful for testing/migration staging):

```bash
./resolve_backup.sh \
  --restore inputfile.tar.gz \
  --restore-home /home/targetuser \
  --restore-opt /opt \
  --restore-root /
```

Restore options summary:

- `-r, --restore FILE` restore from backup archive
- `--restore-home DIR` restore `payload/home/<user>/...` into `DIR`
- `--restore-opt DIR` restore `payload/opt/...` into `DIR`
- `--restore-root DIR` restore `payload/system/...` into `DIR`

## Requirements

- **ffmpeg** (with DNxHD/DNxHR encoder support)
- **bash** 4.0+
- Optional: **GNU parallel** (for multi-threaded conversions)

### Installation

**Arch Linux:**
```bash
sudo pacman -S ffmpeg
```

**Debian/Ubuntu:**
```bash
sudo apt install ffmpeg
```

Optional parallel processing:
```bash
sudo apt install parallel          # Debian/Ubuntu
sudo pacman -S parallel            # Arch
```

## Usage

```bash
chmod +x resolve_convert.sh
./resolve_convert.sh [OPTIONS] [PATH]
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-o DIR` | Custom output directory | `<PATH>/resolve_ready` |
| `-q QUALITY` | DNxHR profile: `lb`, `sq`, `hq`, `hqx`, `444` | `hq` |
| `-j N` | Parallel jobs (requires GNU parallel) | `1` |
| `-n` | Dry-run — preview without converting | — |
| `-h` | Show help | — |

### Examples

Convert everything in current directory:
```bash
./resolve_convert.sh
```

Convert a specific folder:
```bash
./resolve_convert.sh /mnt/footage
```

Custom output location:
```bash
./resolve_convert.sh -o /mnt/edit /mnt/raw
```

High quality (12-bit) with 2 parallel jobs:
```bash
./resolve_convert.sh -q hqx -j 2 /mnt/raw
```

Preview conversions (dry-run):
```bash
./resolve_convert.sh -n /mnt/footage
```

## Output Formats

### Video Codec Options

| Profile | Name | Bitrate | Use Case |
|---------|------|---------|----------|
| `lb` | DNxHR LB | ~100 Mbps | Proxy/offline editing |
| `sq` | DNxHR SQ | ~220 Mbps | Standard quality |
| `hq` | DNxHR HQ | ~440 Mbps | High quality (default) |
| `hqx` | DNxHR HQX | ~660 Mbps | 12-bit, high quality |
| `444` | DNxHR 444 | ~880 Mbps | 4:4:4, maximum quality |

**Container:** QuickTime (.mov) — native support in Resolve

### Audio

**Codec:** PCM (signed 24-bit linear)  
**Sample Rate:** 48 kHz (Resolve standard)  
**Channels:** Stereo  
**Container:** WAV  

## Folder Structure Example

```
/mnt/footage/
  day1/clip_a.mp4
  day1/clip_b.mkv
  day2/interview.mov
  bgm.mp3
  ↓
/mnt/footage/resolve_ready/
  day1/clip_a.mov
  day1/clip_b.mov
  day2/interview.mov
  bgm.wav
```

## Supported Input Formats

**Video:** mp4, mkv, avi, mov, mxf, wmv, flv, webm, ts, m2ts, mts, mpg, mpeg, m4v, 3gp, ogv, vob, rmvb, rm, asf, divx, dv, f4v, hevc, h264, h265

**Audio:** mp3, aac, flac, ogg, m4a, wma, aiff, aif, opus, wav, ape, alac, mka, ac3, dts, eac3, amr, au, ra

## Workflow Tips

1. **Test first:** Use `-n` (dry-run) to preview before actual conversion
2. **Monitor space:** DNxHR HQ produces ~660 MB/minute; ensure sufficient disk space
3. **Proxy editing:** Use `-q lb` for faster initial edits, re-link to high-quality originals later
4. **Batch processing:** Combine with `-j` for parallel conversions on multi-core systems
5. **Network storage:** Conversions may be slower on network drives; consider local temporary storage

## Troubleshooting

**"ffmpeg build does not include the DNxHD/DNxHR encoder"**
- Your ffmpeg build lacks DNxHD support. Reinstall with: `sudo pacman -S ffmpeg` or `sudo apt install ffmpeg`

**"GNU parallel not found — running sequentially"**
- Install GNU parallel for multi-threaded conversions, or proceed single-threaded

**No files found**
- Verify the path exists and contains supported media files
- Check that files aren't in the output directory (automatically excluded)

**Conversion failed for a file**
- Check ffprobe can read the file: `ffprobe input.mp4`
- Verify ffmpeg supports the codec: `ffmpeg -decoders | grep codec_name`
- Consider re-encoding the source with a standard encoder

## Performance

On a modern multi-core system (e.g., 6-core CPU):
- **Sequential:** ~100 Mbps throughput
- **Parallel (6 jobs):** ~400–500 Mbps throughput

DNxHR HQ bitrate: ~660 Mbps = ~82 MB/s  
Expected time per minute of video: ~0.5–1 second (depending on system and quality)

## License

MIT License — see [LICENSE](LICENSE) for details

## Contributing

Contributions are welcome! Please see [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) for guidelines.

## Author

Created for DaVinci Resolve workflows on Linux.

---

**Ready to convert?**
```bash
./resolve_convert.sh /path/to/footage
```
