# vim:set syntax=sh et sw=4:

_git_pull_all() {
	local pwd=$(pwd)
	for f in $pwd/*; do
	    if ! test -d $f/.git; then continue; fi
		echo -n "$f: "
		cd $f
		git pull --all
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


_git_summary () 
{ 
    cat  <<EOF

create a "master" repository from another existing master repository
==================================================================

git clone --bare https://.../mystuff.git mystuff.git

update with *all* tags
======================

git pull --tags

clean local checkout
====================
# test:
git clean -d -x -n
# do:
git clean -d -x -f
git checkout -f

merge upstream changes
======================
git remote add upstream https://github.com/krenfro/fannj.git
git pull upstream master

reset master to upstream
========================
http://stackoverflow.com/questions/5916329/cleanup-git-master-branch-and-move-some-commit-to-new-branch

Make a new branch to hold stuff

$ git branch old_master
Send to remote for backup (just incase)

$ git checkout old_master
$ git push origin old_master
Reset local master to the commit before you started modifying stuff

$ git checkout master
$ git reset --hard 037hadh527bn
Merge in changes from upstream master

$ git pull upstream master
Now DELETE master on remote repo

On github this won't work without first going into the admin section for the fork and setting the default branch to something other than master temporarily as they try and protect you from blowing stuff away.

$ git push origin :master
And recreate it

$ git push origin master
On github you should now set the default branch back to master

EOF

}
