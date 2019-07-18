function man --wraps man --description "Format and display manual pages"
    set -x LESS_TERMCAP_mb (set_color brred)
    set -x LESS_TERMCAP_md (set_color brred)
    set -x LESS_TERMCAP_me (set_color normal)
    set -x LESS_TERMCAP_se (set_color normal)
    set -x LESS_TERMCAP_so (set_color -b blue bryellow)
    set -x LESS_TERMCAP_ue (set_color normal)
    set -x LESS_TERMCAP_us (set_color brgreen)

    command man $argv
end
