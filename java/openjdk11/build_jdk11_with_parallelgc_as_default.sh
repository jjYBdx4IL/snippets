#!/bin/bash

set -Eex
set -o pipefail

tag=$1
git clone https://github.com/openjdk/jdk11u
cd jdk11u
git checkout $tag
export PATH=${PATH//:\/usr\/lib\/ccache/}
sed -i ./src/hotspot/share/gc/shared/gcConfig.cpp -e 's:FLAG_SET_ERGO_IF_DEFAULT(bool, UseG1GC, true);:FLAG_SET_ERGO_IF_DEFAULT(bool, UseParallelGC, true);:g'
bash ./configure --disable-warnings-as-errors --with-version-pre=$tag --with-version-opt=parallelgcdefault
make clean
time nice make bundles
ls -l build/linux*/bundles

