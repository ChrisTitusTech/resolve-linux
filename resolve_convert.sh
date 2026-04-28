#!/usr/bin/env bash
# =============================================================================
#  resolve_convert.sh — Transcode media to DaVinci Resolve-friendly formats
#                        (Linux / free codec set)
#
#  Video  → DNxHR HQ  (.mov)   — intermediate codec; works great in Resolve
#  Audio  → PCM 24-bit 48 kHz  (.wav)  — universal, lossless, zero fuss
#
#  By default:
#    • Recurses ALL sub-directories (skipping resolve_ready/ automatically)
#    • Mirrors the source folder tree inside resolve_ready/
#    • Output lands in <PATH>/resolve_ready/
#
#  Usage:
#    chmod +x resolve_convert.sh
#    ./resolve_convert.sh [OPTIONS] [PATH]
#
#  Options:
#    -o DIR      Custom output directory  (default: <PATH>/resolve_ready)
#    -q QUALITY  DNxHR profile: lb | sq | hq | hqx | 444  (default: hq)
#    -j N        Parallel jobs (default: 1)
#    -n          Dry-run — print what would happen, convert nothing
#    -h          Show this help
#
#  Dependencies:  ffmpeg (with dnxhd encoder support)
#
#  Install on Arch:        sudo pacman -S ffmpeg
#  Install on Deb/Ubuntu:  sudo apt install ffmpeg
# =============================================================================

set -euo pipefail

# ── Defaults (OUTPUT_DIR resolved after arg parsing) ──────────────────────────
QUALITY="hq"
PARALLEL_JOBS=1
DRY_RUN=false
SEARCH_PATH="."
OUTPUT_DIR=""          # empty = auto: <SEARCH_PATH>/resolve_ready

# ── Colour helpers (only colorize if stdout is a terminal) ─────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERR]${RESET}   $*" >&2; }
header()  { echo -e "\n${BOLD}$*${RESET}"; }

# ── Help ──────────────────────────────────────────────────────────────────────
usage() {
cat <<EOF
${BOLD}resolve_convert.sh${RESET} — Batch transcode for DaVinci Resolve on Linux

  ${BOLD}USAGE${RESET}
    $0 [OPTIONS] [PATH]

  ${BOLD}BEHAVIOUR${RESET}
    Walks PATH (default: current directory) recursively, skipping the
    resolve_ready/ output folder, and converts every media file found.
    Sub-directory structure is mirrored inside the output folder so your
    project layout is preserved.

  ${BOLD}OPTIONS${RESET}
    -o DIR      Custom output directory  (default: <PATH>/resolve_ready)
    -q QUALITY  DNxHR profile:
                  lb   = DNxHR LB  ~  low bitrate, offline/proxy editing
                  sq   = DNxHR SQ  ~  standard quality
                  hq   = DNxHR HQ  ~  high quality             [DEFAULT]
                  hqx  = DNxHR HQX ~  high quality, 12-bit
                  444  = DNxHR 444 ~  full 4:4:4, maximum quality
    -j N        Parallel conversion jobs  (default: 1, requires GNU parallel)
    -n          Dry-run — show what would be converted, do nothing
    -h          Show this help

  ${BOLD}EXAMPLES${RESET}
    $0                          # Convert everything in current dir
    $0 /mnt/footage             # Convert a specific folder
    $0 -o /mnt/edit /mnt/raw   # Custom output location
    $0 -q hqx -j 2 /mnt/raw   # 12-bit quality, 2 parallel jobs
    $0 -n .                    # Dry-run to preview what will be converted

  ${BOLD}OUTPUT FORMATS${RESET}
    Video → DNxHR HQ .mov  (QuickTime wrapper, Avid DNxHR codec)
    Audio → PCM s24le .wav (48 kHz, 24-bit, stereo)

  ${BOLD}FOLDER STRUCTURE EXAMPLE${RESET}
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
EOF
exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while getopts ":o:q:j:nh" opt; do
  case $opt in
    o) OUTPUT_DIR="$OPTARG" ;;
    q) QUALITY="$OPTARG" ;;
    j) PARALLEL_JOBS="$OPTARG" ;;
    n) DRY_RUN=true ;;
    h) usage ;;
    :) error "Option -$OPTARG requires an argument."; exit 1 ;;
    \?) error "Unknown option: -$OPTARG"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[[ $# -gt 0 ]] && SEARCH_PATH="$1"

# Resolve SEARCH_PATH to absolute so all comparisons are consistent
SEARCH_PATH="$(realpath "$SEARCH_PATH")" || { error "Invalid path: $1"; exit 1; }

# Validate that SEARCH_PATH exists and is a directory
[[ -d "$SEARCH_PATH" ]] || { error "Not a directory: $SEARCH_PATH"; exit 1; }

# Set default output dir now that SEARCH_PATH is known
[[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="${SEARCH_PATH}/resolve_ready"
OUTPUT_DIR="$(realpath -m "$OUTPUT_DIR")"   # -m: ok if it doesn't exist yet

# ── Validate quality ──────────────────────────────────────────────────────────
case "$QUALITY" in
  lb|sq|hq|hqx|444) ;;
  *) error "Invalid quality: $QUALITY. Choose lb|sq|hq|hqx|444"; exit 1 ;;
esac

# ── Known video / audio extensions ───────────────────────────────────────────
VIDEO_EXTS="mp4|mkv|avi|mov|mxf|wmv|flv|webm|ts|m2ts|mts|mpg|mpeg|m4v|3gp|ogv|vob|rmvb|rm|asf|divx|dv|f4v|hevc|h264|h265"
AUDIO_EXTS="mp3|aac|flac|ogg|m4a|wma|aiff|aif|opus|wav|ape|alac|mka|ac3|dts|eac3|amr|au|ra"

# ── Check dependencies ────────────────────────────────────────────────────────
check_deps() {
  local missing=()
  local encoders
  for cmd in ffmpeg ffprobe; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required tools: ${missing[*]}"
    echo "  Arch:          sudo pacman -S ffmpeg"
    echo "  Debian/Ubuntu: sudo apt install ffmpeg"
    exit 1
  fi

  # Avoid false negatives with `set -o pipefail` and `grep -q` SIGPIPE.
  encoders="$(ffmpeg -hide_banner -encoders 2>/dev/null || true)"
  if ! grep -qiE '(^|[[:space:]])dnxhd([[:space:]]|$)' <<<"$encoders"; then
    error "ffmpeg build does not include the DNxHD/DNxHR encoder."
    echo "  Arch:          sudo pacman -S ffmpeg"
    echo "  Debian/Ubuntu: sudo apt install ffmpeg"
    exit 1
  fi
}

# ── Detect video or audio via stream inspection ───────────────────────────────
get_media_type() {
  local file="$1"
  local has_video has_audio
  has_video=$(ffprobe -v quiet -select_streams v:0 \
    -show_entries stream=codec_type -of csv=p=0 "$file" 2>/dev/null | head -1)
  has_audio=$(ffprobe -v quiet -select_streams a:0 \
    -show_entries stream=codec_type -of csv=p=0 "$file" 2>/dev/null | head -1)

  if [[ "$has_video" == "video" ]]; then
    echo "video"
  elif [[ "$has_audio" == "audio" ]]; then
    echo "audio"
  else
    echo "unknown"
  fi
}

# ── Map quality shorthand → ffmpeg DNxHR profile string ──────────────────────
get_dnxhr_profile() {
  case "$1" in
    lb)  echo "dnxhr_lb"  ;;
    sq)  echo "dnxhr_sq"  ;;
    hq)  echo "dnxhr_hq"  ;;
    hqx) echo "dnxhr_hqx" ;;
    444) echo "dnxhr_444" ;;
  esac
}

