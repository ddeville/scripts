function oai_buildbox_check_space --description "Check the remaining spaces on build boxes"
    for box in a b c d e f g h i j
        set df (az ssh vm --ip "cpu-$box.build-box.internal.api.openai.org" -- -o PubkeyAcceptedKeyTypes=+ssh-rsa-cert-v01@openssh.com "df -h" 2>/dev/null | grep /mnt)
        set comps (string split --no-empty ' ' $df)
        echo "cpu-$box is using $comps[5] ($comps[3] out of $comps[2])"
    end
    for box in a b c
        set df (az ssh vm --ip "gpu-$box.build-box.internal.api.openai.org" -- -o PubkeyAcceptedKeyTypes=+ssh-rsa-cert-v01@openssh.com "df -h" 2>/dev/null | grep /mnt)
        set comps (string split --no-empty ' ' $df)
        echo "gpu-$box is using $comps[5] ($comps[3] out of $comps[2])"
    end
end
