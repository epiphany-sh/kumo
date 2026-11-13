# Kumo's shell integration for zsh: marks each prompt (OSC 133;A), where a
# command's output starts (C) and when it's done, with its status (D), so
# Kumo can mark the lines you ran. Your prompt is left as it is.
(( ${+_kumo_marks} )) && return
builtin typeset -g _kumo_marks=1

# First of the precmd hooks, so $? is still the command's. A D with no
# command before it (the first prompt, an empty line) is ignored.
_kumo_precmd() {
  builtin local code=$?
  builtin print -n "\e]133;D;$code\a\e]133;A\a"
  return $code
}

_kumo_preexec() {
  builtin print -n '\e]133;C\a'
}

precmd_functions=(_kumo_precmd $precmd_functions)
preexec_functions+=(_kumo_preexec)
