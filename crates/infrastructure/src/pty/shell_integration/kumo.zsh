# Kumo's shell integration for zsh: marks each prompt (OSC 133;A), where
# you type (B), where a command's output starts (C) and when it's done, with
# its status (D), so Kumo can mark the lines you ran. It also says the
# folder at each prompt (633;P;Cwd=) and the line you ran (633;E, signed
# with the nonce Kumo gave this shell), so Kumo can remember and suggest it.
# Your prompt looks as it did: B takes no room.
(( ${+_kumo_marks} )) && return
builtin typeset -g _kumo_marks=1

# A shell variable, not exported: what you run here never sees it.
builtin typeset -g _kumo_nonce="${KUMO_NONCE-}"
builtin unset KUMO_NONCE

builtin typeset -g _kumo_escaped
builtin typeset -g _kumo_end=$'%{\e]133;B\a%}'

# $1 with `\`, `;` and the characters that would end a mark escaped.
_kumo_escape() {
  _kumo_escaped=${1//\\/\\\\}
  _kumo_escaped=${_kumo_escaped//;/\\x3b}
  _kumo_escaped=${_kumo_escaped//$'\n'/\\x0a}
  _kumo_escaped=${_kumo_escaped//$'\r'/\\x0d}
  _kumo_escaped=${_kumo_escaped//$'\a'/\\x07}
  _kumo_escaped=${_kumo_escaped//$'\e'/\\x1b}
}

# First of the precmd hooks, so $? is still the command's. A D with no
# command before it (the first prompt, an empty line) is ignored.
_kumo_precmd() {
  builtin local code=$?
  _kumo_escape "$PWD"
  builtin print -rn -- $'\e]133;D;'"$code"$'\a\e]133;A\a\e]633;P;Cwd='"$_kumo_escaped"$'\a'
  # B goes at the end of your prompt: the hook that adds it runs last,
  # after the ones that set your prompt (themes add theirs after Kumo's).
  if [[ "${precmd_functions[-1]}" != _kumo_prompt_end ]]; then
    precmd_functions=(${precmd_functions:#_kumo_prompt_end} _kumo_prompt_end)
  fi
  # The line editor isn't up while .zshenv runs: its hook goes in here,
  # once, before the first prompt.
  if (( ! ${+_kumo_zle} )); then
    builtin typeset -g _kumo_zle=1
    builtin autoload -Uz add-zle-hook-widget 2>/dev/null \
      && add-zle-hook-widget line-init _kumo_line_init 2>/dev/null
  fi
  return $code
}

_kumo_prompt_end() {
  [[ "$PS1" == *"$_kumo_end" ]] || PS1="$PS1$_kumo_end"
}

_kumo_preexec() {
  if [[ -n "$_kumo_nonce" ]]; then
    _kumo_escape "$1"
    builtin print -rn -- $'\e]633;E;'"$_kumo_escaped;$_kumo_nonce"$'\a'
  fi
  builtin print -n '\e]133;C\a'
}

# Where you type is also where the line editor starts: that marks the first
# prompt, whose hooks ran before the one that adds B was last.
_kumo_line_init() {
  builtin print -n '\e]133;B\a'
}

precmd_functions=(_kumo_precmd $precmd_functions _kumo_prompt_end)
preexec_functions+=(_kumo_preexec)
