IWINFO="/usr/bin/iwinfo"
IWPRIV="/usr/sbin/iwpriv"
IWLIST="/usr/sbin/iwlist"

LOG_TMP_FILE_PATH="/tmp/xiaoqiang.log"
TMP_FILE="/tmp/tmpfile.txt"

LOG_STR="wifi_log: "

if [ $# -eq 1 ]; then
	LOG_TMP_FILE_PATH=$1
fi

wificount=`cat /etc/config/wireless | grep "wifi-device" | wc -l`

echo "${LOG_STR}wificount=\"${wificount}\"" > ${TMP_FILE}

for n in `seq 2`
do
	let n=n-1
	ifname="wl$n"

	cat /proc/net/dev | grep -q "wl$n"
	if [ $? -eq 1 ]; then
		echo "${LOG_STR}Ifname=\"${ifname}\" not exist" >> ${TMP_FILE}
		continue
	fi

	Cur_channel=`${IWINFO} ${ifname} info | awk -F " " '/Channel/{print $4}'`

	if [ $n -eq 0 ]; then
		cat /proc/net/dev | grep -q "apclii0"
		if [ $? -eq 1 ]; then
			Scan_if="${ifname}"
		else
			Scan_if="apclii0"
		fi
	fi
	if [ $n -eq 1 ]; then
		cat /proc/net/dev | grep -q "apcli0"
		if [ $? -eq 1 ]; then
			Scan_if="${ifname}"
		else
			Scan_if="apcli0"
		fi
	fi
	echo "${LOG_STR}Ifname=\"${ifname}\", Current_channel=\"${Cur_channel}\", Scan_if=\"${Scan_if}\"" >> ${TMP_FILE}
	
	# get neighbor bssid list
	${IWLIST} ${Scan_if} scanning > /dev/null 2>&1
	sleep 2
	${IWLIST} ${Scan_if} scanning last | grep -A 4 "Cell" | grep -v "Mode" | grep -v "Protocol" | grep -v "\-\-" >> ${TMP_FILE}
	
	cat ${TMP_FILE} >> ${LOG_TMP_FILE_PATH}
	rm -rf ${TMP_FILE}
done


