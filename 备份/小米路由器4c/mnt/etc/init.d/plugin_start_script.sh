#!/bin/sh /etc/rc.common
# Copyright (C) 2010-2012 OpenWrt.org

START=98
STOP=20

prepare_plugin_environment()
{
	bin_list="/bin/busybox /bin/chmod /bin/ping /bin/mount /bin/sh /bin/ash /bin/ls /bin/ps /bin/grep /bin/kill /bin/cat /bin/sed /usr/bin/killall \
	/usr/bin/lua /usr/bin/awk /usr/bin/top /usr/sbin/plugin_action /usr/sbin/plugin_download /usr/sbin/taskmonitorDaemon /bin/mkdir /bin/rm bin/sleep"

	mkdir -p /userdisk/appdata/chroot_file/
	mkdir -p /userdisk/appdata/chroot_file/bin
	mkdir -p /userdisk/appdata/chroot_file/lib
	mkdir -p /userdisk/appdata/chroot_file/usr/lib
	mount --bind /lib /userdisk/appdata/chroot_file/lib/
	mount --bind /usr/lib /userdisk/appdata/chroot_file/usr/lib/
	for bin in $bin_list
	do
		if [ -e $bin ]
		then
			cp -P $bin /userdisk/appdata/chroot_file/bin/
		fi
	done

}

start()
{
	netmode=$(uci get xiaoqiang.common.NETMODE)
	if [ "$netmode"x != "lanapmode"x ] && [ "$netmode"x != "wifiapmode"x ]
	then

		prepare_plugin_environment
		sync
		# decrese current priority and throw myself to mem cgroup
		# so all plugins inherit those attributes
		renice -n+10 -p $$
		echo $$ > /dev/cgroup/mem/group1/tasks
		/usr/sbin/plugin_start_impl_standalone_hd.sh nonResourcePlugin &
	fi
}

stop()
{
	/usr/sbin/plugin_stop_impl_standalone_hd.sh
}
