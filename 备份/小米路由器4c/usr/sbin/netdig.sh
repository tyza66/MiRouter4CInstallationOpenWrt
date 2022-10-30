#!/bin/ash
APP_NAME=$0
RET=0
TMP_FILE_="/tmp/netdig_tmp"
usage(){
	echo "Usage: $0 config-file"
	echo "	config-file ex:"
	echo "	192.1681.1.1:4:100"
	echo "	ip:count:max-of-random-delay"
}
read_config_from_file(){
	if [ $# -ne 1 ]; then
		usage
		exit 1
	else
		CONFIG_FILE="$1"
		if [ -f $CONFIG_FILE ]; then
			IP=$(cat $CONFIG_FILE | awk -F ':' '{print $1}')
			COUNT=$(cat $CONFIG_FILE | awk -F ':' '{print $2}')
			MAX_DELAY=$(cat $CONFIG_FILE | awk -F ':' '{print $3}')

			if [ "$IP" = "" ] || [ "$COUNT" = "" ] || [ "$MAX_DELAY" = "" ]; then
				echo "config file parse error"
				usage
				exit 3
			fi
		else
			echo "config file miss"
			exit 2
		fi
	fi
}


read_config_from_uci(){
	COUNT=$(uci get netdig.config.count | sed 's/[^0-9]//g' 2> /dev/NULL)
	MAX_DELAY=$(uci get netdig.config.max_delay | sed 's/[^0-9]//g' 2> /dev/NULL)
}


parse_ping_file(){
	TMP_FILE=$1
	BUSYBOX_PING=$(ping -v 2>&1 | grep BusyBox > /dev/NULL ; echo $?)
	echo "ping tmp file $TMP_FILE"
	if [ -f $TMP_FILE ]; then
		if [ $BUSYBOX_PING == "0" ]; then 

			TRUE_IP=$(cat $TMP_FILE | grep PING | cut -d ' ' -f 3 | sed 's/[(,)]//g' 2> /dev/NULL)
			CNAME=$(cat $TMP_FILE | grep PING | cut -d ' ' -f 2 2> /dev/NULL)
			MIN=$(cat $TMP_FILE | grep round-trip | cut -d ' ' -f 4 | cut -d '/' -f 1 2> /dev/NULL)
			AVG=$(cat $TMP_FILE | grep round-trip | cut -d ' ' -f 4 | cut -d '/' -f 2 2> /dev/NULL)
			MAX=$(cat $TMP_FILE | grep round-trip | cut -d ' ' -f 4 | cut -d '/' -f 3 2> /dev/NULL)
			MDEV=0
			TRANS=$(cat $TMP_FILE | grep received | cut -d ' ' -f 1 2> /dev/NULL)
			RECV=$(cat $TMP_FILE | grep received | cut -d ' ' -f 4 2> /dev/NULL)
			#LOSS=$((TRANS-RECV))
			TIME=0
		else
			TRUE_IP=$(cat $TMP_FILE | grep PING | cut -d ' ' -f 3 | sed 's/[(,)]//g' 2> /dev/NULL)
			CNAME=$(cat $TMP_FILE | grep PING | cut -d ' ' -f 2 2> /dev/NULL)
			MIN=$(cat $TMP_FILE | grep rtt | cut -d ' ' -f 4 | cut -d '/' -f 1 2> /dev/NULL)
			AVG=$(cat $TMP_FILE | grep rtt | cut -d ' ' -f 4 | cut -d '/' -f 2 2> /dev/NULL)
			MAX=$(cat $TMP_FILE | grep rtt | cut -d ' ' -f 4 | cut -d '/' -f 3 2> /dev/NULL)
			MDEV=$(cat $TMP_FILE | grep rtt | cut -d ' ' -f 4 | cut -d '/' -f 4 2> /dev/NULL)
			TRANS=$(cat $TMP_FILE | grep received | cut -d ' ' -f 1 2> /dev/NULL)
			RECV=$(cat $TMP_FILE | grep received | cut -d ' ' -f 4 2> /dev/NULL)
			#LOSS=$(cat $TMP_FILE | grep received | cut -d ' ' -f 6 | sed 's/%//g' 2> /dev/NULL)
			TIME=$(cat $TMP_FILE | grep received | cut -d ' ' -f 10 | sed 's/ms//g' 2> /dev/NULL)
		fi
			LOSS=`awk 'BEGIN{printf "%.0f",('$((TRANS-RECV))'/'$TRANS')*100}'`
			TIMESTAMP=$(date +%s)
	else
		echo "parse ping result ($2) error ret:$RET"
		return 199
	fi
}


ping_test(){
	ping $1 -c $COUNT > $TMP_FILE_
	RET=$?
	if [ $RET -ne 0 ]; then
		echo "ping ($1) error ret:$RET"
		return $RET
	else
		parse_ping_file $TMP_FILE_ $1
		return $?
	fi
}
random(){
	RANDOM_MIN=$1
	RANDOM_MAX=$2-$RANDOM_MIN
#	RANDOM_RET=($RANDOM%$RANDOM_MAX + $RANDOM_MIN)
	return $RANDOM_RET
}

keep_alone(){
	pkill APP_NAME
}


read_config_from_uci

MAX_DELAY=$(echo $MAX_DELAY | sed 's/[^0-9]//g')
MAX_DELAY=$(printf %d $MAX_DELAY)
COUNT=$(echo $COUNT | sed 's/[^0-9]//g')
COUNT=$(printf %d $COUNT)

#echo $MAX_DELAY
if [ "$MAX_DELAY" = "0" ] || [ "$MAX_DELAY" = "" ] || [ $MAX_DELAY -gt 7200 ]; then
	DELAY=0
else
	RANDOM=$(cat /proc/sys/kernel/random/uuid | cut -f1 -d '-')
	RANDOM=$(printf %d 0x$RANDOM)
	DELAY=$(($RANDOM%$MAX_DELAY))
fi


echo DELAY=$DELAY

if [ "$COUNT" = "0" ] || [ "$COUNT" = "" ] || [ $COUNT -gt 128 ]; then
	COUNT=4
fi

echo $MAX_DELAY
echo $COUNT
#exit 0
sleep $DELAY

for ip in `uci get netdig.config.ip_list`
do
	echo "*********************************************************************"
	ping_test $ip
	RET=$?
	if [ $RET -ne 0 ]; then
		echo "..ping $ip error ret:$RET"
		logger  stat_points_none netdig_info="$RET,$ip"
	else
		echo "..ping $ip success ret:"
		echo "ping $2 res:"
		echo "ip=$ip"
		echo "cname=$CNAME"
		echo "TRUE_IP=$TRUE_IP"
		echo "min=$MIN"
		echo "avg=$AVG"
		echo "max=$MAX"
		echo "mdev=$MDEV"
		echo "trans=$TRANS"
		echo "recv=$RECV"
		echo "loss=$LOSS"
		echo "time=$TIME"
		echo "timestamp=$TIMESTAMP"
		logger  stat_points_none netdig_info="$RET,$ip,$CNAME,$TRUE_IP,$MIN,$AVG,$MAX,$MDEV,$TRANS,$RECV,$LOSS,$TIME,$TIMESTAMP"
	fi
done


