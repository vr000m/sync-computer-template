#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APTFILE="$ROOT/Aptfile"

echo "=== Raspberry Pi Bootstrap ==="
echo ""

# Update apt
echo "Updating package lists..."
sudo apt update

# Install packages from Aptfile
if [[ -f "$APTFILE" ]]; then
    echo ""
    echo "Installing packages from Aptfile..."
    echo "(This may take a while on a fresh system)"
    echo ""

    # Filter out comments and empty lines, then install
    # Handle empty Aptfile without masking actual apt failures
    PACKAGES=$(grep -v '^#' "$APTFILE" | grep -v '^$' || true)
    if [[ -n "$PACKAGES" ]]; then
        echo "$PACKAGES" | xargs sudo apt install -y
    else
        echo "Aptfile is empty or contains only comments; skipping apt install."
    fi
else
    echo "No Aptfile found at $APTFILE"
    echo "Skipping package installation."
fi

# Install Starship prompt (not in apt)
echo ""
echo "Installing Starship prompt..."
mkdir -p ~/.local/bin
curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin

# Install uv (fast Python package manager)
echo ""
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Tailscale (not in standard apt repos)
echo ""
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "Next steps:"
echo "  1. Run: sudo tailscale up"
echo "  2. Run: scripts/sync.sh apply"
echo "  3. Open a new terminal or run: source ~/.bashrc"
echo ""
