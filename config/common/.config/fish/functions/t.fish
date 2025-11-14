function t
    mkdir -p /tmp/scratch
    set name (string split "/" $PWD --right --max=1 --fields=2)
    set path (mktemp --directory --tmpdir=/tmp/scratch $name.XXXXX)
    cd $path
end
