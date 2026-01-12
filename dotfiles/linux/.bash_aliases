# ~/.bash_aliases - Custom aliases for Raspberry Pi 5

# Safety aliases (prompt before overwrite)
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ls improvements
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias lt='ls -ltr'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -20'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# System
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ports='ss -tuln'

# Raspberry Pi specific
alias temp='vcgencmd measure_temp'
alias throttle='vcgencmd get_throttled'
alias volts='vcgencmd measure_volts'
alias clock='vcgencmd measure_clock arm'

# Quick edits
alias bashrc='${EDITOR:-nano} ~/.bashrc && source ~/.bashrc'
alias aliases='${EDITOR:-nano} ~/.bash_aliases && source ~/.bash_aliases'
