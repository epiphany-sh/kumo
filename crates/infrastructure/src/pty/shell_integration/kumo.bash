# Kumo's shell integration for bash.
#
# Bash runs this instead of ~/.bashrc (--init-file). Read your startup files
# as bash would have, then mark each prompt (OSC 133;A), where a command's
# output starts (C) and when it's done, with its status (D), so Kumo can
# mark the lines you ran. Your prompt is left as it is.
if [[ -n "${KUMO_BASH_LOGIN-}" ]]; then
  builtin unset KUMO_BASH_LOGIN
  [[ -r /etc/profile ]] && builtin source /etc/profile
  for _kumo_file in ~/.bash_profile ~/.bash_login ~/.profile; do
    if [[ -r "$_kumo_file" ]]; then
      builtin source "$_kumo_file"
      break
    fi
  done
  builtin unset _kumo_file
else
  [[ -r ~/.bashrc ]] && builtin source ~/.bashrc
fi

if [[ -z "${_kumo_marks-}" ]]; then
  _kumo_marks=1

  # First of the prompt commands, so $? is still the command's. A D with
  # no command before it (the first prompt, an empty line) is ignored.
  _kumo_prompt() {
    local code=$?
    builtin printf '\e]133;D;%s\a\e]133;A\a' "$code"
    return $code
  }

  if [[ "$(builtin declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
    PROMPT_COMMAND=(_kumo_prompt "${PROMPT_COMMAND[@]}")
  else
    PROMPT_COMMAND="_kumo_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
  fi

  if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )); then
    # Shown once a command is read, right before it runs.
    PS0="${PS0-}"$'\e]133;C\a'
  elif [[ -z "$(builtin trap -p DEBUG)" ]]; then
    # Older bash (macOS's 3.2) has no PS0: the first command run after the
    # prompt commands is the one you typed.
    _kumo_armed=
    _kumo_preexec() {
      [[ -n "$_kumo_armed" ]] || return 0
      _kumo_armed=
      # Enter on an empty line: straight to the prompt commands.
      [[ "$BASH_COMMAND" == _kumo_prompt* ]] && return 0
      builtin printf '\e]133;C\a'
    }
    _kumo_arm() { _kumo_armed=1; }
    PROMPT_COMMAND="$PROMPT_COMMAND; _kumo_arm"
    builtin trap '_kumo_preexec' DEBUG
  fi
fi
