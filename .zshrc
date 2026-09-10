export ZSH="$HOME/.oh-my-zsh"
export BAT_THEME="GitHub"
[ -f ~/.zshrc.meta ] && source ~/.zshrc.meta

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="false"

plugins=(z zsh-syntax-highlighting zsh-autosuggestions zsh-completions)

source $ZSH/oh-my-zsh.sh
export EDITOR="nvim"
export VISUAL="nvim"

# Use tmux's terminfo inside tmux. Forcing xterm-256color inside tmux can
# break key-protocol negotiation and leak CSI-u/modifyOtherKeys sequences.
if [[ -n "$TMUX" ]]; then
  export TERM=tmux-256color
else
  export TERM=xterm-256color
fi

export PATH="$PATH:/home/shah256/.cargo/bin"

bindkey -v
# Enable editing command line in editor
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'V' edit-command-line     # V in normal mode
bindkey -M vicmd 'v' visual-mode           # v enters visual mode

alias ls='eza --icons --group-directories-first'

eval "$(atuin init zsh)"
eval "$(starship init zsh)"
eval "$(navi widget zsh)"

# nlog - view logs in nvim with log syntax highlighting
#   nlog app.log        open file(s)
#   tw log ... | nlog   open piped output
nlog() {
  if [ -t 0 ]; then
    nvim -R -c 'set ft=log nowrap' "$@"
  else
    nvim -R -c 'set ft=log nowrap' -
  fi
}

. "$HOME/.local/bin/env"
source $HOME/.local/bin/env
