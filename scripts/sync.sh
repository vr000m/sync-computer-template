#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_BASE="$ROOT/dotfiles"
USB_STAGE="$ROOT/usb"

# Secret patterns to strip from collected text files.
# 1) Environment variable assignments (KEY=value)
SECRET_ENV_RE='(OPENAI_API_KEY|ANTHROPIC_API_KEY|GEMINI_API_KEY|CLAUDE_API_KEY|HF_TOKEN|HUGGING_FACE_HUB_TOKEN|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN|AWS_ACCESS_KEY_ID|AZURE_CLIENT_SECRET|AZURE_TENANT_ID|GOOGLE_APPLICATION_CREDENTIALS|GOOGLE_API_KEY|CLOUDFLARE_API_TOKEN|SENDGRID_API_KEY|TWILIO_AUTH_TOKEN|STRIPE_SECRET_KEY|DATABASE_URL|REDIS_URL|MONGODB_URI|API_KEY|SECRET_KEY|AUTH_TOKEN|ACCESS_TOKEN|REFRESH_TOKEN|PASSWORD|PASSWD|PRIVATE_KEY)='
# 2) Literal token prefixes
SECRET_TOKEN_RE='(sk-ant-[a-zA-Z0-9_-]{20,}|sk-proj-[a-zA-Z0-9_-]{20,}|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|ghs_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9_]{20,}|glpat-[a-zA-Z0-9_-]{20,}|xoxb-[0-9]{10,}|xoxp-[0-9]{10,}|AKIA[0-9A-Z]{16}|hf_[a-zA-Z0-9]{20,})'
# 3) Private key / certificate markers
SECRET_BLOCK_RE='-----BEGIN .*(PRIVATE KEY|CERTIFICATE)-----'

# Files that are safe to track in git.
# Common sources shared across platforms (currently empty, reserved for future use).
# shellcheck disable=SC2034
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
  "$HOME/.claude/hooks/context-alert.sh"
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
  "$HOME/.claude/hooks/context-alert.sh"
)

# Secrets to stage for USB backup (not tracked in git).
SECRET_DIRS=(
  "$HOME/.ssh"
  "$HOME/.gnupg"
  # Add your own secret directories here, e.g.:
  # "$HOME/.config/some-app-with-tokens"
)

# Category definitions for selective apply/collect
# Files in each category
declare -a CAT_SHELL=(
  "$HOME/.zshrc"
  "$HOME/.zprofile"
  "$HOME/.profile"
  "$HOME/.aliases"
  "$HOME/.bashrc"
  "$HOME/.bash_aliases"
  "$HOME/.inputrc"
)

declare -a CAT_GIT=(
  "$HOME/.gitconfig"
  "$HOME/.config/git/ignore"
)

declare -a CAT_SECURITY=(
  "$HOME/.ssh/config"
  "$HOME/.gnupg/gpg.conf"
  "$HOME/.gnupg/gpg-agent.conf"
)

declare -a CAT_CLAUDE_FILES=(
  "$HOME/.claude/CLAUDE.md"
  "$HOME/.claude/settings.json"
  "$HOME/.claude/settings.local.json"
  "$HOME/.claude/hooks/context-alert.sh"
)

declare -a CAT_CODEX=(
  "$HOME/.codex/config.toml"
  "$HOME/.codex/rules/default.rules"
)

declare -a CAT_GEMINI=(
  "$HOME/.gemini/settings.json"
)

declare -a CAT_TOOLS=(
  "$HOME/.config/starship.toml"
  "$HOME/.config/zed/settings.json"
  "$HOME/.config/gh/config.yml"
  "$HOME/.config/trail/config.toml"
)

VALID_CATEGORIES="shell git security claude codex gemini tools"

usage() {
  cat <<'EOF'
Usage: scripts/sync.sh <command> [category]

Commands:
  collect [category]  Copy dotfiles from $HOME into dotfiles/ (sanitizes common API keys).
  apply [category]    Copy dotfiles/ back into $HOME (backs up existing files).
  stage-usb           Copy SSH/GPG secrets into usb/ staging (ignored by git).
  push-usb            Sync usb/ staging to /Volumes/Samsung_T5/sync_computer (or auto-detect).
  pull-usb            Restore SSH/GPG from /Volumes/Samsung_T5/sync_computer into $HOME (backs up existing).

Categories (optional, omit for all):
  shell      .zshrc, .zprofile, .profile, .aliases, .bashrc
  git        .gitconfig, .config/git/ignore
  security   .ssh/config, .gnupg/gpg.conf, .gnupg/gpg-agent.conf
  claude     .claude/CLAUDE.md, .claude/settings.json, .claude/settings.local.json, .claude/hooks/
  codex      .codex/config.toml, .codex/rules/default.rules
  gemini     .gemini/settings.json
  tools      starship.toml, zed/settings.json, gh/config.yml, trail/config.toml

Examples:
  scripts/sync.sh apply           # Apply everything
  scripts/sync.sh collect claude  # Collect only claude configs

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
  echo "${src#"$HOME"/}"
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

  # Binary files: copy as-is.
  if file --mime-encoding "$src" 2>/dev/null | grep -q binary; then
    rsync -a "$src" "$dest"
    return
  fi

  # Text files: strip lines matching secret patterns.
  local before after
  before="$(wc -l < "$src")"

  { grep -vE -- "$SECRET_ENV_RE" "$src" || true; } \
    | { grep -vE -- "$SECRET_TOKEN_RE" || true; } \
    | { grep -vE -- "$SECRET_BLOCK_RE" || true; } \
    > "$dest"

  after="$(wc -l < "$dest")"
  local stripped=$((before - after))
  if [[ $stripped -gt 0 ]]; then
    echo "  WARNING: Sanitized $stripped line(s) from $(basename "$src")" >&2
  fi
}

