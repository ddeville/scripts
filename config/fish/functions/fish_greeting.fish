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

    echo -n $l_color" OS: "
    echo $r_color(uname -rs)

    echo -n $l_color" Hostname: "
    echo $r_color(uname -n)

    echo -n $l_color" Uptime: "
    echo $r_color(uptime)

    echo
end
