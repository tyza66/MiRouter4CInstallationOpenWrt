#!/bin/sh
# Copyright (C) 2010-2012 OpenWrt.org

prepare_qos_lt(){
	lt_qos_up=2400
	lt_qos_down=2400
	echo "up is $lt_qos_up , down is $lt_qos_down"
        echo `ps w|grep -v -e "grep" -e "chroot"|grep "lt -f main.conf -d"`
        lt_pid=`ps|grep -v -e "grep" -e "chroot"|grep "lt -f main.conf -d"`
	lt_pid=$(echo $lt_pid|cut -d " " -f 1)
	echo "lt pid is $lt_pid"
	/etc/init.d/miqos on_leteng $lt_qos_up $lt_qos_down
	/etc/init.d/miqos set_leteng_task $lt_pid
	
    if [ -f /dev/cgroup/cpu/proxy/tasks ]; then
		echo $lt_pid > /dev/cgroup/cpu/proxy/tasks
    fi	
}

list_alldir(){  
	for file in `ls $1 | grep [^a-zA-Z]\.manifest$`  
	do  
		if [ -f $1/$file ];then
			accessUserdata=$(grep "access_userdata" $1/$file)
			if ([ "$2"x = "resourcePlugin"x ] && [ -z "$accessUserdata" ]) || ([ "$2"x = "nonResourcePlugin"x ] && [ -n "$accessUserdata" ]);then
				continue
			fi
			#is_supervisord=$(grep "is_supervisord" $1/$file | cut -d'=' -f2 | cut -d'"' -f2)
			#echo "is_supervisord is $is_supervisord"
			status=$(grep -n "^status " $1/$file | cut -d'=' -f2 | cut -d'"' -f2)
			echo "status is $status"
			plugin_id=$(grep "plugin_id" $1/$file | cut -d'=' -f2 | cut -d'"' -f2)
			echo "plugin_id is $plugin_id"

			record_path=/usr/share/datacenter/pluginrecord
			app_path=/userdisk/appdata
			init_file=init_files.record
			dst_path=${app_path}/${plugin_id}/${init_file}
			if [ ! -f ${dst_path} ];then
			    if [ -f ${record_path}/${plugin_id}.record ];then
			        cp ${record_path}/${plugin_id}.record ${dst_path}
				else
				    echo "${app_path}/${plugin_id}/" > ${dst_path}
				    echo "${dst_path}" >> ${dst_path}
			    fi
			fi
			if [ "$status"x = "5"x ];then
				pluginControllor -b $plugin_id >/dev/null 2>&1 &
				if [ "$plugin_id"x = "2882303761517745527"x ];then
					sleep 5
					prepare_qos_lt
				fi
			fi  
		fi  
	done  
}  

monitorLt(){
	result=`ps|grep -v "grep" |grep "lt -f main.conf -d"`
	echo $result
	if [[ "$result" == "" ]]
	then
		status=$(grep -n "^status " /userdisk/appdata/app_infos/2882303761517745527.manifest | cut -d'=' -f2 | cut -d'"' -f2)
		echo "lt status is $status"
		if [ "$status"x = "5"x ];then
			pluginControllor -b 2882303761517745527 >/dev/null 2>&1 &
			sleep 5
			prepare_qos_lt
		fi
	fi
}

case $1 in
		"nonResourcePlugin" | "resourcePlugin")
			echo $1
			pluginControllor -u          
			list_alldir /userdisk/appdata/app_infos $1
			;;
		"monitorLt")
			echo $1
			monitorLt
			;;
		"lt_qos")
			echo $1
			prepare_qos_lt
			;;
esac


