#!/bin/bash

# vim:set sw=4 ts=4 et ai smartindent fileformat=unix fileencoding=utf-8 syntax=sh:

# deploys jmonkeyengine to maven central.

set -o pipefail
set -e
set -u
set -x

scriptDir="$(readlink -f "$(dirname "$0")")"

jmeVersion=3.2.1-stable
deployToRemote=0
SKIP_BUILD=${SKIP_BUILD:+yes}

if ! test -d jme; then
    git clone https://github.com/jMonkeyEngine/jmonkeyengine.git jme
fi

pushd jme
#git pull
git checkout v$jmeVersion -f
git clean -f
git status

repoDir="$HOME/.m2/repository"
repoUrl="file://$repoDir"

# bump lwjgl version to latest bugfix release
sed -i ./jme3-lwjgl3/build.gradle -e 's:3.1.2:3.1.6:'

# remove external repository dependence
perl -0777 -i -pe 's/repositories.*?}.*?}//igs' jme3-niftygui/build.gradle

if [[ -z "$SKIP_BUILD" ]]; then
    gradle --stop
    gradle clean
    gradle build javadocJar -x test
fi

newVersion=3.2.1-SNAPSHOT # -SNAPSHOT for test releases
deploymentPlugin=org.apache.maven.plugins:maven-deploy-plugin:2.8.2
if (( deployToRemote )); then
    deploymentPlugin=org.apache.maven.plugins:maven-gpg-plugin:1.6
fi
# change this to deploy to another maven hierarchy, necessary because of ownership in central
relocGroupTo="org.jmonkeyengine"
relocGroupTo="com.github.jjYBdx4IL.jme"

if (( deployToRemote )); then
    repositoryId=oss.sonatype.org
    repoUrl=https://oss.sonatype.org/content/repositories/snapshots/
    #repoUrl=https://oss.sonatype.org/content/repositories/releases/
    keyname="jjYBdx4IL@github.com"
else
    rm -rfv "$repoDir/${relocGroupTo//.//}"
fi

# mvn org.apache.maven.plugins:maven-gpg-plugin:1.6:help -Dgoal=sign-and-deploy-file -Ddetail=true

retry() {
    local n=10
    while (( n > 0 )) && ! timeout --foreground 30m "$@"; do
        n=$((n-1))
    done
    if (( n == 0 )); then return 1; fi
    return 0
}

# path conversion for running maven in cygwin environment
pathcvt() {
    echo "$@"
}
if which cygpath >&/dev/null; then
    pathcvt() {
        cygpath -w -m "$@"
    }
fi

for pomFile in `find "$scriptDir" -name '*.pom'`; do
    libDir="$(dirname "$(dirname "$pomFile")")/libs"
    projectName="$(basename "$(dirname "$(dirname "$(dirname "$pomFile")")")")"
    test -d $libDir
    # remove "-stable" suffixes from version declarations to follow maven central conventions
	sed -i $pomFile -e "s:$jmeVersion:$newVersion:"
    sed -i $pomFile -e "s:groupId>org.jmonkeyengine:groupId>$relocGroupTo:"
    # check for and add sources, javadoc, tests jars
    files=
    types=
    classifiers=
    for classifier in tests; do
        if test -f $libDir/$projectName-$jmeVersion-$classifier.jar; then
            files=$files${files:+,}$(pathcvt "$libDir/$projectName-$jmeVersion-$classifier.jar")
            types=$types${types:+,}jar
            classifiers=$classifiers${classifiers:+,}$classifier
        fi
    done
    if [[ -n "$files" ]]; then
        files="-Dfiles=$files"
        types="-Dtypes=$types"
        classifiers="-Dclassifiers=$classifiers"
    fi
    if (( deployToRemote )); then
        retry mvn $deploymentPlugin:sign-and-deploy-file -DrepositoryId=$repositoryId -Durl=$repoUrl -Dgpg.keyname=$keyname \
            -DpomFile=$(pathcvt "$pomFile") \
            -Djavadoc=$(pathcvt "$libDir/$projectName-$jmeVersion-javadoc.jar") \
            -Dsources=$(pathcvt "$libDir/$projectName-$jmeVersion-sources.jar") \
            $files $types $classifiers \
            -Dfile=$(pathcvt "$libDir/$projectName-$jmeVersion.jar")
    else
        mvn install:install-file \
            -DpomFile=$(pathcvt "$pomFile") \
            -Djavadoc=$(pathcvt "$libDir/$projectName-$jmeVersion-javadoc.jar") \
            -Dsources=$(pathcvt "$libDir/$projectName-$jmeVersion-sources.jar") \
            -Dfile=$(pathcvt "$libDir/$projectName-$jmeVersion.jar")
    fi        
done
popd

# run deployment tests
pushd jme-testproject
sed -i pom.xml -e "s:<jme.version>.*</jme.version>:<jme.version>$newVersion</jme.version>:"
mvn -U clean install

echo "All done."

