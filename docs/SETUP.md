# Setup Guide

This guide walks you through setting up sync-computer for your own use.

## Quick Start

### 1. Fork or Clone

```bash
# Option A: Fork on GitHub, then clone your fork
git clone git@github.com:YOUR_USERNAME/sync-computer-template.git ~/Code/sync-computer
cd ~/Code/sync-computer

# Option B: Clone and set up your own remote
git clone https://github.com/vr000m/sync-computer-template.git ~/Code/sync-computer
cd ~/Code/sync-computer
git remote remove origin
git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPO_NAME.git
```

### 2. Customize the .example Files

Copy the `.example` files and customize them:

```bash
# For macOS
cp dotfiles/darwin/.gitconfig.example dotfiles/darwin/.gitconfig
cp dotfiles/darwin/.zshrc.example dotfiles/darwin/.zshrc
cp dotfiles/darwin/.aliases.example dotfiles/darwin/.aliases
cp dotfiles/darwin/.ssh/config.example dotfiles/darwin/.ssh/config

# For Linux/RPi
cp dotfiles/linux/.gitconfig.example dotfiles/linux/.gitconfig
cp dotfiles/linux/.bashrc.example dotfiles/linux/.bashrc
cp dotfiles/linux/.ssh/config.example dotfiles/linux/.ssh/config
```

Then edit each file to add your:
- Name and email in `.gitconfig`
- SSH key paths in `.ssh/config`
- Custom aliases
- Any personal paths or settings

### 3. Update sync.sh Sources

Edit `scripts/sync.sh` to list the dotfiles you want to sync:

```bash
# For macOS (DOTFILES_SOURCES_DARWIN)
declare -a DOTFILES_SOURCES_DARWIN=(
  "$HOME/.zshrc"
  "$HOME/.aliases"
  "$HOME/.gitconfig"
  "$HOME/.ssh/config"
  "$HOME/.config/starship.toml"
)

# For Linux (DOTFILES_SOURCES_LINUX)
declare -a DOTFILES_SOURCES_LINUX=(
  "$HOME/.bashrc"
  "$HOME/.bash_aliases"
  "$HOME/.gitconfig"
  "$HOME/.ssh/config"
  "$HOME/.inputrc"
  "$HOME/.config/starship.toml"
)
```

### 4. Run Bootstrap

**On macOS:**
```bash
scripts/bootstrap.sh
scripts/sync.sh apply
```

**On Linux/Raspberry Pi:**
```bash
scripts/bootstrap_rpi.sh
scripts/sync.sh apply
```

---

## Detailed Configuration

### Git Configuration

Edit your `.gitconfig` to set:

```ini
[user]
    name = Your Name
    email = your-email@example.com
    signingkey = ~/.ssh/id_ed25519.pub  # or GPG key ID
```

### SSH Keys

1. Generate an SSH key if you don't have one:
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

2. Add it to your SSH agent:
   ```bash
   # macOS
   ssh-add --apple-use-keychain ~/.ssh/id_ed25519

   # Linux
   eval $(keychain --quiet --agents ssh id_ed25519)
   ```

3. Add the public key to GitHub: https://github.com/settings/keys

### Secrets Management

**Never commit secrets to git!** Use `.local` files instead:

- `~/.zshrc.local` (macOS) - for API keys, tokens
- `~/.bashrc.local` (Linux) - for API keys, tokens

These files are sourced by the shell but not tracked in git.

Example `~/.bashrc.local`:
```bash
export OPENAI_API_KEY="sk-..."
export GITHUB_TOKEN="ghp_..."
```

---

## USB Backup (Optional)

The sync script can backup SSH/GPG keys to a USB drive:

```bash
# Stage secrets to usb/ folder (not committed to git)
scripts/sync.sh stage-usb

# Push to USB drive
scripts/sync.sh push-usb

# On a new machine, pull from USB
scripts/sync.sh pull-usb
```

Set `USB_TARGET` if your drive isn't auto-detected:
```bash
USB_TARGET=/media/username/USB_DRIVE/sync_computer scripts/sync.sh push-usb
```

---

## Platform-Specific Notes

### macOS

- Uses `zsh` as default shell
- Homebrew packages in `Brewfile`
- Run `brew bundle --file Brewfile` to install packages

### Linux / Raspberry Pi

- Uses `bash` as default shell
- apt packages in `Aptfile`
- `bootstrap_rpi.sh` also installs:
  - Starship prompt
  - uv (Python package manager)
  - Tailscale (VPN)

---

## Workflow Summary

1. **On your main machine:** Make changes to dotfiles, then:
   ```bash
   scripts/sync.sh collect
   git add . && git commit -m "Update dotfiles"
   git push
   ```

2. **On other machines:** Pull and apply:
   ```bash
   git pull
   scripts/sync.sh apply
   ```

3. **For secrets:** Use USB backup or manually copy.
