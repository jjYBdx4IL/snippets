# vim:set syntax=sh et sw=4:

_mvn_mk_src_dirs() {
	mkdir -p src/{main,test}/{java,resources}
}

_mvn_fast() {
    mvn -Ddependency-check.skip -DskipTests -DskipITs -Dmaven.javadoc.skip -Dcheckstyle.skip -Dlicense.skip -Denforcer.skip clean install "$@"
}

_mvn_summary () 
{ 
    cat  <<EOF
running single tests
====================

mvn -Dtest="BayeuxClientTest#testPerf" test -DfailIfNoTests=false

http://maven.apache.org/plugins/maven-surefire-plugin/examples/single-test.html

disable testing
===============

http://maven.apache.org/plugins/maven-surefire-plugin/test-mojo.html

mvn -Dmaven.test.skip.exec=true install
# or without even building the tests:
mvn -Dmaven.test.skip=true install

find updates
============

mvn versions:display-dependency-updates
mvn versions:display-plugin-updates

analyze project configuration
=============================

mvn help:effective-pom
mvn help:effective-settings

misc
====
-Dmaven.repo.local=
-Dmaven.javadoc.skip=true
mkdir -p src/{main,test}/{java,resources}
-Ddependency-check.skip -DskipTests -DskipITs -Dmaven.javadoc.skip -Dcheckstyle.skip -Dlicense.skip -Denforcer.skip

delete locally built (not downloaded) packages from local repo
==============================================================
find ~/.m2/repository -name maven-metadata-local.xml -printf '%h\n' | while read l; do rm -rfv "\$l"; done

publish a release
=================
mvn release:prepare
git push --all
git push --tags
mvn release:perform

EOF

}

_mvn_search_local_repo () 
{ 
    find ~/.m2/repository/ -name '*.jar' | while read l; do
        if unzip -v "$l" 2>&1 | grep "$1"; then
            echo " \--> found in: $l";
        fi;
    done
}
