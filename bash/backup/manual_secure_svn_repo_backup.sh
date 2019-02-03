#!/bin/bash
# vim:set syntax=sh et sw=4:

#
# Disclaimer: use at your own risk! Nothing is really free.
#
# Creates a local 'append only' mirror of a remote subersion repository.
# You might have to explicitly set up your remote repository using a somewhat
# older storage format.
#
# Usage: manual_secure_svn_repo_backup.sh $targetDir
#
# Expects a config file at "$targetDir.cfg" to point at the remote svn repository source:
#
# ```
# rsyncSource=root@your.host:/remote/path/to/svn/repos
# ```
#


set -Eex
set -o pipefail

backup() {
    src=$1
    dst=$2
    if test -e "$dst.nobackup"; then
        echo "skipping $dst"
        return
    fi
    echo "$src -> $dst"
    if ! test -d "$dst"; then
        rsync -ai --exclude="/db/transactions/*" "$src/" "$dst"
    fi
    rsync -ai "$src/db/current" "$dst/db/."
    if head -n1 "$dst/db/format" | grep "^6$"; then
        rsync -ai "$src/db/rep-cache.db" "$dst/db/."
        rsync -ai "$src/db/txn-current" "$dst/db/."
    fi
    rsync -ai --ignore-existing '--exclude=/db/transactions/*' "$src/" "$dst"
    sync
    echo 3 >/proc/sys/vm/drop_caches
    sync
    echo 3 >/proc/sys/vm/drop_caches
    sync
    echo "svnadmin verify..."
    if ! head -n1 "$dst/db/format" | grep "^6$"; then
        svnadmin verify $dst >&/dev/null
    else
        echo "svn repository format not supported" >&2
        exit 2
    fi
    echo "verifying checksums..."
    tmpf=$(mktemp)
    trap "rm $tmpf" EXIT
    rsync -ainc --del '--exclude=/db/transactions/*' "$src/" "$dst" 2>&1 | tee $tmpf
    local tmpfsize=$(stat -c %s "$tmpf")
    if (( tmpfsize > 0 )); then
        cat "$tmpf"
        exit 1
    fi
    rm $tmpf
    trap - EXIT
}

tgtdir=$1
source $tgtdir.cfg
if [[ -z "$rsyncSource" ]]; then
    echo "no rsyncSource configured for $tgtdir" >&2
    exit 34
fi

backup $rsyncSource $tgtdir

hostpart=${rsyncSource%%:*}
pathpart=${rsyncSource#*:}
if [[ "$hostpart:$pathpart" != "$rsyncSource" ]]; then
    exit 4
fi
if ! ssh $hostpart svnadmin verify $pathpart >&/dev/null; then
    echo "remote repo verify failed" >&2
    read
    exit 1
fi

sync

echo "All OK."
