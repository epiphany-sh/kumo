# Kumo's shell integration for fish: marks each prompt (OSC 133;A), where
# you type (B), where a command's output starts (C) and when it's done, with
# its status (D), so Kumo can mark the lines you ran. It also says the
# folder at each prompt (633;P;Cwd=) and the line you ran (633;E, signed
# with the nonce Kumo gave this shell), so Kumo can remember and suggest it.
# Your prompt looks as it did: B takes no room.
#
# fish 4 marks A, C and D itself.
if not set -q __kumo_marks
    set -g __kumo_marks 1

    # A shell variable, not exported: what you run here never sees it.
    set -g __kumo_nonce "$KUMO_NONCE"
    set -e KUMO_NONCE

    # $argv[1] with `\`, `;` and the characters that would end a mark
    # escaped.
    function __kumo_escape
        set -l s (string replace -a '\\' '\\\\' -- $argv[1] | string collect)
        set s (string replace -a ';' '\\x3b' -- $s | string collect)
        set s (string replace -a \n '\\x0a' -- $s | string collect)
        set s (string replace -a \r '\\x0d' -- $s | string collect)
        set s (string replace -a \a '\\x07' -- $s | string collect)
        string replace -a \e '\\x1b' -- $s
    end

    function __kumo_cwd --on-event fish_prompt
        printf '\e]633;P;Cwd=%s\a' (__kumo_escape "$PWD")
    end

    function __kumo_command --on-event fish_preexec
        if test -n "$__kumo_nonce"
            printf '\e]633;E;%s;%s\a' (__kumo_escape "$argv[1]") "$__kumo_nonce"
        end
    end

    # B at the end of your prompt, whichever prompt you have: it wraps
    # fish_prompt once it's defined (your config.fish has run by the first
    # prompt).
    function __kumo_prompt_end --on-event fish_prompt
        functions -q fish_prompt; or return
        functions -q __kumo_user_prompt; and return
        functions -c fish_prompt __kumo_user_prompt
        function fish_prompt
            __kumo_user_prompt
            printf '\e]133;B\a'
        end
    end

    if test (string match -r '^\d+' -- $version) -lt 4
        function __kumo_preexec --on-event fish_preexec
            printf '\e]133;C\a'
        end

        function __kumo_postexec --on-event fish_postexec
            printf '\e]133;D;%s\a' $status
        end

        function __kumo_prompt --on-event fish_prompt
            printf '\e]133;A\a'
        end
    end
end
