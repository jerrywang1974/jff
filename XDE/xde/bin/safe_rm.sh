# For Bash
#
# Usage:
#   Add these to ~/.bashrc:
#       export TRASH_DIR=/opt/$USER/Trash   # default is ~/.__trash
#       . /path/to/safe_rm.sh
#
#   Use "/bin/rm" or "\rm" for real rm.

safe_rm () {
    local d t f s

    if [ -z "$PS1" ]; then
        /bin/rm "$@"
    else
        d="${TRASH_DIR:=$HOME/.__trash}/`date +%Y%m-%W`"
        t="`date +%F_%H-%M-%S`"

        mkdir -p "$d" || return

        for f do
            [ -e "$f" ] || {
                echo "Not found: $f" >&2
                continue
            }

            perl -MCwd -e 'index(Cwd::abs_path($ARGV[0]), $ARGV[1]) == 0 ? exit(1) : exit(0)' \
                    "$f" "${TRASH_DIR:-$HOME/.__trash}" || {
                echo "Please use /bin/rm or \rm to delete files in trash." >&2
                continue
            }

            s=$d/`basename "$f"`-$t-$RANDOM
            # Loudly, train users to be careful without this message.
            echo "Move $f to $s ..."
            /bin/mv "$f" "$s" || break
        done

        echo -e "[$? $t `whoami` `pwd`] $@\n" >> "$d/00rmlog.txt"
    fi
}

alias cp='cp -i'
alias mv='mv -i'
alias rm=safe_rm

# Loudly too
[ -z "$PS1" ] || {
    echo
    echo "Made safe aliases for mv/cp/rm, trash at ${TRASH_DIR:-$HOME/.__trash}."
    echo
}

