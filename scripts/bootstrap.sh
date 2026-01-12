# scripts/bootstrap.sh
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_FILE="$ROOT/Brewfile"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '%s\n' "$1 is required but not found. Please install it and re-run." >&2
    exit 1
  fi
}

require_cmd curl

# 1) Install Homebrew if missing
if ! command -v brew >/dev/null 2>&1; then
  printf '%s\n' "Homebrew not found. Installing Homebrew (brew.sh)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Initialize brew environment for current shell
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  # Persist PATH only if not already present
  if [[ -x "$(command -v brew)" ]]; then
    BREW_PREFIX="$(brew --prefix)"
    SHELLENV_EVAL="$(brew shellenv)"
    for rc in "$HOME/.zprofile" "$HOME/.zshrc"; do
      if [[ -f "$rc" ]] && grep -Fq "$SHELLENV_EVAL" "$rc"; then
        :
      else
        printf '%s\n' "$SHELLENV_EVAL" >> "$rc"
      fi
    done
    printf '%s\n' "Added Homebrew shellenv to ~/.zprofile and ~/.zshrc (if missing)."
  fi

  if ! command -v brew >/dev/null 2>&1; then
    printf '%s\n' "Homebrew installation appears incomplete. Ensure Xcode Command Line Tools are installed (xcode-select --install) and try again." >&2
    exit 1
  fi
else
  printf '%s\n' "Homebrew is already installed."
fi

# 2) Verify Brewfile exists
if [[ ! -f "$BUNDLE_FILE" ]]; then
  printf 'Brewfile not found at %s\n' "$BUNDLE_FILE" >&2
  exit 1
fi

# 3) Install packages from Brewfile
printf 'Installing Homebrew bundle from %s...\n' "$BUNDLE_FILE"
brew bundle --file "$BUNDLE_FILE"
printf '%s\n' "Base packages installed."
printf '%s\n' "If you use nvm, ensure ~/.nvm exists (brew prints the setup instructions)."

# 4) Install Oh My Zsh if missing
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  printf '%s\n' "Oh My Zsh already installed at ~/.oh-my-zsh. Skipping."
else
  printf '%s\n' "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  printf '%s\n' "Oh My Zsh installation complete."
fi

# 5) Install Claude Code via official installer script (post-brew)
printf '%s\n' "Installing Claude Code via install.sh..."
if ! curl -fsSL https://claude.ai/install.sh | bash; then
  printf '%s\n' "Claude Code install failed." >&2
  exit 1
fi
printf '%s\n' "Claude Code installation complete."

printf '%s\n' "Bootstrap complete."
