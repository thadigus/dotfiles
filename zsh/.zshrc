# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
if [[ -z "${ZSH:-}" ]]; then
  if [[ -f "/usr/share/oh-my-zsh/oh-my-zsh.sh" ]]; then
    export ZSH="/usr/share/oh-my-zsh"
  else
    export ZSH="$HOME/.oh-my-zsh"
  fi
fi

ZSH_THEME="norm"

# Uncomment one of the following lines to change the auto-update behavior
zstyle ':omz:update' mode auto      # update automatically without asking

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 1

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="mm/dd/yyyy"


# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

[[ -f "$ZSH/oh-my-zsh.sh" ]] && (( ! ${+functions[omz]} )) && source "$ZSH/oh-my-zsh.sh"

# User configuration

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"


if command -v tmux &>/dev/null && [ -z "$TMUX" ] && [[ -o interactive ]] && [ "$TERM_PROGRAM" != "vscode" ]; then
  exec tmux new-session -A -s main
fi

fastfetch -c ~/.config/neofetch.jsonc
export NEWT_COLORS="root=#000000,#212733 roottext=#d9d7ce,#d4d8df border=#686868,#212733 window=#d9d7ce,#212733 shadow=#686868,#191e2a title=#000000,#d4d8df label=#000000,#d4d8df button=#d9d7ce,#212733 actbutton=#191e2a,#6dcbfa compactbutton=#000000,#d4d8df checkbox=#bae67e,#212733 actcheckbox=#191e2a,#bae67e entry=#d9d7ce,#212733 disentry=#686868,#212733 listbox=#d9d7ce,#212733 actlistbox=#191e2a,#6dcbfa sellistbox=#191e2a,#6dcbfa actsellistbox=#191e2a,#fad07b textbox=#d9d7ce,#212733 acttextbox=#191e2a,#73d0ff emptyscale=,#686868 fullscale=,#6dcbfa helpline=#000000,#d4d8df"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.devcontainers/bin:$PATH"

