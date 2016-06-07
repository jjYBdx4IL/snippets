#!/bin/bash

# Sybase ASE 15 Developer Edition Auto-Install Script for Linux (tested on Ubuntu 12.04/amd64)
#
# Hint: the installer requires 32 bit libs (usually installable in addition to your native 64bit stuff).
#
# add to /etc/rc.local on Debian-based systems for automatic startup:
# (you also need to chown sybase.sybase the install dir and add the sybase user and group by "useradd sybase")
#
# (
#    renice 10 $$
#    ionice -c3 -p$$
#    screen -dmS SYBASE sudo -u sybase /bin/bash -c "export LC_ALL=C; source /scratch/syb_UNITTEST/SYBASE.sh ; /scratch/syb_UNITTEST/ASE-15_0/bin/dataserver -sUNITTEST -d/scratch/syb_UNITTEST/data/master.dat -e/scratch/syb_UNITTEST/ASE-15_0/install/ase_server.log -c/scratch/syb_UNITTEST/ASE-15_0/UNITTEST.cfg -M/scratch/syb_UNITTEST/ASE-15_0"
# )  >/dev/null 2>/dev/null &
#

set -e
set -x
export LC_ALL=C
export LANG=C

DESTDIR=$1
SERVERNAME=$2
SERVERPORT=$3
DLDIR=$4

if [[ $# -lt 3 ]]; then
    echo "usage: $0 <DESTDIR> <SERVERNAME> <SERVERPORT> [DLDIR]" >&2
    exit 1
fi

is_server_running() {
    if netstat -tlpn | grep ":$SERVERPORT.*dataserver"; then return 0; fi
    return 1
}

if ! [[ -e "$DESTDIR/.install_done" ]]; then
    if [[ -e $DESTDIR ]]; then
        echo "$DESTDIR already exists" >&2
        exit 3
    fi
    read SHMMAX </proc/sys/kernel/shmmax
    if (( SHMMAX < 128000000 )); then
        echo "add \"echo 128000000 > /proc/sys/kernel/shmmax\" to your startup scripts" >&2
        exit 2
    fi

    if [[ -z $DLDIR ]]; then DLDIR=$HOME; fi
    if [[ ! -e $DLDIR ]]; then mkdir -p $DLDIR; fi

    url="http://download.sybase.com/eval/155/ase155esd2_linuxx86-64.tgz"
    dlfile=$DLDIR/${url##*/}
    unpacked_dir=${url##*/}
    unpacked_dir=$DLDIR/${unpacked_dir%.tgz}.unpacked
    if [[ ! -e $unpacked_dir ]]; then
        rm -rf $unpacked_dir.tmp
        if ! [[ -e $dlfile ]]; then
            wget -O $dlfile.tmp -c "$url"
            sync
            mv -f $dlfile.tmp $dlfile
        fi
        mkdir -p $unpacked_dir.tmp
        tar xz -C $unpacked_dir.tmp -f $dlfile
        sync
        mv -f $unpacked_dir.tmp $unpacked_dir
        # wir behalten nur das *ent*packte Archiv
        rm -f $dlfile
    fi

    cd $unpacked_dir

    test -r sample_response.txt
    test -x setup.bin
    test -e ASE-ThirdPartyLegal.pdf

    tmpf=$(mktemp)
    cat sample_response.txt >> $tmpf
    echo "AGREE_TO_SYBASE_LICENSE=true" >> $tmpf

    sed -i $tmpf \
        -e "s:/opt/sybase:$DESTDIR:g" \
        -e "s:^\(SYBASE_PRODUCT_LICENSE_TYPE\)=.*:\\1=express:g" \
        -e "s:^\(SY_CONFIG_ASE_SERVER\)=.*:\\1=true:g" \
        -e "s:^\(SY_CONFIG_BS_SERVER\)=.*:\\1=false:g" \
        -e "s:^\(SY_CONFIG_XP_SERVER\)=.*:\\1=false:g" \
        -e "s:^\(SY_CONFIG_JS_SERVER\)=.*:\\1=false:g" \
        -e "s:^\(SY_CONFIG_MS_SERVER\)=.*:\\1=false:g" \
        -e "s:^\(SY_CONFIG_SM_SERVER\)=.*:\\1=false:g" \
        -e "s:^\(SY_CONFIG_WS_SERVER\)=.*:\\1=false:g" \
        -e "s:^\(SY_CONFIG_UA_SERVER\)=.*:\\1=false:g" \
        -e "s:^\(SY_CONFIG_TXT_SERVER\)=.*:\\1=false:g" \
        -e "s:^\(SY_CFG_ASE_SERVER_NAME\)=.*:\\1=$SERVERNAME:g" \
        -e "s:^\(SY_CFG_ASE_PORT_NUMBER\)=.*:\\1=$SERVERPORT:g" \
        -e "s:^\(SY_CFG_ASE_SYBTEMP_DB_SIZE\)=.*:\\1=128:g" \
        -e "s:^\(SY_CFG_ASE_SYBTEMP_DEV_SIZE\)=.*:\\1=128:g" \
        -e "s:^\(SY_CFG_ASE_MASTER_DEV_SIZE\)=.*:\\1=256:g" \
        -e "s:^\(SY_CFG_ASE_MASTER_DB_SIZE\)=.*:\\1=26:g"
        
    ./setup.bin -i silent -f $tmpf
    source $DESTDIR/SYBASE.sh
    while is_server_running; do
        echo -e "
use master
go
-- do *NOT* do that in *PRODUCTION*!!
create procedure sp_thresholdaction 
        @dbname varchar(30),
        @segmentname varchar(30),
        @space_left int,
        @status int
as
        dump transaction @dbname with truncate_only
go
-- do not use master db for testing - too many limitations there
create database unittest on default = 64
go
sp_dboption unittest, 'select into/bulkcopy/pllsort', 'true'
go
shutdown
go
" | isql -S$SERVERNAME -Usa -P'' || true
        sleep 3
    done
    sed -i $DESTDIR/interfaces -e 's:\(tcp ether\) \S*:\1 127.0.0.1:g'
    touch "$DESTDIR/.install_done"
fi

if netstat -tlpn | grep ":$SERVERPORT.*dataserver"; then exit 0; fi

. $DESTDIR/SYBASE.sh
cmd="$DESTDIR/ASE-15_0/bin/dataserver -s$SERVERNAME -d$DESTDIR/data/master.dat -e$DESTDIR/ASE-15_0/install/ase_server.log -c$DESTDIR/ASE-15_0/$SERVERNAME.cfg -M$DESTDIR/ASE-15_0"
if (( DEBUG )); then
    $cmd
else
    $cmd >&/dev/null &
fi


