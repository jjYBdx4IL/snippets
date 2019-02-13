# vim:set syntax=sh et sw=4:

_bash_find_latest_updates() {
    LC_ALL=C find . -printf '%T+  %Tc  %p\n' | LC_ALL=C sort -k 1 | tail -n 1000 | while read l; do echo "${l#*  }"; done
}

_h2() {
    java -jar `find ~/.m2/repository/ -regex '.*/h2-[^-]+.jar' |sort -r|head -n1`
}

_bash_summary() {
cat <<EOF
# line by line replacement, update file in place:
sed -i <filename> -e "s:::"
# multiline replacement, update file in place:
perl -0777 -i -pe "s/a test\nPlease do not/not a test\nBe/igs" alpha.txt

a=''; echo "\${a:+arg} - \${a:-arg}": $(a=''; echo "${a:+arg}  - ${a:-arg}")
a=0;  echo "\${a:+arg} - \${a:-arg}": $(a=0; echo "${a:+arg} - ${a:-arg}")
a=1;  echo "\${a:+arg} - \${a:-arg}": $(a=1; echo "${a:+arg} - ${a:-arg}")

in words:

  :-  <=>  argument is fallback
  :+  <=>  argument replaces value iff value exists

Add installation prefix:

export PATH=\$(pwd)/bin:\$PATH
export LD_LIBRARY_PATH=\$(pwd)/lib:\$LD_LIBRARY_PATH

REGEX: if [[ \$a =~ :([0-9a-z]+) ]]; then echo \${BASH_REMATCH[1]}; fi

# script start

#!/bin/bash
# vim:set sw=4 ts=4 et ai smartindent fileformat=unix fileencoding=utf-8 syntax=sh:
if [[ -n \$DEBUG ]]; then set -x; fi
set -Eex ; set -o pipefail
export LANG=C LC_ALL=C TZ=UTC
scriptdir=\$(dirname "\$(readlink -f "\$0")")
cd \$scriptdir

EOF
}

