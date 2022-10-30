#!/bin/sh
# Copyright (C) 2010-2012 OpenWrt.org

list_alldir(){  
	for file in `ls $1 | grep [^a-zA-Z]\.manifest$`  
	do
		if [ -f $1/$file ];then
			accessUserdata=$(grep "access_userdata" $1/$file)
			if [ "$2"x = "resourcePlugin"x ] && [ -z "$accessUserdata" ];then
				continue
			fi
			#is_supervisord=$(grep "is_supervisord" $1/$file | cut -d'=' -f2 | cut -d'"' -f2)
			#echo "is_supervisord is $is_supervisord"
			status=$(grep -n "^status " $1/$file | cut -d'=' -f2 | cut -d'"' -f2)
			echo "status is $status"
			plugin_id=$(grep "plugin_id" $1/$file | cut -d'=' -f2 | cut -d'"' -f2)
			echo "plugin_id is $plugin_id"
			if [ "$status"x = "5"x ];then
				pluginControllor -k $plugin_id
				/usr/sbin/chroot_umout.sh /userdisk/appdata/$plugin_id
			fi
		fi
	done
}                 
list_alldir /userdisk/appdata/app_infos $1 
