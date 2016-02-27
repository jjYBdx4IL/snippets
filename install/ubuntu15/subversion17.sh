#!/bin/bash
set -Eex
apt-get -y install wget checkinstall
apt-get -y build-dep subversion
wget -c http://mirror.23media.de/apache/subversion/subversion-1.7.22.tar.bz2
tar xjf subversion-1.7.22.tar.bz2
rm -rf subversion17-1.7.22
mv subversion-1.7.22 subversion17-1.7.22
cd subversion17-1.7.22
./configure --prefix=/opt/svn17 --enable-broken-httpd-auth --without-berkeley-db --without-apache --without-apxs --without-swig
make -j4
checkinstall --default --install
/opt/svn17/bin/svn --version
echo OK