# ── Build mirrored output path ────────────────────────────────────────────────
# Mirrors sub-directory structure relative to SEARCH_PATH into OUTPUT_DIR.
# e.g.  SEARCH_PATH/day1/clip.mp4  →  OUTPUT_DIR/day1/clip.mov
make_output_path() {
  local input="$1"
  local ext="$2"
  local rel_path rel_dir base
  rel_path=$(realpath --relative-to="$SEARCH_PATH" "$input")
  rel_dir=$(dirname "$rel_path")
  base=$(basename "$input")
  base="${base%.*}"
  if [[ "$rel_dir" == "." ]]; then
    echo "${OUTPUT_DIR}/${base}.${ext}"
  else
    echo "${OUTPUT_DIR}/${rel_dir}/${base}.${ext}"
  fi
}

# ── Convert VIDEO ─────────────────────────────────────────────────────────────
convert_video() {
  local input="$1"
  local output profile pix_fmt
  output=$(make_output_path "$input" "mov")
  profile=$(get_dnxhr_profile "$QUALITY")

  if [[ -f "$output" ]]; then
    warn "Skipping (exists): ${output#"$SEARCH_PATH/"}"
    return 0
  fi

  mkdir -p "$(dirname "$output")"
  info "VIDEO  ${input#"$SEARCH_PATH/"}  →  ${output#"$SEARCH_PATH/"}  [${profile}]"

  if $DRY_RUN; then
    echo "       ffmpeg -i \"$input\" -c:v dnxhd -profile:v $profile -c:a pcm_s24le ..."
    return 0
  fi

  pix_fmt="yuv422p"
  [[ "$QUALITY" == "hqx" ]] && pix_fmt="yuv422p12le"
  [[ "$QUALITY" == "444" ]] && pix_fmt="yuv444p12le"

  if ffmpeg -hide_banner -loglevel error -stats \
      -i "$input" \
      -c:v dnxhd -profile:v "$profile" \
      -pix_fmt "$pix_fmt" \
      -c:a pcm_s24le -ar 48000 -ac 2 \
      -movflags write_colr \
      -y "$output" 2>&1; then
    success "Done: ${output#"$SEARCH_PATH/"}"
    return 0
  else
    error "Failed: $input"
    rm -f "$output"
    return 1
  fi
}

