# vim:set syntax=bash et sw=4:

_svn_add_unknown_entries() {
    svn status | grep ^? | cut -d " " -f 8 | while read l; do svn add $l; done
}
