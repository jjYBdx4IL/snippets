#!/bin/bash

# sorry -- quick hack only, but seems to work
# takes one argument: root dir of our openjdk build.
# puts XML files into current directory.

testrootdir=$1

test -d "$testrootdir" || exit 1

for f in `find "$testrootdir" -name Stats.txt -printf '%P\n'`; do
    reldir=${f%/Stats.txt}
    testname=${reldir//\//.}
    nfail=$(cat "$testrootdir/$reldir/faillist.txt" | wc -l)
    nrun=$(cat "$testrootdir/$reldir/runlist.txt" | wc -l)
    npass=$(cat "$testrootdir/$reldir/passlist.txt" | wc -l)
    x="$testname.xml"
cat > "$x" <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<testsuite errors="0" failures="$nfail" name="$testname" tests="$nrun">
EOF
    cat "$testrootdir/$reldir/passlist.txt" | while read l rest; do
cat >> "$x" <<EOF
    <testcase classname="$testname" name="$l" time="0.0" />
EOF
    done
    cat "$testrootdir/$reldir/faillist.txt" | while read l rest; do
cat >> "$x" <<EOF
    <testcase classname="$testname" name="$l" time="0.0">
        <failure><![CDATA[$rest]]></failure>
    </testcase>
EOF
    done
cat >> "$x" <<EOF
    <system-out><![CDATA[$(cat "$testrootdir/$reldir/output.txt")]]></system-out>
</testsuite>
EOF
done

