# Fast CLI Utilities

Modern replacements for traditional Unix commands, written in Rust/Go for better performance.

## Installed Utilities

### fd (replaces `find`)
**Why:** The standard `find` command has cryptic syntax and is slow on large directories. `fd` is 5-10x faster, has sensible defaults (ignores .git, respects .gitignore), and uses intuitive syntax.

```bash
# Traditional find
find . -name "*.js" -type f

# fd equivalent
fd -e js

# fd is simpler for most cases
fd pattern              # find files matching pattern
fd -e js -e ts          # find .js and .ts files
fd -H pattern           # include hidden files
fd -I pattern           # don't respect .gitignore
```

**Benchmark:** In a large codebase, `fd` typically completes in ~50ms vs `find` at ~500ms.

---

### bat (replaces `cat`)
**Why:** `cat` just dumps text. `bat` adds syntax highlighting, line numbers, git integration (shows modified lines), and automatic paging for long files.

```bash
bat file.py             # syntax highlighted output
bat -A file.txt         # show non-printable characters
bat --diff file.py      # show git diff for file
bat -l json data        # force JSON highlighting (for stdin)
```

**Note:** bat uses less as pager. Press `q` to quit, `/` to search.

---

### eza (replaces `ls`)
**Why:** `ls` output is plain and doesn't show git status. `eza` provides colorful output, git status indicators, tree view, and better formatting.

```bash
eza                     # simple ls
eza -la                 # long format with hidden files
eza -la --git           # show git status for each file
eza --tree              # tree view
eza --tree -L 2         # tree view, 2 levels deep
eza -la --icons         # with file type icons (needs nerd font)
```

---

### fzf (fuzzy finder)
**Why:** Game-changer for navigation. Fuzzy-find anything - files, command history, git branches, processes. The shell integration provides:
- `Ctrl+R` - fuzzy search command history (much better than default)
- `Ctrl+T` - fuzzy find files and insert path
- `Alt+C` - fuzzy find directories and cd into them

```bash
fzf                     # find files interactively
vim $(fzf)              # open selected file in vim
cat $(fzf)              # cat selected file
git checkout $(git branch | fzf)  # switch branch interactively

# Pipe anything to fzf
ps aux | fzf            # find process
env | fzf               # find env variable
```

**Pro tip:** Type multiple words to narrow search. `^` prefix matches start, `$` suffix matches end.

---

### jq (JSON processor)
**Why:** Essential for working with APIs and JSON data. Parses, filters, and transforms JSON from command line.

```bash
# Pretty print JSON
cat data.json | jq

# Extract field
jq '.name' file.json

# Extract nested field
jq '.user.email' file.json

# Get array element
jq '.[0]' file.json

# Filter array
jq '.[] | select(.status == "active")' file.json

# API example
curl -s https://api.github.com/users/octocat | jq '.login, .name'
```

---

### delta (replaces `diff`, git pager)
**Why:** Standard git diff is hard to read. Delta provides syntax highlighting, line numbers, side-by-side view, and word-level diff highlighting.

Configured automatically via `.gitconfig`. Just use git normally:
```bash
git diff                # now shows delta-formatted output
git show HEAD           # commit details with delta
git log -p              # patches with delta
```

**Navigation:** `n`/`N` to jump between files (when `navigate = true`).

---

### btop (replaces `top`/`htop`)
**Why:** Beautiful, feature-rich system monitor. Shows CPU, memory, disks, network, and processes with graphs and colors.

```bash
btop                    # launch system monitor
```

**Navigation:** Mouse support, or use arrow keys. `q` to quit.

---

## Utilities Considered But Not Installed

| Utility | Purpose | Why Skipped |
|---------|---------|-------------|
| `zoxide` | Smart cd (learns habits) | Adds complexity, standard cd works fine |
| `dust` | Disk usage visualization | `du -sh *` usually sufficient |
| `duf` | Disk free overview | `df -h` usually sufficient |
| `procs` | Better ps | `ps aux \| grep` works fine |
| `sd` | Simpler sed | sed is fine for occasional use |
| `tldr` | Simplified man pages | Can use web search |
| `hyperfine` | Benchmarking | Niche use case |
| `tokei` | Code statistics | Niche use case |

---

## Installation

All utilities are in the Brewfile:
```bash
cd ~/code/vr000m/sync-computer
brew bundle --file Brewfile
```

Or install individually:
```bash
brew install fd bat eza fzf jq git-delta btop
```

## Shell Integration

fzf requires shell integration for keybindings (already in .zshrc):
```zsh
source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"
source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
```

delta is configured via .gitconfig (already done).
