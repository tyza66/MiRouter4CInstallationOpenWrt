#!/bin/sh
# restart $1 if it's RSS memory exceed $2 KB use method $3
# $1 = process name
# $2 = memory threshold (percentage)
# $3 = "restart method"

[ -z "$1" -o -z "$2" -o -z "$3" ] && return 0

pid=`pidof $1 | awk '{print $1}'`
[ -z $pid ] && return 0

prss=`cat /proc/$pid/status | grep VmRSS | awk '{print $2}'`
[ -z $prss ] && return 0

mtotal=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
pct=$((prss*100/mtotal))

#echo $prss $mtotal $pct

[ "$pct" -lt "$2" ] && return 0

delay=`hexdump -d -n 2 /dev/urandom | head -n 1 |awk '{print $2}'`
delay=$(($delay%3600))
logger -s -p 3 -t "restart_service" "$1 consuming $prss kB memory. Restarting after $delay seconds"
sleep $delay

$3
