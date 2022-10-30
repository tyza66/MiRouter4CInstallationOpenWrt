#!/bin/sh
# Copyright (C) 2006-2011 OpenWrt.org

if ( ! grep -qs '^root:[!x]\?:' /etc/shadow || \
     ! grep -qs '^root:[!x]\?:' /etc/passwd ) && \
   [ -z "$FAILSAFE" ]
then
	ft_mode=`cat /proc/xiaoqiang/ft_mode`
	if [ "$ft_mode" = "1" ]; then
		exec /bin/ash --login
	else
		busybox login
	fi
fi
