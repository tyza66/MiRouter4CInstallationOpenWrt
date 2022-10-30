#!/bin/sh
root_path=$1
root_dev=$root_path/dev
root_proc=$root_path/proc
root_usr_bin=$root_path/usr/bin
root_usr_sbin=$root_path/usr/sbin

umount $root_dev
umount $root_proc

mkdir -p $root_dev
mkdir -p $root_proc
mkdir -p $root_usr_bin
mkdir -p $root_usr_sbin

mount --bind /dev $root_dev
mount --bind /proc $root_proc

cp /usr/bin/awk $root_usr_bin
cp /usr/bin/basename $root_usr_bin
cp /usr/bin/head $root_usr_bin
cp /usr/bin/logger $root_usr_bin
cp /usr/bin/nohup $root_usr_bin
cp /usr/bin/tr $root_usr_bin
cp /usr/sbin/supervisord $root_usr_sbin
