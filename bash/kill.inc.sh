# vim:set syntax=sh et sw=4:

_kill_childs_grep() {
	kill `ps -o pid,cmd | grep $1 | grep -v grep | sed -e 's:\([0-9][0-9]*\).*:\1:'` || :
    ps -o pid,cmd | grep $1 | grep -v grep
}

_kill_by_binary_and_port() {
    local pids=`netstat -tlpen 2>/dev/null | grep "^tcp.* .*:$2 .*\/$1 *$" | sed -e 's:.*\b\([0-9][0-9]*\)/[^\/]*\b.*:\1:'`
    kill -HUP $pids
}

