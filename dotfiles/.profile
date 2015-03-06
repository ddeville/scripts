alias ll="ls -lahL"
alias oo="open ."
alias con="tail -40 -f /var/log/system.log"
alias topc="top -o cpu"
alias topm="top -o mem"
alias kd="killall Dock"
alias kdns="sudo killall -HUP mDNSResponder"

export EDITOR="vi"
export CLICOLOR=1
export GREP_OPTIONS='--color=auto'
export XCODE="`xcode-select --print-path`"
export PATH="$HOME/scripts/bin:$XCODE/Tools:/usr/local/bin:$PATH"

# .profile for Dropbox

SYMBOLICATOR=iosbuild-vm02.corp.dropbox.com
PORT=15900

for SLAVE in iosbuild-mp01 iosbuild-mp02 iosbuild-mp03 iosbuild-mp04 iosbuild-vm02;
do
    alias ${SLAVE}="ssh $SLAVE"
    alias ${SLAVE}_tunnel="ssh -N -L ${PORT}:${SLAVE}.corp.dropbox.com:5900 releng@build-bastion.corp.dropbox.com& sleep 1;  open vnc://localhost:${PORT}"
    PORT=$((PORT+1))
done

REPO=~/work

function branches()
{
    for DIR in `ls $REPO`;
    do
        echo -n $DIR: 
        (cd $REPO; cd $DIR; hg branch)
    done
}

function activate()
{
     source ~/venv/bin/activate
}

