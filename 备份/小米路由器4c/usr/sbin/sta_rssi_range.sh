#!/bin/sh
LOGGER="/usr/bin/logger"
IWINFO="/usr/bin/iwinfo"
IWPRIV="/usr/sbin/iwpriv"

. /lib/functions.sh
stainfo_idx=7

sta_rssi_init() {
	local string
	for r in `seq 2`; do
		let r=r-1
		for i in `seq 10`; do
			let i=i-1
			string="rssi_array_$r$i"
			eval $string=0;
		done
	done
}

sta_rssi_colloct() {
	local string
	rssi=$1
#wl0 5g
	radio=$((1 - $2))

	if [ $rssi -gt -10 ];  then
		idx=0
	else
		if [ $rssi -le -90 ]; then
			idx=9
		else
			idx=$((0 - $rssi / 10))
		fi

	fi

	string="rssi_array_$radio$idx"
	eval $string=\$\(\(\$\{${string}\} + 1\)\)
}

sta_rssi_update() {
	local string
#直接根据地一个无线接口判断
	bsd_on=`uci get wireless.\@wifi-iface[0].bsd`
	if [ "$bsd_on" = "1" ]; then
		string="network_bsd=on"
	else
		string="network_bsd=off"
	fi
	for r in `seq 2`; do
		let r=r-1
		for i in `seq 10`; do
			let i=i-1
			sta_num=`eval echo \\$rssi_array_${r}${i}`
			string="$string|$sta_num"
		done
	done

	logger stat_points_none $string
}

#只统计两个主接口上的设备
sta_rssi_get() {
	wificount=`cat /etc/config/wireless | grep "wifi-device" | wc -l`

	for n in `seq 2`; do
		let n=n-1
		ifname="wl$n"
		cat /proc/net/dev | grep -q "wl$n"
		if [ $? -eq 1 ]; then
			continue
		fi
		stacount="`${IWINFO} ${ifname} assoclist | grep "stacount:" | awk -F " " '{print $2}'`"
		if [ ! ${stacount} -eq 0 ]; then
			for j in `seq ${stacount}`
			do
				i=$(($j + $stainfo_idx))
				starssi="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $4}'`"
				sta_rssi_colloct $starssi $n
			done
		fi
	done
}

sta_rssi_init
sta_rssi_get
sta_rssi_update
