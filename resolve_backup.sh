#!/usr/bin/env bash
# =============================================================================
#  resolve_backup.sh — Back up DaVinci Resolve install and user customizations
#
#  Includes (when present):
#    - /opt/resolve
#    - ~/.local/share/DaVinciResolve
#    - ~/.config/Blackmagic Design/DaVinci Resolve
#    - ~/.local/share/BlackmagicDesign/DaVinci Resolve
#    - System and user fonts/fontconfig paths
#
#  Excludes from /opt/resolve backup:
#    - plugins
#    - LUT
#
#  Archive contains a payload tree that is easy to restore on another machine:
#    payload/opt/resolve
#    payload/home/<user>/...
#    MANIFEST.txt
#
#  Usage:
#    chmod +x resolve_backup.sh
#    ./resolve_backup.sh [OPTIONS]
#
#  Options:
#    -o, --output-dir DIR    Where the archive should be written (default: .)
#    -n, --dry-run           Show what would be backed up, do not create archive
#    -t, --test-archive      Verify archive readability after creation
#        --source-home DIR   Home directory to scan (default: $HOME)
#        --opt-path DIR      Resolve install path (default: /opt/resolve)
#        --archive-name NAME Override archive file name prefix
#        --self-test         Run built-in end-to-end test and exit
#        --no-color          Disable color output
#    -h, --help              Show help
# =============================================================================

set -euo pipefail

OUTPUT_DIR="."
DRY_RUN=false
TEST_ARCHIVE=true
SOURCE_HOME="${HOME}"
OPT_PATH="/opt/resolve"
ARCHIVE_NAME=""
SELF_TEST=false
INCLUDE_SYSTEM_FONTS=true
USE_COLOR=true

if [[ ! -t 1 ]]; then
  USE_COLOR=false
fi

if $USE_COLOR; then
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

usage() {
  cat <<EOF
${BOLD}resolve_backup.sh${RESET} — Back up DaVinci Resolve on Linux

${BOLD}USAGE${RESET}
  $0 [OPTIONS]

${BOLD}OPTIONS${RESET}
  -o, --output-dir DIR    Where the archive should be written (default: .)
  -n, --dry-run           Show what would be backed up, do not create archive
  -t, --test-archive      Verify archive readability after creation (default: on)
      --source-home DIR   Home directory to scan (default: $HOME)
      --opt-path DIR      Resolve install path (default: /opt/resolve)
      --archive-name NAME Override archive file name prefix
      --self-test         Run built-in end-to-end test and exit
        --no-system-fonts  Skip system font paths (/usr/share/fonts, etc.)
      --no-color          Disable color output
  -h, --help              Show help

${BOLD}EXAMPLES${RESET}
  $0
  $0 --output-dir ~/backups
  $0 --dry-run
  $0 --source-home /home/alex --opt-path /opt/resolve

${BOLD}RESTORE${RESET}
  mkdir -p /tmp/resolve-restore
  tar -xzf <archive>.tar.gz -C /tmp/resolve-restore
  sudo rsync -a /tmp/resolve-restore/payload/opt/ /opt/
  sudo rsync -a /tmp/resolve-restore/payload/system/ /
  rsync -a /tmp/resolve-restore/payload/home/<user>/ /home/<user>/

${BOLD}NOTE${RESET}
  /opt/resolve/plugins and /opt/resolve/LUT are intentionally excluded.
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output-dir)
      OUTPUT_DIR="${2:-}"
      [[ -n "$OUTPUT_DIR" ]] || { error "--output-dir requires a value"; exit 1; }
      shift 2
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -t|--test-archive)
      TEST_ARCHIVE=true
      shift
      ;;
    --source-home)
      SOURCE_HOME="${2:-}"
      [[ -n "$SOURCE_HOME" ]] || { error "--source-home requires a value"; exit 1; }
      shift 2
      ;;
    --opt-path)
      OPT_PATH="${2:-}"
      [[ -n "$OPT_PATH" ]] || { error "--opt-path requires a value"; exit 1; }
      shift 2
      ;;
    --archive-name)
      ARCHIVE_NAME="${2:-}"
      [[ -n "$ARCHIVE_NAME" ]] || { error "--archive-name requires a value"; exit 1; }
      shift 2
      ;;
    --self-test)
      SELF_TEST=true
      shift
      ;;
    --no-system-fonts)
      INCLUDE_SYSTEM_FONTS=false
      shift
      ;;
    --no-color)
      USE_COLOR=false
      RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      error "Unknown option: $1"
      usage
      ;;
  esac
