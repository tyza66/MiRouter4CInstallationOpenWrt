#!/bin/sh
root_path=$1
root_proc=$root_path/proc

umount $root_proc

mkdir -p $root_proc

mount -t proc proc $root_proc

