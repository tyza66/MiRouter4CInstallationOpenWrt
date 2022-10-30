#!/bin/sh
root_path=$1
root_cache=$root_path/cache_dir

org_cache_dir=$2

umount $root_cache

mkdir -p $root_cache
chmod 777 $root_cache
mkdir -p $org_cache_dir
chmod 777 $org_cache_dir

mount --bind $org_cache_dir $root_cache
