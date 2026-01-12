#!/usr/bin/env bash
# Move obvious secret exports out of shell init files into ~/.zshrc.local.
set -euo pipefail

SECRET_LOCAL="$HOME/.zshrc.local"
SRC_FILES=("$HOME/.zshrc" "$HOME/.zprofile")

# Matches exports like export OPENAI_API_KEY=... or export FOO_TOKEN=...
SECRET_REGEX='^[[:space:]]*export[[:space:]]+([A-Za-z0-9_]*(API_KEY|TOKEN|SECRET|PASSWORD|AUTH_TOKEN))='

dedupe_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  awk '!seen[$0]++' "$file" > "${file}.tmp.$$" && mv "${file}.tmp.$$" "$file"
}

move_secrets() {
  local src="$1"
  [[ -f "$src" ]] || { echo "Skipping missing file: $src"; return; }

  local backup="${src}.bak.$(date +%Y%m%d%H%M%S)"
  cp "$src" "$backup"

  local tmp
  tmp="$(mktemp)"
  local moved=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ $SECRET_REGEX ]]; then
      echo "$line" >> "$SECRET_LOCAL"
      moved=1
    else
      echo "$line" >> "$tmp"
    fi
  done < "$src"

  mv "$tmp" "$src"

  if [[ $moved -eq 1 ]]; then
    echo "Moved secrets from $src (backup: $backup)"
  else
    rm -f "$backup"
    echo "No secrets detected in $src"
  fi
}

for file in "${SRC_FILES[@]}"; do
  move_secrets "$file"
done

dedupe_file "$SECRET_LOCAL"
echo "Secrets consolidated into $SECRET_LOCAL"
