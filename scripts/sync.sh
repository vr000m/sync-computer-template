#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_BASE="$ROOT/dotfiles"
USB_STAGE="$ROOT/usb"

# Files that are safe to track in git.
declare -a DOTFILES_SOURCES_COMMON=(
)

declare -a DOTFILES_SOURCES_DARWIN=(
  "$HOME/.zshrc"
  "$HOME/.zprofile"
  "$HOME/.profile"
  "$HOME/.aliases"
  "$HOME/.gitconfig"
  "$HOME/.ssh/config"
  "$HOME/.config/starship.toml"
  "$HOME/.gnupg/gpg.conf"
  "$HOME/.gnupg/gpg-agent.conf"
  "$HOME/.config/zed/settings.json"
  "$HOME/.config/git/ignore"
  "$HOME/.config/gh/config.yml"
  "$HOME/.config/trail/config.toml"
  # AI coding assistants
  "$HOME/.claude/CLAUDE.md"
  "$HOME/.claude/settings.json"
  "$HOME/.claude/settings.local.json"
  "$HOME/.claude.json"
  "$HOME/.codex/config.toml"
  "$HOME/.codex/rules/default.rules"
  "$HOME/.gemini/settings.json"
)

declare -a DOTFILES_SOURCES_LINUX=(
  "$HOME/.bashrc"
  "$HOME/.bash_aliases"
  "$HOME/.profile"
  "$HOME/.gitconfig"
  "$HOME/.ssh/config"
  "$HOME/.inputrc"
  "$HOME/.config/git/ignore"
  "$HOME/.config/starship.toml"
  # AI coding assistants
  "$HOME/.claude/CLAUDE.md"
  "$HOME/.claude/settings.json"
  "$HOME/.claude/settings.local.json"
  "$HOME/.claude.json"
)

# Secrets to stage for USB backup (not tracked in git).
SECRET_DIRS=(
  "$HOME/.ssh"
  "$HOME/.gnupg"
  # Add your own secret directories here, e.g.:
  # "$HOME/.config/some-app-with-tokens"
)

usage() {
  cat <<'EOF'
Usage: scripts/sync.sh <command>

Commands:
  collect      Copy dotfiles from $HOME into dotfiles/ (sanitizes common API keys).
  apply        Copy dotfiles/ back into $HOME (backs up existing files).
  stage-usb    Copy SSH/GPG secrets into usb/ staging (ignored by git).
  push-usb     Sync usb/ staging to /Volumes/Samsung_T5/sync_computer (or auto-detect).
  pull-usb     Restore SSH/GPG from /Volumes/Samsung_T5/sync_computer into $HOME (backs up existing).

Options:
  USB_TARGET=/path/to/dir  Override the USB target for push-usb.
  SYNC_PLATFORM=darwin|linux|common  Override platform detection for collect/apply.
  USB_PLATFORM=darwin|linux  Override platform detection for stage-usb/push-usb/pull-usb.
EOF
}

ensure_rsync() {
  command -v rsync >/dev/null 2>&1 || {
    echo "rsync is required; install via Homebrew: brew install rsync" >&2
    exit 1
  }
}

rel_path() {
  local src="$1"
  echo "${src#$HOME/}"
}

detect_platform() {
  if [[ -n "${SYNC_PLATFORM:-}" ]]; then
    echo "$SYNC_PLATFORM"
    return 0
  fi

  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    *) echo "common" ;;
  esac
}

detect_usb_platform() {
  if [[ -n "${USB_PLATFORM:-}" ]]; then
    echo "$USB_PLATFORM"
    return 0
  fi

  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    *) echo "common" ;;
  esac
}

bucket_dir() {
  local bucket="$1"
  echo "$DOTFILES_BASE/$bucket"
}

usb_bucket_dir() {
  local platform
  platform="$(detect_usb_platform)"
  echo "$USB_STAGE/$platform"
}

copy_sanitized() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  case "$src" in
    "$HOME/.zshrc" | "$HOME/.zprofile" | "$HOME/.bashrc" | "$HOME/.bash_profile")
      # Strip obvious API keys/secrets from shell init files.
      grep -vE '(OPENAI_API_KEY|ANTHROPIC_API_KEY|GEMINI_API_KEY|CLAUDE_API_KEY|API_KEY|SECRET_KEY|AUTH_TOKEN|ACCESS_TOKEN)=' "$src" > "$dest"
      ;;
    *)
      rsync -a "$src" "$dest"
      ;;
  esac
}

collect_dotfiles() {
  ensure_rsync
  local platform
  platform="$(detect_platform)"

  if [[ ${DOTFILES_SOURCES_COMMON+set} == set ]]; then
    collect_list "common" "${DOTFILES_SOURCES_COMMON[@]}"
  fi
  case "$platform" in
    darwin)
      if [[ ${DOTFILES_SOURCES_DARWIN+set} == set ]]; then
        collect_list "darwin" "${DOTFILES_SOURCES_DARWIN[@]}"
      fi
      ;;
    linux)
      if [[ ${DOTFILES_SOURCES_LINUX+set} == set ]]; then
        collect_list "linux" "${DOTFILES_SOURCES_LINUX[@]}"
      fi
      ;;
    common) : ;;
    *) : ;;
  esac
}

apply_dotfiles() {
  ensure_rsync
  local platform
  platform="$(detect_platform)"

  if [[ ${DOTFILES_SOURCES_COMMON+set} == set ]]; then
    apply_list "common" "${DOTFILES_SOURCES_COMMON[@]}"
  fi
  case "$platform" in
    darwin)
      if [[ ${DOTFILES_SOURCES_DARWIN+set} == set ]]; then
        apply_list "darwin" "${DOTFILES_SOURCES_DARWIN[@]}"
      fi
      ;;
    linux)
      if [[ ${DOTFILES_SOURCES_LINUX+set} == set ]]; then
        apply_list "linux" "${DOTFILES_SOURCES_LINUX[@]}"
      fi
      ;;
    common) : ;;
    *) : ;;
  esac
}

