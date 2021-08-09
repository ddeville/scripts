function fish_greeting
    echo (set_color brblack)"
     /\     /\\
    {  `---'  }
    {  O   O  }
    ~~>  V  <~~
     \  \|/  /
      `-----'____
      /     \    \_
     {       }\  )_\_   _
     |  \_/  |/ /  \_\_/ )
      \__/  /(_/     \__/
        (__/

     Did I hear fish? Meow!
"

    set -l l_color (set_color normal; set_color --bold white)
    set -l r_color (set_color normal; set_color green)

    if [ (uname -s) = "Darwin" ]
        echo $l_color" OS:         "$r_color(sw_vers -productName) $r_color(sw_vers -productVersion) $r_color(sw_vers -buildVersion)
        echo $l_color" Uptime:     "$r_color(uptime | sed -E 's/.*(up.*), [[:digit:]]+ user.*/\1/')
        echo $l_color" Disk usage: "$r_color(df -H | grep '/System/Volumes/Data$' | awk '{printf "%s available (%s used)\n", $4, $5}')
        echo $l_color" User:       "$r_color(id -un)
        echo $l_color" Hostname:   "$r_color(uname -n)
    else
        echo $l_color" OS:         "$r_color(uname -rs)
        echo $l_color" Uptime:     "$r_color(uptime -p)
        echo $l_color" User:       "$r_color(id -un)
        echo $l_color" Hostname:   "$r_color(uname -n)
    end

    echo
end
