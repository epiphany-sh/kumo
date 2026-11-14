# Kumo's shell integration for bash.
#
# Bash runs this instead of ~/.bashrc (--init-file). Read your startup files
# as bash would have, then mark each prompt (OSC 133;A), where you type (B),
# where a command's output starts (C) and when it's done, with its status
# (D), so Kumo can mark the lines you ran. It also says the folder at each
# prompt (633;P;Cwd=) and the line you ran (633;E, signed with the nonce
# Kumo gave this shell), so Kumo can remember and suggest it. Your prompt
# looks as it did: B takes no room.
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

  # A shell variable, not exported: what you run here never sees it.
  _kumo_nonce="${KUMO_NONCE-}"
  builtin unset KUMO_NONCE
  _kumo_end=$'\\[\e]133;B\a\\]'
  # The history number of the last line you ran, at the prompt.
  _kumo_seen=

  # $1 with `\`, `;` and the characters that would end a mark escaped.
  _kumo_escape() {
    _kumo_escaped=${1//\\/\\\\}
    _kumo_escaped=${_kumo_escaped//;/\\x3b}
    _kumo_escaped=${_kumo_escaped//$'\n'/\\x0a}
    _kumo_escaped=${_kumo_escaped//$'\r'/\\x0d}
    _kumo_escaped=${_kumo_escaped//$'\a'/\\x07}
    _kumo_escaped=${_kumo_escaped//$'\e'/\\x1b}
  }

  # The last line in the history: its number in _kumo_number, the line in
  # _kumo_line.
  _kumo_last() {
    local entry head rest
    entry=$(HISTTIMEFORMAT= builtin history 1)
    head=${entry%%[0-9]*}
    rest=${entry#"$head"}
    _kumo_number=${rest%%[!0-9]*}
    # "  12* line": the number, a mark for an edited line, a space.
    _kumo_line=${rest:${#_kumo_number}+2}
  }

  # First of the prompt commands, so $? is still the command's. A D with
  # no command before it (the first prompt, an empty line) is ignored.
  _kumo_prompt() {
    local code=$?
    _kumo_escape "$PWD"
    builtin printf '\e]133;D;%s\a\e]133;A\a\e]633;P;Cwd=%s\a' "$code" "$_kumo_escaped"
    return $code
  }

  # Last of the prompt commands, after the ones that set your prompt.
  _kumo_prompt_end() {
    local code=$?
    [[ "$PS1" == *"$_kumo_end" ]] || PS1="$PS1$_kumo_end"
    if [[ -n "$_kumo_nonce" ]]; then
      _kumo_last
      _kumo_seen=$_kumo_number
    fi
    return $code
  }

  # The line about to run, when it went into the history: one that didn't
  # (a space first with ignorespace, history off) isn't remembered.
  _kumo_command() {
    [[ -n "$_kumo_nonce" ]] || return 0
    _kumo_last
    [[ -n "$_kumo_number" && "$_kumo_number" != "$_kumo_seen" ]] || return 0
    _kumo_escape "$_kumo_line"
    builtin printf '\e]633;E;%s;%s\a' "$_kumo_escaped" "$_kumo_nonce"
  }

  if [[ "$(builtin declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
    PROMPT_COMMAND=(_kumo_prompt "${PROMPT_COMMAND[@]}" _kumo_prompt_end)
  else
    PROMPT_COMMAND="_kumo_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}; _kumo_prompt_end"
  fi

  if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )); then
    # Shown once a command is read, right before it runs.
    PS0="${PS0-}"'$(_kumo_command)'$'\e]133;C\a'
  elif [[ -z "$(builtin trap -p DEBUG)" ]]; then
    # Older bash (macOS's 3.2) has no PS0: the first command run after the
    # prompt commands is the one you typed.
    _kumo_armed=
    _kumo_preexec() {
      [[ -n "$_kumo_armed" ]] || return 0
      _kumo_armed=
      # Enter on an empty line: straight to the prompt commands.
      [[ "$BASH_COMMAND" == _kumo_prompt* ]] && return 0
      _kumo_command
      builtin printf '\e]133;C\a'
    }
    _kumo_arm() { _kumo_armed=1; }
    if [[ "$(builtin declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
      PROMPT_COMMAND+=(_kumo_arm)
    else
      PROMPT_COMMAND="$PROMPT_COMMAND; _kumo_arm"
    fi
    builtin trap '_kumo_preexec' DEBUG
  fi
fi
