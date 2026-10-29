# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# Ensure Omarchy systemd user SSH agent socket is connected
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"

# Ensure Flatpak applications & AppImages are discovered by desktop launcher
if [[ -d "/var/lib/flatpak/exports/share" || -d "$HOME/.local/share/flatpak/exports/share" ]]; then
  export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:/var/lib/flatpak/exports/share:${HOME}/.local/share/flatpak/exports/share"
fi

# Antigravity CLI and Android SDK
export PATH="$HOME/.local/bin:$HOME/Android/Sdk/platform-tools:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# Auto-launch zsh for interactive terminal sessions while keeping bash as system login shell
if command -v zsh &>/dev/null; then
  if [[ $(ps --no-header --pid=$PPID --format=comm 2>/dev/null) != "zsh" && -z "${BASH_EXECUTION_STRING:-}" && ${SHLVL:-1} -le 1 ]]; then
    shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=''
    exec zsh $LOGIN_OPTION
  fi
fi

# All the default Omarchy aliases, functions, and completions
# (source Omarchy interactive core if bash is invoked explicitly)
if [[ -n "$OMARCHY_PATH" && -r "$OMARCHY_PATH/default/bash/rc" ]]; then
  source "$OMARCHY_PATH/default/bash/rc"
fi

# History configuration
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=5000
HISTFILESIZE=10000
shopt -s checkwinsize

# fnm (Fast Node Manager) fallback if installed
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell bash 2>/dev/null)"
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
