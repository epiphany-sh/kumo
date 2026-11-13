# Kumo's shell integration for zsh.
#
# zsh read this file because Kumo pointed ZDOTDIR at its folder. Put your
# ZDOTDIR back, so your .zprofile, .zshrc and .zlogin load from it as
# always, read your .zshenv, then add the marks.
builtin typeset -g _kumo_zsh="$ZDOTDIR/kumo.zsh"
if [[ -n "${KUMO_USER_ZDOTDIR+x}" ]]; then
  ZDOTDIR="$KUMO_USER_ZDOTDIR"
  builtin unset KUMO_USER_ZDOTDIR
else
  builtin unset ZDOTDIR
fi
[[ -r "${ZDOTDIR:-$HOME}/.zshenv" ]] && builtin source "${ZDOTDIR:-$HOME}/.zshenv"
[[ -o interactive && -r "$_kumo_zsh" ]] && builtin source "$_kumo_zsh"
builtin unset _kumo_zsh
