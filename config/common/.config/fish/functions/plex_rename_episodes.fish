function plex_rename_episodes
    argparse --name=plex_rename_episodes 'n/names=' 'c/count=' 'e/extension=' 'dry_run' -- $argv
    or return

    if test -d $_flag_names; or test -d $_flag_count; or test -d $_flag_extension
        echo "Usage: "
        echo "  plex_rename_episodes -names=\"/path/to/file/with/names.txt\" --count=30 --extension=mkv [--dry_run]"
        return 1
    end

    set file_path (eval echo $_flag_names)  # for ~ expansion
    set filenames (string split '\n' (cat $file_path))

    if test (count $filenames) -ne $_flag_count
        echo "Count ($_flag_count) doesn't match the number of names in the file ("(count $filenames)")"
        return 1
    end

    for idx in (seq $_flag_count)
        set num (printf "%02d" $idx)
        set old_name "$num.$_flag_extension"
        set new_name "$num "(string trim $filenames[$idx])".$_flag_extension"

        if test -f $old_name
            echo "Moving \"$old_name\" to \"$new_name\""

            if test -d $_flag_dry_run
                mv "$old_name" "$new_name"

                if test $status -ne 0
                    echo "Failed to move file, stopping"
                    return $status
                end
            end
        else
            echo "File doesn't exist at \"$old_name\", skipping..."
        end
    end
end
