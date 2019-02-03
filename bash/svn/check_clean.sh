#!/bin/bash
# vim:set sw=4 ts=4 et ai smartindent fileformat=unix fileencoding=utf-8 syntax=sh:
set -Ee ; set -o pipefail
export LANG=C LC_ALL=C
scriptdir=$(readlink -f "$(dirname "$0")")
cd $1
shift

which svn >/dev/null
which grep >/dev/null
which cut >/dev/null

svnVersion=$(svn info | grep ^Revision: | cut -d " " -f 2)
upUrl=$(svn info | grep ^URL: | cut -d " " -f 2)
svnUpVersion=$(svn info $upUrl | grep ^Revision: | cut -d " " -f 2)

if (( svnVersion != svnUpVersion )); then
    echo "please run svn update" >&2
    exit 2
fi

lcDate=$(LC_ALL=C svn info | grep "^Last Changed Date:" | cut -d " " -f 4 | sed -e 's:-::g')
lcRev=$(LC_ALL=C svn info | grep "^Last Changed Rev:" | cut -d " " -f 4)
svnVersion="$lcRev.v$lcDate"

if (( $(svn status 2>&1 | wc -l) > 0 )); then    
    echo "directory is dirty, has local changes" >&2
    if [[ -n "$FORCE" ]]; then
        svnVersion="$svnVersion.dirty"
    else
        exit 3
    fi
fi

echo -n "$svnVersion"

exit 0
