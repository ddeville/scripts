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

    if [ (uname -s) = Darwin ]
        echo $l_color" OS:         "$r_color(sw_vers -productName) $r_color(sw_vers -productVersion) $r_color(sw_vers -buildVersion)
        echo $l_color" Uptime:     "$r_color(uptime | sed -E 's/.*(up.*), [[:digit:]]+ user.*/\1/')
        echo $l_color" User:       "$r_color(id -un)
        echo $l_color" Hostname:   "$r_color(uname -n)
        echo $l_color" Disk usage: "$r_color(begin; df -H /System/Volumes/Data 2>/dev/null; or df -H / 2>/dev/null; end | awk 'NR==2 {printf "%s available (%s used)\n", $4, $5}')
    else
        echo $l_color" OS:         "$r_color(uname -rs)
        echo $l_color" Uptime:     "$r_color(uptime -p)
        echo $l_color" User:       "$r_color(id -un)
        echo $l_color" Hostname:   "$r_color(uname -n)
        echo -n $l_color" Disk usage: "
        echo -ne $r_color(\
            df -l -h | \
            grep -E 'dev/(nvme|sd|vda|xvda|root|mapper)' | \
            awk '{
                if (NR!=1) printf "             "
                printf "%s -> %4s available (%s used)\\\\n", $6, $4, $5
            }'
        )
    end

    echo
end
