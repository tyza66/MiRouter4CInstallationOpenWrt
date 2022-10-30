#!/bin/sh

root_path=$1
root_bin=$root_path/bin
root_lib=$root_path/lib
root_user=$root_path/usr

umount $root_lib -l 2>/dev/null
umount $root_bin -l 2>/dev/null
umount $root_user/lib -l 2>/dev/null
umount $root_path/userdata -l 2>/dev/null
umount $root_path/proc -l 2>/dev/null
umount $root_path/dev -l 2>/dev/null
umount $root_path/cache_dir -l 2>/dev/null
umount $root_path/tmp -l 2>/dev/null
umount $root_path/下载 -l 2>/dev/null
