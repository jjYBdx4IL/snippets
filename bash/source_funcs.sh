# vim:set syntax=sh et sw=4:

# add the following line to your ~/.bashrc:
# . /path/to/this/file/source_funcs.sh

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

funcdir=${BASH_SOURCE%/*}/funcs

if [[ ! -d $funcdir ]]; then
    return
fi

for f in `find "$funcdir" -mindepth 1 -maxdepth 1 -type f -not -name '*~' -not -name '.*' -name '*.inc.sh' -printf '%P\n' | sort`; do
    source "$funcdir/$f"
done

