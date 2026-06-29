#! /usr/bin/env zsh
#
# 伊的zsh配置
#

# Removed 'set -e -o' - this was causing SSH sessions to close on any error
# setopt xtrace

vecho() {
  if [[ -n ${VECHO:-} ]]; then
    echo "$@"
  fi
}

echo "伊的zsh配置"
echo "[uid] $(id -u)"
echo "[iam] $(whoami)"
echo "[pwd] $(pwd)"
echo "[host] $(hostname)"

# Exit if not an interactive shell.
[ -z "$PS1" ] && return

if [[ "$TERM" == "dumb" ]]; then
  unsetopt zle
  unsetopt prompt_cr
  unsetopt prompt_subst

  PS1='...$ ' 
  return
fi

# vecho "stowing files"
# cd ~/the.files
# stow --adopt -R -t ~ .

# cd - > /dev/null # return to og


# scm_breeze setup
if [ -s "$HOME/the.files/scm_breeze/scm_breeze.sh" ]; then
  vecho "sourcing scm_breeze"
  source "$HOME/the.files/scm_breeze/scm_breeze.sh"
fi

for config in ~/.config/zsh/*.zsh; do
    vecho "Sourcing $config"
    source "$config"
done

export TERM=xterm-256color

echo "hello, gently, from self :3"

if [[ -n "${SSH_CONNECTION:-}" ]]; then
  fastfetch
fi

