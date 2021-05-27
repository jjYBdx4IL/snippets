h2gui() {
  local latest="$(ls ~/.m2/repository/com/h2database/h2/*/h2-*.jar |grep -v sources|sort|tail -n1)"
  if [[ $(uname) =~ ^CYGWIN ]]; then
    java "$@" -jar "$(cygpath -w "$latest")"
  else
    java "$@" -jar "$latest"
  fi
}

h2appui() {
    local portoffset=$1||1
    pushd ~/co/devel/java/github/misc/h2-frontend
    mvn wildfly:deploy -DskipTests -Dwildfly.port=$(( 9990 + portoffset)) && xdg-open http://localhost:$((8080+portoffset))/h2/h2
    popd
}
