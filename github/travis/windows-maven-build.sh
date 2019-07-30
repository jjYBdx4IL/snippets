#!/bin/bash

set -Eev

choco install unzip || :
choco install zip || :
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"

sdk install java 11.0.2-open
sdk install maven 3.6.0
mvn -q clean install

