function rg --wraps rg --description "Display Rg results in a pager"
    command rg -p $argv | less -RFX
end
