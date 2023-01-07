function ffmpeg_split_episodes
    argparse --name=ffmpeg_split_episodes 'n/name_format=' 't/timestamp=' 'c/count=' -- $argv
    or return

    echo $_flag_name_format
    echo $_flag_timestamp
    echo $_flag_count

    if test -d $_flag_name_format; or test -d $_flag_timestamp; or test -d $_flag_count
        echo "Usage: "
        echo "  ffmpeg_split_episodes Curious.George.S01E%s.1080p.WEB.h264-NOMA.mkv \"00:11:58\" 30"
        return 1
    end

    for idx in (seq -f "%02g" $_flag_count)
        set num1 (printf "%02d" (math "$idx * 2 - 1"))
        set num2 (printf "%02d" (math "$idx * 2"))
        set filename (printf $_flag_name_format $idx)
        set extension (string split -r -m1 . $filename)[2]

        ffmpeg -t $_flag_timestamp -c copy $num1.$extension -ss $_flag_timestamp -c copy $num2.$extension -i $filename
    end
end
