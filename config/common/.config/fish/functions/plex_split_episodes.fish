function plex_split_episodes
    argparse --name=plex_split_episodes 'n/name_format=' 't/timestamp=' 'c/count=' dry_run -- $argv
    or return

    if test -d $_flag_name_format; or test -d $_flag_timestamp; or test -d $_flag_count
        echo "Usage: "
        echo "  plex_split_episodes -name_format=\"Curious.George.S01E%s.1080p.WEB.h264-NOMA.mkv\" --timestamp=\"00:11:58\" --count=30 [--dry_run]"
        return 1
    end

    for idx in (seq -f "%02g" $_flag_count)
        set filename (printf $_flag_name_format $idx)
        if not test -f $filename
            echo "Cannot find file at path \"$filename\", stopping"
            return 1
        end

        set ext (string split -r -m1 . $filename)[2]
        set ts $_flag_timestamp

        set out1 (printf "%02d.$ext" (math "$idx * 2 - 1"))
        set out2 (printf "%02d.$ext" (math "$idx * 2"))

        echo "Running:"
        echo "  ffmpeg -t \"$ts\" -c copy \"$out1\" -ss \"$ts\" -c copy \"$out2\" -i \"$filename\""

        if test -d $_flag_dry_run
            ffmpeg -t "$ts" -c copy "$out1" -ss "$ts" -c copy "$out2" -i "$filename"

            if test $status -ne 0
                echo "Failed to run ffmpeg, stopping"
                return $status
            end
        end
    end
end
