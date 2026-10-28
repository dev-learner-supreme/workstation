# ==============================================================================
# Omarchy Core Shell Integration
# ==============================================================================
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Load Omarchy system zsh options & shared environment if installed
[[ -f /usr/share/omarchy-zsh/shell/zoptions ]] && source /usr/share/omarchy-zsh/shell/zoptions
[[ -f /usr/share/omarchy-zsh/shell/all ]] && source /usr/share/omarchy-zsh/shell/all

# ==============================================================================
# Environment & Editor
# ==============================================================================
export EDITOR='micro'
export VISUAL='micro'

# ==============================================================================
# History Settings (Persistent, Deduplicated, Shared)
# ==============================================================================
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt EXTENDED_HISTORY          # Record timestamp and duration
setopt SHARE_HISTORY             # Share history across sessions immediately
setopt HIST_EXPIRE_DUPS_FIRST    # Remove duplicate entries first when trimming
setopt HIST_IGNORE_DUPS          # Do not record identical consecutive commands
setopt HIST_IGNORE_ALL_DUPS      # Delete old duplicate entry if new one is typed
setopt HIST_FIND_NO_DUPS         # Do not display duplicates when searching
setopt HIST_IGNORE_SPACE         # Prepending a space prevents saving command
setopt HIST_VERIFY               # Don't execute immediately on history expansion

# Up/Down arrows search history matching current prefix
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# ==============================================================================
# Smart Completion Engine
# ==============================================================================
autoload -Uz compinit
# Cache compdump to keep startup fast
if [ "$(find "$HOME/.zcompdump" -mtime +1 2>/dev/null)" ]; then
  compinit
else
  compinit -C
fi

zmodload -i zsh/complist

# Case-insensitive and partial-word completion (e.g. typing 'cd doc' matches 'Documents')
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Interactive arrow-navigable menu for tab completions
zstyle ':completion:*' menu select

# Colored completions matching ls
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Group matches and display descriptions
zstyle ':completion:*:*:*:*:descriptions' format '%F{green}-- %d --%f'
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes

# ==============================================================================
# Tool Integrations (fzf, zoxide, eza)
# ==============================================================================
# fzf shell integration (Ctrl+R history, Ctrl+T files, Alt+C cd)
if command -v fzf &>/dev/null; then
  source <(fzf --zsh)
fi

# zoxide (smarter cd -> type 'z <dir>')
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# Cross-tool compatibility (fdfind/fd, batcat/bat)
if command -v fd &>/dev/null && ! command -v fdfind &>/dev/null; then
  alias fdfind='fd'
elif command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  alias fd='fdfind'
fi

if command -v bat &>/dev/null && ! command -v batcat &>/dev/null; then
  alias batcat='bat'
fi

# eza aliases (modern ls replacement)
if command -v eza &>/dev/null; then
  alias ls='eza --icons'
  alias ll='eza -lh --icons --git'
  alias la='eza -lha --icons --git'
  alias tree='eza --tree --icons'
fi

# ==============================================================================
# Plugins (Arch Linux / Debian / Ubuntu)
# ==============================================================================
# Autosuggestions (press Right Arrow to accept suggestion)
for _zsh_as in \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  if [ -f "$_zsh_as" ]; then
    source "$_zsh_as"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    break
  fi
done
unset _zsh_as

# Syntax Highlighting (MUST be sourced near the end)
for _zsh_sh in \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  if [ -f "$_zsh_sh" ]; then
    source "$_zsh_sh"
    break
  fi
done
unset _zsh_sh

# ==============================================================================
# SSH Key Management (Omarchy native systemd user socket)
# ==============================================================================
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"


export PATH="$HOME/.local/bin:$PATH"

# Android SDK & Platform Tools
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

# ==============================================================================
# Starship Prompt (Must be at the very end)
# ==============================================================================
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi


# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/Work/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/Work/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/Work/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/Work/google-cloud-sdk/completion.zsh.inc"; fi

# fnm
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi

# Agent Configuration Sync & Diagnostics
alias sync-agent="$HOME/.agents/sync.sh"
alias agent-doctor="$HOME/.agents/skills/agent-health-check/scripts/doctor.sh"

# ==============================================================================
# Navigation & Quick Directory Jump Aliases
# ==============================================================================
# Directory traversal
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Workspaces & Core Hubs
alias cdw='cd ~/Work'
alias cdp='cd ~/Projects'
alias cda='cd ~/.agents'

# Company Repositories (Math-Junior)
alias cdagri='cd ~/Work/ProjectAgri'
alias cdcms='cd ~/Work/CMS'
alias cdweb='cd ~/Work/RODO-Website'
alias cdfb='cd ~/Work/Firebase'
