#!/bin/bash
# vim:set syntax=sh et sw=4:

#
# Disclaimer: use at your own risk! Nothing is really free.
#
# Creates a local copy/backup of a remote subersion repository.
# You might have to explicitly set up your remote repository using a somewhat
# older storage format (3) in order to only get new files on commit and to not
# change existing files. Rsync's --backup option is used to protect
# a perfectly valid backup from getting irreversibly destroyed by bit rot on
# the source side.
#
# Usage: manual_secure_svn_repo_backup.sh $targetDir
#
# Expects a config file at "$targetDir.cfg" to point at the remote svn repository source:
#
# ```
# rsyncSource=root@your.host:/remote/path/to/svn/repos
# gpgDestDir=/tmp (optional)
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
    local bakdir=$(readlink -f "$dst.bak")
    rsync -irlDc --del --backup "--backup-dir=$bakdir" --suffix=.bak-$(date +%Y%m%d-%H%M%S) "$src/" "$dst"
    sync
    echo 3 >/proc/sys/vm/drop_caches || sudo flush_cache
    sync
    echo 3 >/proc/sys/vm/drop_caches || :
    sync
    echo "svnadmin verify..."
    svnadmin verify $dst >&/dev/null
}

tgtdir=${1%/}
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

#sync
#
#if [[ -n "$gpgDestDir" ]]; then
#    tar cf "$tgtdir.tgz" -I pigz -C "$tgtdir" .
#    gpg -v -e "$tgtdir.tgz"
#    chmod 644 "$tgtdir.tgz.gpg"
#    mv -v "$tgtdir.tgz.gpg" "$gpgDestDir/."
#    sync
#fi

echo "All OK."
