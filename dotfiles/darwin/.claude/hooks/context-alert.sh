#!/bin/bash
# Context threshold alert — fires after each Claude response via Stop hook.
# Sends a macOS notification when context usage crosses warning thresholds.
# Also prints a message to stderr so it appears in the terminal.

INPUT=$(cat)
CONTEXT_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CURRENT_DIR=$(echo "$INPUT" | jq -r '.workspace.current_dir // "unknown"')
REPO_NAME=$(basename "$CURRENT_DIR")

if [ "$CONTEXT_PCT" -ge 30 ]; then
  MSG="[$REPO_NAME] Context at ${CONTEXT_PCT}%. Time to compact or start a new session."
  osascript -e "display notification \"$MSG\" with title \"Claude Code\" sound name \"Ping\""
  echo "$MSG" >&2
elif [ "$CONTEXT_PCT" -ge 20 ]; then
  MSG="[$REPO_NAME] Context at ${CONTEXT_PCT}%. Approaching threshold."
  osascript -e "display notification \"$MSG\" with title \"Claude Code\""
  echo "$MSG" >&2
fi

exit 0
