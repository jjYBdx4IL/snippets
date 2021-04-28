# vim:set sw=4 ts=4 et ai smartindent fileformat=unix fileencoding=utf-8 syntax=sh:

_git_fsck_all() {
    local pwd=$(pwd)
    set -Ee
	for f in $pwd/*; do
	    if ! test -d $f/.git; then continue; fi
		echo "$f: "
		cd $f
		LC_ALL=C git fsck --full --strict
	done
	cd $pwd
}

_git_pull_all() {
    local pwd=$(pwd)
	for f in $pwd/*; do
	    if ! test -d $f/.git; then continue; fi
		echo -n "$f: "
		cd $f
		LC_ALL=C git pull --all
	done
	cd $pwd
}

_git_status_all() {
	local okmd5="d158955c3de1219dbdee7368efbfd46c"
	local md5=""
	local pwd=$(pwd)
	for f in $pwd/*; do
	    if ! test -d $f/.git; then continue; fi
		echo -n "$f: "
		cd $f
		md5=`LC_ALL=C git status 2>&1 | md5sum`
		md5=${md5%% *}
		if [[ "$okmd5" != "$md5" ]]; then
			echo
			git status
		else
			echo ok
		fi
	done
	cd $pwd
}

