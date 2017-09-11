#!/bin/bash

# tested with WildFly 11 and Glassfish 4.x

set -x

pubname=$1
if [[ -z $pubname ]]; then
	pubname=ROOT
fi
webappdir=$(ls -d `pwd`/target/*-SNAPSHOT)
iswildfly=0

ctxroot="/$pubname"
if [[ "$pubname" == "ROOT" ]]; then
	ctxroot="/"
fi

if curl http://localhost:9990/ ; then
    iswildfly=1
fi

wildflycmd() {
	local cmd=$1
	curl --digest -L -u admin:admin -D - http://localhost:9990/management \
		--header "Content-Type: application/json" \
		-d "$cmd"
}

if (( iswildfly )); then
	wildflycmd '{"operation" : "composite", "address" : [], "steps" : [{"operation" : "undeploy", "address" : {"deployment" : "'$pubname'.war"}},{"operation" : "remove", "address" : {"deployment" : "'$pubname'.war"}}],"json.pretty":1}'
	wildflycmd '{"operation" : "composite", "address" : [], "steps" : [{"operation" : "add", "address" : {"deployment" : "'$pubname'.war"}, "content" : [{"path" : "'$webappdir'", "archive":"false"}]},{"operation" : "deploy", "address" : {"deployment" : "'$pubname'.war"}}],"json.pretty":1}'
fi

while inotifywait -e close_write -r $webappdir || :; do
    if ! (( iswildfly )); then
    	curl -v -H 'Accept: application/json' \
		-X POST \
		-H 'X-Requested-By: loadr' \
		-F force=true \
		-F id=$webappdir \
		-F isredeploy=true \
		-F virtualservers=server \
		-F contextRoot=$ctxroot \
		-F name=$pubname \
		http://localhost:4848/management/domain/applications/application
    else
        wildflycmd '{"operation" : "composite", "address" : [], "steps" : [{"operation" : "redeploy", "address" : {"deployment" : "'$pubname'.war"}}],"json.pretty":1}'
    fi
done