# Get files for a specific category
get_category_files() {
  local category="$1"
  case "$category" in
    shell)    printf '%s\n' "${CAT_SHELL[@]}" ;;
    git)      printf '%s\n' "${CAT_GIT[@]}" ;;
    security) printf '%s\n' "${CAT_SECURITY[@]}" ;;
    claude)   printf '%s\n' "${CAT_CLAUDE_FILES[@]}" ;;
    codex)    printf '%s\n' "${CAT_CODEX[@]}" ;;
    gemini)   printf '%s\n' "${CAT_GEMINI[@]}" ;;
    tools)    printf '%s\n' "${CAT_TOOLS[@]}" ;;
    *)        echo "Unknown category: $category" >&2; return 1 ;;
  esac
}

# Check if a file is in a category
file_in_category() {
  local file="$1" category="$2"
  local cat_file
  while IFS= read -r cat_file; do
    [[ "$file" == "$cat_file" ]] && return 0
  done < <(get_category_files "$category" 2>/dev/null)
  return 1
}

collect_dotfiles() {
  ensure_rsync
  local platform category="${1:-}"
  platform="$(detect_platform)"

  # Validate category if provided
  if [[ -n "$category" ]] && ! echo "$VALID_CATEGORIES" | grep -qw "$category"; then
    echo "Unknown category: $category" >&2
    echo "Valid categories: $VALID_CATEGORIES" >&2
    return 1
  fi

  local -a files_to_collect=()

  # Get platform-specific source lists
  case "$platform" in
    darwin)
      files_to_collect=("${DOTFILES_SOURCES_DARWIN[@]}")
      ;;
    linux)
      files_to_collect=("${DOTFILES_SOURCES_LINUX[@]}")
      ;;
  esac

  # Filter by category if specified
  if [[ -n "$category" ]]; then
    local -a filtered_files=()

    for f in "${files_to_collect[@]:-}"; do
      [[ -z "$f" ]] && continue
      if file_in_category "$f" "$category"; then
        filtered_files+=("$f")
      fi
    done

    files_to_collect=()
    [[ ${#filtered_files[@]} -gt 0 ]] && files_to_collect=("${filtered_files[@]}")
  fi

  # Collect files
  if [[ ${#files_to_collect[@]} -gt 0 ]]; then
    collect_list "$platform" "${files_to_collect[@]}"
  fi
}

apply_dotfiles() {
  ensure_rsync
  local platform category="${1:-}"
  platform="$(detect_platform)"

  # Validate category if provided
  if [[ -n "$category" ]] && ! echo "$VALID_CATEGORIES" | grep -qw "$category"; then
    echo "Unknown category: $category" >&2
    echo "Valid categories: $VALID_CATEGORIES" >&2
    return 1
  fi

  local -a files_to_apply=()

  # Get platform-specific source lists
  case "$platform" in
    darwin)
      files_to_apply=("${DOTFILES_SOURCES_DARWIN[@]}")
      ;;
    linux)
      files_to_apply=("${DOTFILES_SOURCES_LINUX[@]}")
      ;;
  esac

  # Filter by category if specified
  if [[ -n "$category" ]]; then
    local -a filtered_files=()

    for f in "${files_to_apply[@]:-}"; do
      [[ -z "$f" ]] && continue
      if file_in_category "$f" "$category"; then
        filtered_files+=("$f")
      fi
    done

    files_to_apply=()
    [[ ${#filtered_files[@]} -gt 0 ]] && files_to_apply=("${filtered_files[@]}")
  fi

  # Apply files
  if [[ ${#files_to_apply[@]} -gt 0 ]]; then
    apply_list "$platform" "${files_to_apply[@]}"
  fi
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
      local backup
      backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
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
category="${2:-}"
case "$cmd" in
  collect) collect_dotfiles "$category" ;;
  apply) apply_dotfiles "$category" ;;
  stage-usb) stage_usb ;;
  push-usb) push_usb ;;
  pull-usb) pull_usb ;;
  ""|help|-h|--help) usage ;;
  *) echo "Unknown command: $cmd" >&2; usage; exit 1 ;;
esac
