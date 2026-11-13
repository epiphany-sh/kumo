# Kumo's shell integration for fish: marks each prompt (OSC 133;A), where a
# command's output starts (C) and when it's done, with its status (D), so
# Kumo can mark the lines you ran. Your prompt is left as it is.
#
# fish 4 marks them itself.
if not set -q __kumo_marks; and test (string match -r '^\d+' -- $version) -lt 4
    set -g __kumo_marks 1

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
