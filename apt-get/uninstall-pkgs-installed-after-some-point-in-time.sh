#!/bin/bash
set -Eex
set -o pipefail

find /var/lib/dpkg/info -name '*.list' -type f -cnewer "/var/lib/dpkg/info/<last-pkgname-to-keep>.list" -printf '%P\n' | while read l; do
  l=${l%.list}
  apt-get -y remove ${l%:*}
done
