function fish_greeting
    set_color brblack
    echo "
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
    echo

    set -l l_color (set_color normal; set_color --bold white)
    set -l r_color (set_color normal; set_color green)

    if [ (uname -s) = "Darwin" ]
        echo -n $l_color" OS: "
        echo $r_color(sw_vers -productName) $r_color(sw_vers -productVersion) $r_color(sw_vers -buildVersion)

        echo -n $l_color" Uptime: "
        echo $r_color(uptime | sed -E 's/.*(up.*), [[:digit:]]+ user.*/\1/')

        echo -n $l_color" Disk usage: "
        echo $r_color(df -H | grep '/System/Volumes/Data$' | awk '{printf "%s available (%s)\n", $4, $5}')

        echo -n $l_color" Hostname: "
        echo $r_color(uname -n)
    else
        echo -n $l_color" OS: "
        echo $r_color(uname -rs)

        echo -n $l_color" Uptime: "
        echo $r_color(uptime -p)

        echo -n $l_color" Hostname: "
        echo $r_color(uname -n)
    end

    echo
end
