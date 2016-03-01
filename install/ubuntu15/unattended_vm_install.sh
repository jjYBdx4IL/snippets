#!/bin/bash

sshfwdport=${SSHPORT:-5555}
echo "WARNING! This script will install a VM image with minimum security!" >&2
echo "You will be able to login into the VM on port $sshfwdport as root without any authentication!" >&2

set -Eex
set -o pipefail

VMRESET=yes
USESNAPSHOT=${USESNAPSHOT:-yes}
kernelurl=http://archive.ubuntu.com/ubuntu/dists/wily/main/installer-amd64/current/images/cdrom/
isourl=http://releases.ubuntu.com/15.10/ubuntu-15.10-server-amd64.iso
kvmnetspec="-device e1000,netdev=user.0 -netdev user,id=user.0,hostfwd=tcp::$sshfwdport-:22"
kvmsmpspec="-smp $(grep -c ^proc /proc/cpuinfo)"
kvmram=${RAM:-2048}
maxwait=120
imgsize=100G
imgname="${isourl##*/}"
imgname="${imgname%.*}"
imgbasefile="$imgname.base.img"
imgworkfile="$imgname.work.img"
kvmpid=
sharedFoldersArg=
sharedFoldersMnt=()
sharedFoldersTgt=()


function dl() {
    local arg2=""
    local arg3=""
    if which mvn; then
      if [[ -n "$2" ]]; then
        arg2="-Ddownload.outputFileName=$2"
      fi
      if [[ -n "$3" ]]; then
        arg3="-Ddownload.sha256=$3"
      fi
      if mvn -V -q -B com.googlecode.maven-download-plugin:download-maven-plugin:1.2.1:wget \
        -Dproject.basedir=$(pwd) \
        -Ddownload.url="$1" $arg2 $arg3 ; then return 0; fi
      return 1
    else
      if [[ -n "$2" ]]; then
        arg2="-O $2"
      fi
      if wget -c $arg2 "$1" ; then return 0; fi
      return 1
    fi
}

function runcmd() {
    ssh root@localhost -o TCPKeepAlive=yes -o ConnectTimeout=20 \
      	-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ServerAliveInterval=10 -o ServerAliveCountMax=3 \
	-p $sshfwdport "$@" || return 1
    return 0
}

function waitonline() {
	local rhostname=
	local started=$(date +%s)
        while (( $(date +%s) - started < maxwait )); do
            	if runcmd true; then
			rhostname=$(runcmd hostname)
			if [[ "x$rhostname" == "xbuildvm" ]]; then return 0; fi
                        return 1
		fi
		sleep 3
        done
	return 1
}

cat > ks.cfg <<EOF
#
#Generic Kickstart template for Ubuntu
#Platform: x86 and x86-64
#

#System language
lang en_US

#Language modules to install
langsupport en_US

#System keyboard
keyboard de

#System mouse
mouse

#System timezone
#timezone America/New_York
timezone --utc America/New_York

#Root password
#rootpw --disabled
rootpw rootpass

#Initial user (user with sudo capabilities) 
user ubuntu --fullname "Ubuntu User" --password root4me2

#Reboot after installation
poweroff

#Use text mode install
text

#Install OS instead of upgrade
install

#Installation media
cdrom
#nfs --server=server.com --dir=/path/to/ubuntu/

#System bootloader configuration
bootloader --location=mbr 

#Clear the Master Boot Record
zerombr yes

#Partition clearing information
clearpart --all --initlabel 

#Basic disk partition
part / --fstype ext4 --size 1 --grow --asprimary 
part swap --size 1024 
part /boot --fstype ext4 --size 256 --asprimary 

#Advanced partition
#part /boot --fstype=ext4 --size=500 --asprimary
#part pv.aQcByA-UM0N-siuB-Y96L-rmd3-n6vz-NMo8Vr --grow --size=1
#volgroup vg_mygroup --pesize=4096 pv.aQcByA-UM0N-siuB-Y96L-rmd3-n6vz-NMo8Vr
#logvol / --fstype=ext4 --name=lv_root --vgname=vg_mygroup --grow --size=10240 --maxsize=20480
#logvol swap --name=lv_swap --vgname=vg_mygroup --grow --size=1024 --maxsize=8192

#System authorization infomation
auth  --useshadow  --enablemd5 

#Network information
network --bootproto=dhcp --device=eth0

#Firewall configuration
firewall --disabled --trust=eth0 --ssh 

#Do not configure the X Window System
skipx

%pre

%post
echo buildvm > /etc/hostname
echo "127.0.1.2 buildvm" >> /etc/hosts
sed -i /etc/apt/sources.list -e "s_^deb http\\S* wily_deb http://de.archive.ubuntu.com/ubuntu/ wily_"
sed -i /etc/apt/sources.list -e "s_^deb-src http\\S* wily_deb-src http://de.archive.ubuntu.com/ubuntu/ wily_"
apt-get install -y openssh-server vim
sed -i /etc/ssh/sshd_config -e 's;^PermitRootLogin.*;PermitRootLogin yes;'
sed -i /etc/ssh/sshd_config -e 's;^PermitEmptyPasswords.*;PermitEmptyPasswords yes;'
sed -i 's/nullok_secure/nullok/' /etc/pam.d/common-auth
echo "#!/bin/bash" > /etc/rc.local
echo "passwd -d root" >> /etc/rc.local
echo "GRUB_TERMINAL=console" >> /etc/default/grub
echo "GRUB_TIMEOUT=1" >> /etc/default/grub
echo "GRUB_CMDLINE_LINUX_DEFAULT=" >> /etc/default/grub
update-grub
EOF