# ── Convert AUDIO ─────────────────────────────────────────────────────────────
convert_audio() {
  local input="$1"
  local output
  output=$(make_output_path "$input" "wav")

  if [[ -f "$output" ]]; then
    warn "Skipping (exists): ${output#"$SEARCH_PATH/"}"
    return 0
  fi

  mkdir -p "$(dirname "$output")"
  info "AUDIO  ${input#"$SEARCH_PATH/"}  →  ${output#"$SEARCH_PATH/"}"

  if $DRY_RUN; then
    echo "       ffmpeg -i \"$input\" -c:a pcm_s24le -ar 48000 -ac 2 ..."
    return 0
  fi

  if ffmpeg -hide_banner -loglevel error -stats \
      -i "$input" \
      -c:a pcm_s24le -ar 48000 -ac 2 \
      -y "$output" 2>&1; then
    success "Done: ${output#"$SEARCH_PATH/"}"
    return 0
  else
    error "Failed: $input"
    rm -f "$output"
    return 1
  fi
}

# ── Collect files, pruning the output directory ───────────────────────────────
collect_files() {
  # -path "$OUTPUT_DIR" -prune skips the entire output tree so we never
  # attempt to re-convert already-converted files or loop on ourselves.
  find "$SEARCH_PATH" \
    -path "$OUTPUT_DIR" -prune \
    -o -type f -print \
    | grep -iE "\.(${VIDEO_EXTS}|${AUDIO_EXTS})$" \
    | sort
}

# ── Export symbols needed by subshells / GNU parallel ─────────────────────────
export -f convert_video convert_audio get_media_type make_output_path \
          get_dnxhr_profile info success warn error
export OUTPUT_DIR QUALITY SEARCH_PATH DRY_RUN

# ── Process one file ──────────────────────────────────────────────────────────
process_file() {
  local file="$1"
  local mtype
  mtype=$(get_media_type "$file")
  case "$mtype" in
    video) convert_video "$file" ;;
    audio) convert_audio "$file" ;;
    *)     warn "Skipping (unrecognised media): $file" ;;
  esac
}
export -f process_file

# ── Cleanup temporary files on exit ───────────────────────────────────────────
cleanup() {
  local joblog_file="${1:-}"
  [[ -n "$joblog_file" && -f "$joblog_file" ]] && rm -f "$joblog_file"
  return "${2:-0}"
}
trap 'cleanup; exit 130' INT TERM

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  header "=== resolve_convert.sh ==="
  check_deps

  info "Source       : $SEARCH_PATH"
  info "Output       : $OUTPUT_DIR"
  info "DNxHR quality: $QUALITY  ($(get_dnxhr_profile "$QUALITY"))"
  info "Parallel jobs: $PARALLEL_JOBS"
  $DRY_RUN && warn "DRY-RUN MODE — nothing will be converted"
  echo

  mapfile -t FILES < <(collect_files)
  local total=${#FILES[@]}

  if [[ $total -eq 0 ]]; then
    warn "No media files found under: $SEARCH_PATH"
    exit 0
  fi

  info "Found $total file(s) to process"
  echo

  mkdir -p "$OUTPUT_DIR"

  local ok=0 fail=0 start_time=$SECONDS

  if [[ "$PARALLEL_JOBS" -gt 1 ]] && command -v parallel &>/dev/null; then
    local joblog
    joblog=$(mktemp) || { error "Failed to create temporary file"; exit 1; }
    if printf '%s\n' "${FILES[@]}" \
      | parallel -j "$PARALLEL_JOBS" --joblog "$joblog" process_file {}; then
      ok=$(awk '$7==0' "$joblog" 2>/dev/null | wc -l)
      fail=$(awk '$7!=0' "$joblog" 2>/dev/null | wc -l)
    else
      error "Parallel processing failed"
    fi
    cleanup "$joblog"
  else
    [[ "$PARALLEL_JOBS" -gt 1 ]] && \
      warn "GNU parallel not found — running sequentially"

    local i=0
    for file in "${FILES[@]}"; do
      (( ++i ))
      echo -e "${BOLD}[$i/$total]${RESET} ${file#"$SEARCH_PATH/"}"
      if process_file "$file"; then
        (( ok++ )) || true
      else
        (( fail++ )) || true
      fi
      echo
    done
  fi

  local elapsed=$(( SECONDS - start_time ))
  header "=== Summary ==="
  echo -e "  ${GREEN}Succeeded${RESET} : $ok"
  [[ $fail -gt 0 ]] && echo -e "  ${RED}Failed${RESET}    : $fail"
  echo    "  Elapsed   : ${elapsed}s"
  echo    "  Output    : $OUTPUT_DIR"
  echo
}

main
