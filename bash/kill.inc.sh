# vim:set syntax=sh et sw=4:

_kill_childs_grep() {
	kill `ps -o pid,cmd | grep $1 | grep -v grep | sed -e 's:\([0-9][0-9]*\).*:\1:'` || :
    ps -o pid,cmd | grep $1 | grep -v grep
}