done

canon_path() {
  local p="$1"
  if [[ -e "$p" ]]; then
    realpath "$p"
  else
    realpath -m "$p"
  fi
}

human_size() {
  local bytes="$1"
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "$bytes"
  else
    echo "${bytes}B"
  fi
}

ensure_dir() {
  local dir="$1"
  mkdir -p "$dir" || { error "Cannot create directory: $dir"; exit 1; }
}

build_candidate_paths() {
  local -n out_ref="$1"
  out_ref=()

  # Resolve install + Resolve-specific user data
  out_ref+=("$OPT_PATH")
  out_ref+=("$SOURCE_HOME/.local/share/DaVinciResolve")
  out_ref+=("$SOURCE_HOME/.config/Blackmagic Design/DaVinci Resolve")
  out_ref+=("$SOURCE_HOME/.local/share/BlackmagicDesign/DaVinci Resolve")

  # Fonts required by titles/plugins/transitions and typography-heavy templates
  if $INCLUDE_SYSTEM_FONTS; then
    out_ref+=("/usr/share/fonts")
    out_ref+=("/usr/local/share/fonts")
    out_ref+=("/etc/fonts")
  fi
  out_ref+=("$SOURCE_HOME/.local/share/fonts")
  out_ref+=("$SOURCE_HOME/.fonts")
  out_ref+=("$SOURCE_HOME/.config/fontconfig")
}

dedupe_existing_paths() {
  local -n in_ref="$1"
  local -n out_ref="$2"
  local seen="|"
  local p abs
  out_ref=()
  for p in "${in_ref[@]}"; do
    abs="$(canon_path "$p")"
    [[ -e "$abs" ]] || continue
    if [[ "$seen" != *"|$abs|"* ]]; then
      out_ref+=("$abs")
      seen+="$abs|"
    fi
  done
}

write_manifest() {
  local manifest="$1"
  shift
  local archive_basename="$1"
  shift

  {
    echo "DaVinci Resolve Linux Backup Manifest"
    echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Host: $(hostname 2>/dev/null || echo unknown)"
    echo "User: $(id -un 2>/dev/null || echo unknown)"
    echo "Source home: $SOURCE_HOME"
    echo "Resolve path: $OPT_PATH"
    echo "Archive: $archive_basename"
    echo
    echo "Included paths:"
    for p in "$@"; do
      echo "  - $p"
    done
    echo
    echo "Excluded paths:"
    echo "  - $OPT_PATH/plugins"
    echo "  - $OPT_PATH/LUT"
    echo
    echo "Restore notes:"
    echo "  1) Extract archive to a temporary directory"
    echo "  2) Copy payload/opt/resolve back to /opt/resolve (usually with sudo)"
    echo "  3) Copy payload/system/... back to / (usually with sudo)"
    echo "  4) Copy payload/home/<user>/... into the target user home"
    echo "  5) Verify permissions after restore"
  } > "$manifest"
}

