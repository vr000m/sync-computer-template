# Terminal Performance Optimizations

Guide for optimizing macOS zsh terminal startup time from ~600-900ms to ~250ms.

## Baseline Measurement

Before optimizing, measure your shell startup time:
```bash
for i in 1 2 3; do /usr/bin/time zsh -i -c exit 2>&1; done
```

For detailed profiling, add to top/bottom of `.zshrc`:
```bash
# TOP of .zshrc
zmodload zsh/zprof

# BOTTOM of .zshrc
zprof
```

## Optimizations Applied (2026-01-04)

### 1. Cache Homebrew Prefix (~150-200ms saved)

**Problem:** Each `$(brew --prefix)` call takes ~50ms and was called 4+ times.

**Solution:** Cache in `.zprofile` (runs once per login):
```zsh
# .zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
```

Then use `$HOMEBREW_PREFIX` in `.zshrc`:
```zsh
# Instead of: source $(brew --prefix)/share/zsh-syntax-highlighting/...
source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
```

### 2. Optimize NVM Loading (~100-150ms saved)

**Problem:** `nvm.sh` is slow and blocks shell startup.

**Solution:** Use `--no-use` flag to defer node activation:
```zsh
export NVM_DIR="$HOME/.nvm"
[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" --no-use
[ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && source "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"
```

The `--no-use` flag loads nvm without activating a node version. The `load-nvmrc` hook will activate the correct version when entering project directories.

**Alternative (if you don't need auto .nvmrc):** Lazy-load nvm entirely:
```zsh
export NVM_DIR="$HOME/.nvm"
lazy_load_nvm() {
  unset -f nvm node npm npx
  [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
}
nvm() { lazy_load_nvm && nvm "$@"; }
node() { lazy_load_nvm && node "$@"; }
npm() { lazy_load_nvm && npm "$@"; }
npx() { lazy_load_nvm && npx "$@"; }
```

### 3. Disable Unused Oh-My-Zsh Theme (~20-30ms saved)

**Problem:** OMZ loads a theme that Starship immediately overrides.

**Solution:** Set empty theme:
```zsh
ZSH_THEME=""
```

### 4. Consolidate compinit Calls (~50-80ms saved)

**Problem:** `compinit` was called multiple times (deno, docker, etc.).

**Solution:** Single call with all fpath entries:
```zsh
fpath=("$HOME/.zsh/completions" "$HOME/.docker/completions" $fpath)
autoload -Uz compinit
compinit
```

### 5. Conditional GPG Agent Launch (~20-30ms saved)

**Problem:** `gpgconf --launch gpg-agent` runs on every shell.

**Solution:** Check if already running:
```zsh
export GPG_TTY=$(tty)
pgrep -x gpg-agent >/dev/null || gpgconf --launch gpg-agent
```

## Results

| Metric | Before | After |
|--------|--------|-------|
| Cold start | ~940ms | ~700ms |
| Warm start | ~560ms | ~250ms |

## Additional Optimizations (Not Applied)

### Replace oh-my-zsh with lighter alternatives
- **zinit** - lazy loading plugin manager
- **zsh4humans** - optimized zsh framework
- **sheldon** - fast plugin manager written in Rust

### Enable zsh compilation cache
```zsh
# Compile zshrc for faster loading
zcompile ~/.zshrc
```

### Use zsh-defer for lazy loading
```zsh
# Install: brew install romkatv/zsh-defer/zsh-defer
source /opt/homebrew/opt/zsh-defer/share/zsh-defer/zsh-defer.plugin.zsh
zsh-defer source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
```

## Troubleshooting

### Startup still slow?
1. Profile with `zprof` to find bottlenecks
2. Check for slow network calls (DNS lookups, git status in prompt)
3. Review oh-my-zsh plugins - each adds overhead

### NVM not working?
If `node` command not found after optimization:
```bash
nvm use default  # or nvm use <version>
```

### Starship prompt slow?
Check `~/.config/starship.toml` for expensive modules:
- `localip` with `ssh_only = false`
- `git_status` in large repos
- `cmd_duration` threshold

## References

- [zsh startup profiling](https://stevenvanbael.com/profiling-zsh-startup)
- [nvm lazy loading](https://github.com/nvm-sh/nvm#lazy-loading)
- [Starship performance](https://starship.rs/faq/#why-is-starship-slow)
