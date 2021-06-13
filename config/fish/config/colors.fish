# setup the base16 shell and source the colors
if status --is-interactive
    source "$XDG_CONFIG_HOME/base16-shell/profile_helper.fish"
end

set fish_color_autosuggestion magenta
set fish_color_cancel -r
set fish_color_command green
set fish_color_comment brcyan
set fish_color_cwd brgreen
set fish_color_cwd_root red
set fish_color_end brblack
set fish_color_error red
set fish_color_escape yellow
set fish_color_history_current --bold
set fish_color_host normal
set fish_color_match --background=brblue
set fish_color_normal normal
set fish_color_operator blue
set fish_color_param blue
set fish_color_quote yellow
set fish_color_redirection cyan
set fish_color_search_match bryellow --background=black
set fish_color_selection white --bold --background=black
set fish_color_status red
set fish_color_user brgreen
set fish_color_valid_path --underline
set fish_pager_color_completion normal
set fish_pager_color_description yellow --dim
set fish_pager_color_prefix white --bold --underline
set fish_pager_color_progress brwhite --background=cyan