copy_into_staging() {
  local src="$1"
  local stage_root="$2"
  local source_user
  source_user="$(basename "$SOURCE_HOME")"

  if [[ "$src" == "$OPT_PATH" ]]; then
    info "Copying install path: $src"
    warn "Excluding path: $src/plugins"
    warn "Excluding path: $src/LUT"
    mkdir -p "$stage_root/payload/opt"
    mkdir -p "$stage_root/payload/opt/resolve"
    tar -C "$src" --exclude='./plugins' --exclude='./LUT' -cpf - . \
      | tar -C "$stage_root/payload/opt/resolve" -xpf -
    return
  fi

  if [[ "$src" == "$SOURCE_HOME"* ]]; then
    local rel
    rel="${src#"$SOURCE_HOME"/}"
    [[ "$rel" == "$src" ]] && rel="."
    info "Copying user path: $src"
    mkdir -p "$stage_root/payload/home/$source_user"
    tar -C "$SOURCE_HOME" -cpf - "$rel" | tar -C "$stage_root/payload/home/$source_user" -xpf -
    return
  fi

  if [[ "$src" == /* ]]; then
    local rel_abs
    rel_abs="${src#/}"
    info "Copying system path: $src"
    mkdir -p "$stage_root/payload/system/$(dirname "$rel_abs")"
    cp -a "$src" "$stage_root/payload/system/$rel_abs"
    return
  fi

  warn "Skipping unsupported path root: $src"
}

create_archive() {
  local archive_path="$1"
  local -n include_ref="$2"

  local stage_dir
  stage_dir="$(mktemp -d)"
  trap 'rm -rf "${stage_dir:-}"' EXIT

  local manifest_path="$stage_dir/MANIFEST.txt"
  write_manifest "$manifest_path" "$(basename "$archive_path")" "${include_ref[@]}"

  local p
  for p in "${include_ref[@]}"; do
    copy_into_staging "$p" "$stage_dir"
  done

  cp "$manifest_path" "$stage_dir/payload/MANIFEST.txt"

  tar -C "$stage_dir" -czf "$archive_path" payload

  rm -rf "$stage_dir"
  trap - EXIT
}

verify_archive() {
  local archive_path="$1"
  header "Archive validation"
  if tar -tzf "$archive_path" >/dev/null 2>&1; then
    success "Archive is readable: $archive_path"
  else
    error "Archive validation failed"
    exit 1
  fi

  if tar -tzf "$archive_path" | grep -Fx 'payload/MANIFEST.txt' >/dev/null; then
    success "Manifest found inside archive"
  else
    error "Manifest missing from archive"
    exit 1
  fi
}

self_test() {
  header "Running self-test"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}"' EXIT

  local fake_home="$tmp/home/testuser"
  local fake_opt="$tmp/opt/resolve"
  local fake_out="$tmp/out"

  mkdir -p "$fake_home/.local/share/DaVinciResolve/Support/LUT"
  mkdir -p "$fake_home/.local/share/DaVinciResolve/Support/Fusion/Templates/Edit/Titles"
  mkdir -p "$fake_home/.config/Blackmagic Design/DaVinci Resolve/Preferences"
  mkdir -p "$fake_opt/Fusion/Plugins"
  mkdir -p "$fake_opt/plugins"
  mkdir -p "$fake_opt/LUT"
  mkdir -p "$fake_home/.local/share/fonts"
  mkdir -p "$fake_home/.config/fontconfig"

  echo "LUTDATA" > "$fake_home/.local/share/DaVinciResolve/Support/LUT/custom_lut.cube"
  echo "TEMPLATE" > "$fake_home/.local/share/DaVinciResolve/Support/Fusion/Templates/Edit/Titles/custom_title.setting"
  echo "HOTKEYS" > "$fake_home/.config/Blackmagic Design/DaVinci Resolve/Preferences/custom.keyboard"
  echo "PLUGIN" > "$fake_opt/Fusion/Plugins/custom.plugin"
  echo "SHOULD_SKIP" > "$fake_opt/plugins/skip.plugin"
  echo "SHOULD_SKIP" > "$fake_opt/LUT/skip.cube"
  echo "LOCALFONT" > "$fake_home/.local/share/fonts/userfont.otf"

  "$0" \
    --output-dir "$fake_out" \
    --source-home "$fake_home" \
    --opt-path "$fake_opt" \
    --archive-name "resolve-self-test" \
    --no-system-fonts \
    --no-color

  local archive
  archive="$(ls -1 "$fake_out"/resolve-self-test*.tar.gz | head -n 1)"
  [[ -f "$archive" ]] || { error "Self-test archive was not created"; exit 1; }

  tar -tzf "$archive" | grep -Fx 'payload/opt/resolve/Fusion/Plugins/custom.plugin' >/dev/null
  if tar -tzf "$archive" | grep -Fx 'payload/opt/resolve/plugins/skip.plugin' >/dev/null; then
    error "Self-test failed: excluded /opt/resolve/plugins content was backed up"
    exit 1
  fi
  if tar -tzf "$archive" | grep -Fx 'payload/opt/resolve/LUT/skip.cube' >/dev/null; then
    error "Self-test failed: excluded /opt/resolve/LUT content was backed up"
    exit 1
  fi
  tar -tzf "$archive" | grep -Fx 'payload/home/testuser/.local/share/DaVinciResolve/Support/LUT/custom_lut.cube' >/dev/null
  tar -tzf "$archive" | grep -Fx 'payload/home/testuser/.config/Blackmagic Design/DaVinci Resolve/Preferences/custom.keyboard' >/dev/null
  tar -tzf "$archive" | grep -Fx 'payload/home/testuser/.local/share/fonts/userfont.otf' >/dev/null

  success "Self-test passed"
  info "Test archive: $archive"

  rm -rf "$tmp"
  trap - EXIT
  exit 0
}

main() {
  if $SELF_TEST; then
    self_test
  fi

  SOURCE_HOME="$(canon_path "$SOURCE_HOME")"
  OPT_PATH="$(canon_path "$OPT_PATH")"
  OUTPUT_DIR="$(canon_path "$OUTPUT_DIR")"

  [[ -d "$SOURCE_HOME" ]] || { error "source home is not a directory: $SOURCE_HOME"; exit 1; }
  ensure_dir "$OUTPUT_DIR"

  local -a candidates includes
  build_candidate_paths candidates
  dedupe_existing_paths candidates includes

  header "=== resolve_backup.sh ==="
  info "Source home : $SOURCE_HOME"
  info "Resolve path: $OPT_PATH"
  info "Output dir  : $OUTPUT_DIR"
  info "Sys fonts   : $INCLUDE_SYSTEM_FONTS"

  if [[ ${#includes[@]} -eq 0 ]]; then
    error "No Resolve paths found to back up"
    exit 1
  fi

  info "Discovered ${#includes[@]} path(s):"
  local p
  for p in "${includes[@]}"; do
    info "  - $p"
  done

  if [[ -d "$OPT_PATH" && ! -r "$OPT_PATH" ]]; then
    error "Resolve install path exists but is not readable: $OPT_PATH"
    error "Run with a user that can read it, or use sudo."
    exit 1
  fi

  local stamp archive_basename archive_path
  stamp="$(date +"%Y%m%d_%H%M%S")"
  if [[ -n "$ARCHIVE_NAME" ]]; then
    archive_basename="${ARCHIVE_NAME}_${stamp}.tar.gz"
  else
    archive_basename="resolve_backup_${stamp}.tar.gz"
  fi
  archive_path="$OUTPUT_DIR/$archive_basename"

  if $DRY_RUN; then
    warn "DRY-RUN MODE enabled. No archive will be created."
    info "Would create: $archive_path"
    exit 0
  fi

  header "Creating archive"
  create_archive "$archive_path" includes
  success "Backup archive created"
  info "Archive path: $archive_path"

  local size_bytes size_human
  size_bytes="$(stat -c '%s' "$archive_path" 2>/dev/null || echo 0)"
  size_human="$(human_size "$size_bytes")"
  info "Archive size: $size_human"

  if $TEST_ARCHIVE; then
    verify_archive "$archive_path"
  fi

  header "Done"
  echo "Restore hint:"
  echo "  tar -xzf \"$archive_path\" -C /tmp/resolve-restore"
  echo "  sudo rsync -a /tmp/resolve-restore/payload/opt/ /opt/"
  echo "  sudo rsync -a /tmp/resolve-restore/payload/system/ /"
  echo "  rsync -a /tmp/resolve-restore/payload/home/<user>/ /home/<user>/"
}

main
