function ffmpeg_split_episodes
    argparse --name=ffmpeg_split_episodes 'n/name_format=' 't/timestamp=' 'c/count=' -- $argv
    or return

    if test -d $_flag_name_format; or test -d $_flag_timestamp; or test -d $_flag_count
        echo "Usage: "
        echo "  ffmpeg_split_episodes Curious.George.S01E%s.1080p.WEB.h264-NOMA.mkv \"00:11:58\" 30"
        return 1
    end

    for idx in (seq -f "%02g" $_flag_count)
        set filename (printf $_flag_name_format $idx)
        set ext (string split -r -m1 . $filename)[2]
        set ts $_flag_timestamp

        set out1 (printf "%02d.$ext" (math "$idx * 2 - 1"))
        set out2 (printf "%02d.$ext" (math "$idx * 2"))

        ffmpeg -t "$ts" -c copy "$out1" -ss "$ts" -c copy "$out2" -i "$filename"

        if test $status -ne 0
            echo "Failed to run ffmpeg, stopping"
            return $status
        end
    end
end
