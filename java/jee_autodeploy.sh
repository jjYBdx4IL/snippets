#!/bin/bash

# tested with WildFly 11 and Glassfish 4.x
# in combination with Maven.
#
# WildFly admin password is assumed to be "admin".
# Defaults to Glassfish unless WildFly admin frontend is
# detected at port 9990.
#
# This script accepts as first parameter $pubname (default=ROOT).
# It defines the context root at which to publish the app.
# ROOT means root context ("/"). Don't use forward slashes.
#
# If a second parameter is specified, its value is ignored. Its presence
# indicates that an actual war archive should be deployed instead of
# just deploying the webapp from the build directory.
#
# JavaEE server instance must be running on the same host
# as maven -- no archive upload is being performed, everything
# is served in place from where "mvn install" is placing it
# during the build.
#
# Make sure your IDE copies updated resources to the maven build
# directories. In eclipse, you can achieve this for src/main/webapp
# folder by exploiting m2e support for build-helper-maven-plugin by
# adding to your pom.xml:
#
#   <plugin>
#        <groupId>org.codehaus.mojo</groupId>
#        <artifactId>build-helper-maven-plugin</artifactId>
#        <executions>
#            <!-- help eclipse identify the webapp folder as a resource folder: -->
#            <execution>
#                <id>add-resource</id>
#                <phase>generate-resources</phase>
#                <goals>
#                    <goal>add-resource</goal>
#                </goals>
#                <configuration>
#                    <resources>
#                        <resource>
#                            <directory>src/main/webapp</directory>
#                            <targetPath>${project.build.directory}/${project.build.finalName}</targetPath>
#                        </resource>
#                    </resources>
#                </configuration>
#            </execution>
#        </executions>
#    </plugin>
#
# You also might want to add:
#
#    <build>
#        <!-- put compiled classes where jetty:run's auto-reload is looking for changes -->
#        <outputDirectory>${project.build.directory}/${project.build.finalName}/WEB-INF/classes</outputDirectory>
#
# If there is no `target/*-SNAPSHOT` file system entry, the current working directory will
# be deployed.
#

set -x

pubname=$1
usewar=$2
if [[ -z $pubname ]]; then
	pubname=ROOT
fi
if [[ -z "$usewar" ]]; then
	usewar=0
else
	usewar=1
fi
if ! webappdir=$(ls -d `pwd`/target/*-SNAPSHOT); then
    webappdir=$(pwd)
fi
iswildfly=0

ctxroot="/$pubname"
if [[ "$pubname" == "ROOT" ]]; then
	ctxroot="/"
fi

port=4848
if curl http://localhost:9991/ ; then
    port=9991
    iswildfly=1
elif curl http://localhost:9990/ ; then
    port=9990
    iswildfly=1
fi

if (( usewar )); then
    webappdir=$webappdir.war
    if ! (( iswildfly )); then
        webappdir="@"$webappdir
    fi
fi

wildflycmd() {
	local cmd=$1
	curl --digest -L -u admin:admin -D - http://localhost:$port/management \
		--header "Content-Type: application/json" \
		-d "$cmd"
}

if (( iswildfly )); then
	wildflycmd '{"operation" : "composite", "address" : [], "steps" : [{"operation" : "undeploy", "address" : {"deployment" : "'$pubname'.war"}},{"operation" : "remove", "address" : {"deployment" : "'$pubname'.war"}}],"json.pretty":1}'
    if (( usewar )); then
	wildflycmd '{"operation" : "composite", "address" : [], "steps" : [{"operation" : "add", "address" : {"deployment" : "'$pubname'.war"}, "content" : [{"url" : "file:'$webappdir'"}]},{"operation" : "deploy", "address" : {"deployment" : "'$pubname'.war"}}],"json.pretty":1}'
    else
	wildflycmd '{"operation" : "composite", "address" : [], "steps" : [{"operation" : "add", "address" : {"deployment" : "'$pubname'.war"}, "content" : [{"path" : "'$webappdir'", "archive":"false"}]},{"operation" : "deploy", "address" : {"deployment" : "'$pubname'.war"}}],"json.pretty":1}'
    fi
fi

while inotifywait -e close_write -r $webappdir --excludei "\.(js|html|css)$" || :; do
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
		http://localhost:$port/management/domain/applications/application
    else
        wildflycmd '{"operation" : "composite", "address" : [], "steps" : [{"operation" : "redeploy", "address" : {"deployment" : "'$pubname'.war"}}],"json.pretty":1}'
    fi
done


