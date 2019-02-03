#!/bin/bash

# uses avconv to split media files into
# equal parts

set -Eex

# the command line arguments
fn=$1
artist=$2
title=$3

# desired length of a single part (secs):
partlen=7200

# overlap (secs)
overlap=15

# how many parts to we need?
n=$(avconv -i "$fn" 2>&1  | perl -ne "use POSIX qw/ceil/;/^  Duration: (\\d+):(\\d+):(\\d+)/&&print ceil((\$1*3600+\$2*60+\$3)/$partlen)")

# equalize length of each part
duration=$(avconv -i "$fn" 2>&1  | perl -ne "/^  Duration: (\\d+):(\\d+):(\\d+)/&&print int((\$1*3600+\$2*60+\$3)/$n)")

# no processing if not more than 1 part
if (( n < 2 )); then
  echo "input too short"
  exit 0
fi

for i in $(seq 1 $n); do
  # input offset
  offset=$(( (i-1) * duration ))
  # part duration argument, plus overlap
  dur="-t $(( duration + overlap ))"
  # last part keeps going until the end
  if (( i == n )); then
    dur=""
  fi
  # extract the part
  avconv -i "$fn" -metadata "artist=$artist" -metadata "title=$title $i/$n" -ss $offset -codec copy $dur "$artist - $title - $i of $n.${fn##*.}"
done

echo Done.
