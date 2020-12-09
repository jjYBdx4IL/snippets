#!/bin/bash

set -Ee
set -o pipefail

renice -n 19 $$ || :
ionice -c3 -p$$ || :

tgtdir=$1
shift

if ! test -e $tgtdir; then    
    install -m 700 -d $tgtdir
    pushd $tgtdir
    git init .
    git config user.name $(whoami)
    git config user.email $(whoami)@$(hostname)
    popd
fi

for srcdir in "$@"; do
    srcdir=$(perl -e '$_=shift;s/\/+$//;print' "$srcdir")
    rsync -ai --del --exclude="**/target/" --exclude="**/.git/" --exclude="**/.svn/" \
        --exclude="**/build/" --exclude="**/bin/" --exclude=".*" "$srcdir" "$tgtdir/"
done

pushd $tgtdir
if (( $(git status -s | wc -l) > 0 )); then
    git add -A
    git commit -m backup
fi
popd