collect_list() {
  local bucket="$1"
  shift
  local -a sources=("$@")
  local dir
  dir="$(bucket_dir "$bucket")"

  if [[ ${#sources[@]} -eq 0 ]]; then
    return 0
  fi

  for src in "${sources[@]}"; do
    if [[ ! -f "$src" ]]; then
      echo "Skipping missing file: $src" >&2
      continue
    fi
    local rel
    rel="$(rel_path "$src")"
    local dest="$dir/$rel"
    copy_sanitized "$src" "$dest"
    echo "Collected $bucket/$rel"
  done
}

apply_list() {
  local bucket="$1"
  shift
  local -a sources=("$@")
  local dir
  dir="$(bucket_dir "$bucket")"

  if [[ ${#sources[@]} -eq 0 ]]; then
    return 0
  fi

  for src in "${sources[@]}"; do
    local rel dest backup
    rel="$(rel_path "$src")"
    dest="$dir/$rel"
    if [[ ! -f "$dest" ]]; then
      echo "No tracked copy for $bucket/$rel; skipping" >&2
      continue
    fi
    mkdir -p "$(dirname "$src")"
    if [[ -f "$src" ]] && cmp -s "$dest" "$src"; then
      echo "Unchanged $bucket/$rel; skipped"
      continue
    fi
    if [[ -f "$src" ]]; then
      backup="$src.bak.$(date +%Y%m%d%H%M%S)"
      cp "$src" "$backup"
      echo "Backed up $src -> $backup"
    fi
    rsync -a "$dest" "$src"
    echo "Applied $bucket/$rel"
  done
}

stage_usb() {
  ensure_rsync
  local bucket
  bucket="$(usb_bucket_dir)"
  mkdir -p "$bucket"
  for src in "${SECRET_DIRS[@]}"; do
    if [[ ! -d "$src" ]]; then
      echo "Skipping missing secret dir: $src" >&2
      continue
    fi
    local rel dest
    rel="$(rel_path "$src")"
    dest="$bucket/$rel"
    mkdir -p "$dest"
    rsync -a --delete \
      --exclude 'S.*' \
      --exclude '*.lock' \
      --exclude '*.sock' \
      "$src/" "$dest/"
    echo "Staged $rel into $(basename "$bucket")/ (usb/)"
  done
  echo "Staged secrets are in $bucket (ignored by git)."
}

detect_usb_target() {
  if [[ -n "${USB_TARGET:-}" ]]; then
    echo "$USB_TARGET"
    return 0
  fi
  local vol_base="/Volumes/Samsung_T5"
  local default="$vol_base/sync_computer"
  if [[ -d "$vol_base" ]]; then
    echo "$default"
    return 0
  fi
  for vol in /Volumes/*; do
    if [[ -d "$vol/sync_computer" ]]; then
      echo "$vol/sync_computer"
      return 0
    fi
  done
  return 1
}

push_usb() {
  ensure_rsync
  local bucket
  bucket="$(usb_bucket_dir)"
  if [[ ! -d "$bucket" ]]; then
    echo "Nothing to push; run stage-usb first." >&2
    exit 1
  fi
  local target
  if ! target="$(detect_usb_target)"; then
    echo "Could not find a sync_computer folder on a mounted volume; set USB_TARGET=/path/to/usb." >&2
    exit 1
  fi
  target="$target/$(basename "$bucket")"
  mkdir -p "$target"
  rsync -a --delete "$bucket"/ "$target"/
  echo "Pushed $bucket -> $target"
}

pull_usb() {
  ensure_rsync
  local source
  if ! source="$(detect_usb_target)"; then
    echo "Could not find a sync_computer folder on a mounted volume; set USB_TARGET=/path/to/usb." >&2
    exit 1
  fi
  local bucket
  bucket="$(basename "$(usb_bucket_dir)")"
  source="$source/$bucket"

  for dir in .ssh .gnupg; do
    if [[ ! -d "$source/$dir" ]]; then
      echo "No $dir on USB; skipping"
      continue
    fi
    local dest="$HOME/$dir"
    if [[ -d "$dest" ]]; then
      local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
      cp -a "$dest" "$backup"
      echo "Backed up $dest -> $backup"
    fi
    mkdir -p "$dest"
    rsync -a "$source/$dir"/ "$dest"/
    echo "Restored $dir from USB"
  done

  # Fix permissions for SSH and GPG.
  find "$HOME/.ssh" -type d -exec chmod 700 {} + 2>/dev/null || true
  find "$HOME/.ssh" -type f ! -name "*.pub" -exec chmod 600 {} + 2>/dev/null || true
  find "$HOME/.ssh" -type f -name "*.pub" -exec chmod 644 {} + 2>/dev/null || true
  find "$HOME/.gnupg" -type d -exec chmod 700 {} + 2>/dev/null || true
  find "$HOME/.gnupg" -type f -exec chmod 600 {} + 2>/dev/null || true

  gpgconf --kill gpg-agent >/dev/null 2>&1 || true
  echo "Done. Restarted gpg-agent; test with: echo \"test\" | gpg --clearsign"
}

cmd="${1:-}"
case "$cmd" in
  collect) collect_dotfiles ;;
  apply) apply_dotfiles ;;
  stage-usb) stage_usb ;;
  push-usb) push_usb ;;
  pull-usb) pull_usb ;;
  ""|help|-h|--help) usage ;;
  *) echo "Unknown command: $cmd" >&2; usage; exit 1 ;;
esac
