#!/bin/bash

set -Eeo pipefail
if [[ -n "$DEBUG" ]]; then
    set -x
fi
export LC_ALL=C

giturl=$(svn propget giturl .)
relgitpath="${giturl##*:}"
relgitpath="${relgitpath%.git}"
gitcodir=".git-co.tmp"
GITBRANCH="${BRANCH:-master}"

rm -rf "$gitcodir"
tmpf=$(mktemp)
tmpmsgtpl=$(mktemp)
trap "rm -rf \"$tmpf\" \"$tmpmsgtpl\" \"$(pwd)/$gitcodir\"" EXIT

# check if svn work dir is clean
svn update
svn status 2>&1 | tee -a "$tmpf"

diffonly="no"
isdirty=""
if [[ -n "$(cat "$tmpf")" ]]; then
    isdirty=" (dirty)"
    if [[ -z "$FORCE" ]]; then
        diffonly="yes"
    fi
fi
rm "$tmpf"

svnmsg="$(svn log -l 1)"
svnmsglc=$(echo "$svnmsg" | wc -l)
svnmsgtailc=$(( svnmsglc - 3 ))
svnmsgheadlc=$(( svnmsgtailc - 1 ))
echo "$svnmsg" | tail -n $svnmsgtailc | head -n $svnmsgheadlc >> "$tmpmsgtpl"

svnpath="$(svn info | grep ^URL:)"
svnpath="${svnpath#*//*/}"
svnrev="$(svn info | grep "^Last Changed Rev:")"
svnrev="${svnrev#*: }"
[[ "$svnrev" =~ ^[0-9][0-9]*$ ]]

# put some checks (or an empty file) one level above the github
# export root directory (call exit to abort in there):
. ../github_checks.sh

tdirs=$(find . -name target -type d)
if [[ "x" != "x$tdirs" ]]; then
    echo "clean up first"
    exit 3
fi

git clone "--branch=$GITBRANCH" "$giturl" "$gitcodir"

rsync -avc --del "--exclude=/.git/" "--exclude=$gitcodir/" --exclude="**/.svn/" --exclude="/$urlfile" --exclude="/target/" \
    ./ "$gitcodir/."
pushd "$gitcodir"

echo >> README.md
echo >> README.md
echo "--" >> README.md
if test -e .travis.yml; then
  echo "[![Build Status](https://travis-ci.org/$relgitpath.png?branch=$GITBRANCH)](https://travis-ci.org/$relgitpath)" >> README.md
fi
echo "$svnpath@$svnrev$isdirty" >> README.md

git diff
if [[ "$diffonly" == "no" ]]; then
    git add -A
    git status
    echo
    echo "******* COMMIT MESSAGE: ********"
    cat "$tmpmsgtpl"
    echo "********************************"
    echo
    echo "hit ENTER to continue and use this commit message, or enter a new one:" >&2
    read commitmsg
    if [[ -n "$commitmsg" ]]; then echo "$commitmsg" > "$tmpmsgtpl"; fi
    git commit -F "$tmpmsgtpl"
    if [[ -n "$isdirty" ]]; then
        echo 'SVN is DIRTY! Hit ENTER to PUSH changes anyway.'
        read
    fi
    git push
    echo "All OK." >&2
else
    git status
    echo "won't commit because your svn workdir is not clean" >&2
fi
popd


