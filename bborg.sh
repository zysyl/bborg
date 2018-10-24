#!/usr/bin/env bash
#
#:Date: 2018-10-22 13:25
#:Filename: bborg.sh
#:Author: Roma Slepchik aka zysyl
#:Mail: slepchikrs@gmail.com
#:github: https://github.com/zysyl
#
# Copyright (C) 2018 Roma Slepchik aka zysyl
# Distributed under terms of the MIT license.
#

source $(dirname "$0")/borg.env
export BORG_BASE_DIR=/var/opt/borg

compress_type=lz4
options="--exclude '*isponeclick*' --stats --compression $compress_type"

_check_exist_repo() {
    local username=$1
    borg list --short --first 1 $BORG_USER@$BORG_SERVER:$BORG_SERVER_HOMEDIR/$username >/dev/null 2>&1
    if [[ $? -eq 2 ]]; then
        borg init --encryption=none $BORG_USER@$BORG_SERVER:$BORG_SERVER_HOMEDIR/$username
    fi
}

_create_backup() {
    local username=$1
    logfile=/var/tmp/borg_report.log
    touch $logfile
    chmod 600 $logfile
    fbn=$(borg list --short --first 1 $BORG_USER@$BORG_SERVER:$BORG_SERVER_HOMEDIR/$username)
    hostn=$(hostname -s)
    if [[ -z $fbn ]]; then
        borg create $options $BORG_USER@$BORG_SERVER:$BORG_SERVER_HOMEDIR/$username::init-${username}-{now:%Y-%m-%d}-${hostn} \
            $USERS_HOMEDIR/$username/data $tmpdir 2>> $logfile
    else
        borg create $options $BORG_USER@$BORG_SERVER:$BORG_SERVER_HOMEDIR/$username::${username}-${hostn}-{now:%Y-%m-%d} \
            $USERS_HOMEDIR/$username/data $tmpdir 2>> $logfile
    fi
}

_prune_backup() {
    local username=$1
}

_sendreport() {
cat <<EOF | mail -s "$SUBJ"  "$SEND_TO"
$(cat $logfile)
EOF
}

_ispmgr_dumpdb() {
    local username=$1
    tmpdir=$(mktemp --directory --tmpdir=/var/tmp --suffix=.borg)
    gid=$(id -g $username)
    dblist=$(egrep DbAssign /usr/local/ispmgr/etc/ispmgr.conf | grep $gid | awk '{print $3}')
    for db in $dblist ; do
        mysqldump $db | gzip > $tmpdir/${db}.gz
    done
}

_clear() {
    rm -r $tmpdir
}

for i in $USERS_LIST ; do
    _ispmgr_dumpdb "$i"
    _check_exist_repo "$i"
    _create_backup "$i"
    _clear
done

_sendreport
rm $logfile
