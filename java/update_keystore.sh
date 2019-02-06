#!/bin/bash

set -Eex
set -o pipefail

# export JAVA_HOME=/opt/jdk8
# export PATH=$JAVA_HOME/bin:$PATH

# cd /etc/letsencyrpt/*/live

rm -f jetty.pkcs12
openssl pkcs12 -inkey privkey.pem -in fullchain.pem -export -out jetty.pkcs12 -passout pass:password
rm -f keystore
keytool -importkeystore -srckeystore jetty.pkcs12 -srcstoretype PKCS12 -destkeystore keystore -deststorepass password -srcstorepass password
mv -f keystore ~web/.
chown web.web ~web/keystore
chmod 600 ~web/keystore

