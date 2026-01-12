# sync-computer-template

A template for syncing dotfiles and terminal configuration across macOS and Linux/Raspberry Pi machines.

## Features

- **Cross-platform:** Works on macOS (zsh) and Linux/RPi (bash)
- **Platform-aware sync:** Automatically detects OS and syncs appropriate configs
- **Secret sanitization:** Auto-strips API keys when collecting dotfiles
- **USB backup:** Secure backup of SSH/GPG keys to USB drive
- **Modern CLI tools:** Includes Starship prompt, fzf, ripgrep, bat, fd

See [docs/SETUP.md](docs/SETUP.md) for detailed instructions.

### Collect dotfiles from original machine
```bash
scripts/sync.sh collect
```

### Bootstrap your new machine and copy the dotfiles from original machin

**macOS:**
```bash
scripts/bootstrap.sh
scripts/sync.sh apply
```

**Linux/Raspberry Pi:**
```bash
scripts/bootstrap_rpi.sh
scripts/sync.sh apply
```

## Layout

```
├── Brewfile                    # macOS packages (Homebrew)
├── Aptfile                     # Linux packages (apt)
├── dotfiles/
│   ├── darwin/                 # macOS configs
│   │   ├── .gitconfig.example
│   │   ├── .zshrc.example
│   │   └── .config/starship.toml
│   └── linux/                  # Linux/RPi configs
│       ├── .gitconfig.example
│       ├── .bashrc.example
│       ├── .bash_aliases
│       └── .config/starship.toml
├── scripts/
│   ├── sync.sh                 # Main sync script
│   ├── bootstrap.sh            # macOS bootstrap
│   └── bootstrap_rpi.sh        # RPi bootstrap
└── docs/
    ├── SETUP.md                # Detailed setup guide
    └── *.md                    # Other guides
```

## Usage

### Collect dotfiles from original machine
```bash
scripts/sync.sh collect
```

### Apply dotfiles to new machine
```bash
scripts/sync.sh apply
```

### Backup secrets to USB
```bash
scripts/sync.sh stage-usb
scripts/sync.sh push-usb
```

### Restore secrets from USB
```bash
scripts/sync.sh pull-usb
```

## What's Included

### macOS (via Brewfile)
- Starship prompt
- fzf, ripgrep, bat, fd
- nvm, gh, deno
- GPG + pinentry-mac

### Linux/RPi (via Aptfile + bootstrap)
- Starship prompt
- fzf, bat, fd-find, ripgrep
- tmux, htop
- uv (Python package manager)
- Tailscale (VPN)

## Documentation

- [SETUP.md](docs/SETUP.md) - Detailed setup guide
- [Terminal Performance](docs/terminal-performance-optimizations.md) - Speed up shell startup
- [Fast CLI Utilities](docs/fast-cli-utilities.md) - Modern CLI tool replacements

## License

MIT
