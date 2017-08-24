# vim:set syntax=sh et sw=4:

_svn_add_unknown_entries() {
    svn status | grep ^? | cut -d " " -f 8 | while read l; do svn add $l; done
}

_svn_delete_missing_entries() {
    svn status | grep ^! | cut -d " " -f 8 | while read l; do svn delete $l; done
}