function stopvm() {
	while ps -o cmd --ppid $$ -h | grep "^\(kvm\|qemu-system-\)"; do
	    runcmd shutdown -h now || :
	    sleep 5
	done
	trap - EXIT
}

function startvm() {
	local img="$1"
	shift
	kvm -hda "$img" $kvmsmpspec $kvmnetspec -m $kvmram "$@" &
	kvmpid=$!
	trap "kill $kvmpid" EXIT
	waitonline
}

# -fsdev local,security_model=none,id=fsdev0,path=/scratch/apt-archives -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=hostshare-apt
# mount -t 9p -o trans=virtio,version=9p2000.L,access=any,noatime "hostshare-$tag" /scratch/apt-archives
if test -e unattended_vm_install.shared_folders; then
    srcdir=""
    dstdir=""
    devid=0
    while read l; do
	if [[ -z "$srcdir" ]]; then
		srcdir=$(eval "echo \"$l\"")
		if [[ -n "$srcdir" ]] && [[ ! -d "$srcdir" ]]; then install -d "$srcdir"; fi
	elif [[ -z "$tgtdir" ]]; then
		tgtdir="$l"
		sharedFoldersArg="${sharedFoldersArg} -fsdev local,security_model=none,id=fsdev$devid,path=$srcdir -device virtio-9p-pci,id=fs$devid,fsdev=fsdev$devid,mount_tag=hostshare$devid"
		sharedFoldersMnt[$devid]="mount -t 9p -o trans=virtio,version=9p2000.L,access=any,noatime hostshare$devid $tgtdir"
		sharedFoldersTgt[$devid]="$tgtdir"
		devid=$(( devid + 1 ))
              	srcdir=""
		tgtdir=""
	fi
    done <unattended_vm_install.shared_folders
    echo $sharedFoldersArg
    echo ${sharedFoldersMnt[*]}
    echo ${sharedFoldersTgt[*]}
fi

function setupSharedFolders() {
	local f
	for f in "${sharedFoldersTgt[@]}"; do
		runcmd install -d "$f"
	done
	for f in "${sharedFoldersMnt[@]}"; do
		runcmd $f
	done
}

if ! test -e "$imgbasefile"; then
	dl "$isourl" ubuntu15.iso
	dl "$kernelurl/initrd.gz"
	dl "$kernelurl/vmlinuz"

	cp -f target/initrd.gz .
	echo ./ks.cfg | cpio -H newc -o | gzip >> initrd.gz
	rm -f ks.cfg
	# raw 5:19, qed 5:29, vdi 5:04, qcow2 5:26
	qemu-img create -f qcow2 "$imgbasefile.tmp" "$imgsize"

	time kvm -hda "$imgbasefile.tmp" -cdrom target/ubuntu15.iso -kernel target/vmlinuz -initrd initrd.gz \
	    $kvmnetspec -m $kvmram -append "ks=file:///ks.cfg"

	startvm "$imgbasefile.tmp"
	stopvm

	qemu-img convert -c -O qcow2 "$imgbasefile.tmp" "$imgbasefile.tmp2"
	rm -f "$imgbasefile.tmp"
	sync
	mv -fv "$imgbasefile.tmp2" "$imgbasefile"
        rm -f initrd.gz
        rm -rf target
fi
rm -f ks.cfg

if test -e "$imgworkfile" && [[ "unattended_vm_install.build_deps" -nt "$imgworkfile" ]]; then
	rm -f "$imgworkfile"
fi

if test -e "$imgworkfile" && [[ "unattended_vm_install.pkgs" -nt "$imgworkfile" ]]; then
	rm -f "$imgworkfile"
fi

if ! test -e "$imgworkfile"; then
	qemu-img create -f qcow2 -o backing_file="$imgbasefile" "$imgworkfile.tmp"

	startvm "$imgworkfile.tmp" $sharedFoldersArg
	setupSharedFolders
	runcmd apt-get update -qq
	runcmd apt-get dist-upgrade -V -y
	runcmd apt-get build-dep -y `cat unattended_vm_install.build_deps`
	runcmd apt-get install -y `cat unattended_vm_install.pkgs`
	stopvm

	sync
	mv -fv "$imgworkfile.tmp" "$imgworkfile"
fi

if [[ "x$VMRESET" == "xyes" ]] || [[ ! -e "$imgworkfile.tmp" ]]; then
	if [[ "x$USESNAPSHOT" == "xyes" ]]; then
		qemu-img create -f qcow2 -o backing_file="$imgworkfile" "$imgworkfile.tmp"
	else
		qemu-img convert -f qcow2 -O raw "$imgworkfile" "$imgworkfile.tmp"
	fi
fi
startvm "$imgworkfile.tmp" $sharedFoldersArg
setupSharedFolders

# start only?
if [[ "x$1" == "xstart" ]]; then trap - EXIT; exit 0; fi

runcmd -t /bin/bash -l
stopvm

