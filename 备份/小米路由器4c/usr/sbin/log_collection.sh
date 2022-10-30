#!/bin/sh

redundancy_mode=`uci get misc.log.redundancy_mode`

LOG_TMP_FILE_PATH="/tmp/xiaoqiang.log"
LOG_ZIP_FILE_PATH="/tmp/log.tar.gz"

WIRELESS_FILE_PATH="/etc/config/wireless"
WIRELESS_STRIP='/tmp/wireless.conf'
NETWORK_FILE_PATH="/etc/config/network"
NETWORK_STRIP="/tmp/network.conf"
MACFILTER_FILE_PATH="/etc/config/macfilter"
CRONTAB="/etc/crontabs/root"

LOG_DIR="/data/usr/log/"
LOGREAD_FILE_PATH="/data/usr/log/messages"
LOGREAD0_FILE_PATH="/data/usr/log/messages.0"
LOG_WIFI_AYALYSIS="/data/usr/log/wifi_analysis.log"
LOG_WIFI_AYALYSIS0="/data/usr/log/wifi_analysis.log.0.gz"
PANIC_FILE_PATH="/data/usr/log/panic.message"
TMP_LOG_FILE_PATH="/tmp/messages"
TMP_WIFI_LOG_ANALYSIS="/tmp/wifi_analysis.log"
TMP_WIFI_LOG="/tmp/wifi.log"
DHCP_LEASE="/tmp/dhcp.leases"
IPTABLES_SAVE="/tmp/iptables_save.log"
TRAFFICD_LOG="/tmp/trafficd.log"
PLUGIN_LOG="/tmp/plugin.log"
LOG_MEMINFO="/proc/meminfo"
LOG_SLABINFO="/proc/slabinfo"
DNSMASQ_CONF="/var/etc/dnsmasq.conf"
QOS_CONF="/etc/config/miqos"
WIFISHARE_CONF="/etc/config/wifishare"
MICLOUD_LOG="/tmp/micloudBackup.log"
GZ_LOGS=""

hardware=`uci get /usr/share/xiaoqiang/xiaoqiang_version.version.HARDWARE`

# $1 plugin install path
# $2 output file path
list_plugin(){
    for file in `ls $1 | grep [^a-zA-Z]\.manifest$`
    do
        if [ -f $1/$file ];then
            status=$(grep -n "^status " $1/$file | cut -d'=' -f2 | cut -d'"' -f2)
            plugin_id=$(grep "name" $1/$file | cut -d'=' -f2 | cut -d'"' -f2)
            if [ "$status"x = "5"x ]; then
		echo "$plugin_id" >> $2 # eanbled
        fi
        fi
    done
}

rm -f $LOG_TMP_FILE_PATH

cat $TMP_LOG_FILE_PATH >> $LOGREAD_FILE_PATH
> $TMP_LOG_FILE_PATH

cat $TMP_WIFI_LOG_ANALYSIS >> $LOG_WIFI_AYALYSIS
> $TMP_WIFI_LOG_ANALYSIS

echo "==========SN" >> $LOG_TMP_FILE_PATH
nvram get SN >> $LOG_TMP_FILE_PATH

echo "==========uptime" >> $LOG_TMP_FILE_PATH
uptime >> $LOG_TMP_FILE_PATH

echo "==========df -h" >> $LOG_TMP_FILE_PATH
df -h >> $LOG_TMP_FILE_PATH

echo "==========bootinfo" >> $LOG_TMP_FILE_PATH
bootinfo >> $LOG_TMP_FILE_PATH

echo "==========tmp dir" >> $LOG_TMP_FILE_PATH
ls -lh /tmp/ >> $LOG_TMP_FILE_PATH
du -sh /tmp/* >> $LOG_TMP_FILE_PATH

echo "==========iwpriv wl0" >> $LOG_TMP_FILE_PATH
iwpriv wl0 e2p >> $LOG_TMP_FILE_PATH

echo "==========iwpriv wl1" >> $LOG_TMP_FILE_PATH
iwpriv wl1 e2p >> $LOG_TMP_FILE_PATH

echo "==========ifconfig" >> $LOG_TMP_FILE_PATH
ifconfig >> $LOG_TMP_FILE_PATH

echo "==========/proc/net/dev" >> $LOG_TMP_FILE_PATH
cat /proc/net/dev >> $LOG_TMP_FILE_PATH

echo "==========/proc/bus/pci/devices" >> $LOG_TMP_FILE_PATH
cat /proc/bus/pci/devices >> $LOG_TMP_FILE_PATH

echo "==========route" >> $LOG_TMP_FILE_PATH
route -n >> $LOG_TMP_FILE_PATH

echo "==========ip -6 route" >> $LOG_TMP_FILE_PATH
ip -6 route >> $LOG_TMP_FILE_PATH

cat $NETWORK_FILE_PATH | grep -v -e'password' -e'username' > $NETWORK_STRIP

cat $WIRELESS_FILE_PATH | grep -v 'key' > $WIRELESS_STRIP

echo "==========ps" >> $LOG_TMP_FILE_PATH
ps -w >> $LOG_TMP_FILE_PATH


log_exec()
{
    echo "========== $1" >>$LOG_TMP_FILE_PATH
    eval "$1" >> $LOG_TMP_FILE_PATH
}

list_messages_gz(){
    for file in `ls /data/usr/log/ | grep ^messages\.[1-4]\.gz$`; do
        GZ_LOGS=${GZ_LOGS}" /data/usr/log/"${file}
    done
}

if [ "$hardware" = "R1D" ] || [ "$hardware" = "R2D" ]; then
    /sbin/wifi_rate.sh 6 1 >> $LOG_TMP_FILE_PATH
    local wps_proc_status
    for count in `seq 0 3`; do
        i=$(($count%2))
        wps_proc_status=`nvram get wps_proc_status`

        if [ "$wps_proc_status" = "0" ]; then
            log_exec "acs_cli -i wl$i dump bss"
        else
            echo "========== wps is running!" >>$LOG_TMP_FILE_PATH
        fi
        log_exec "iwinfo wl$i info"
        log_exec "iwinfo wl$i assolist"
        log_exec "wl -i wl$i dump wlc"
        log_exec "wl -i wl$i dump bsscfg"
        log_exec "wl -i wl$i dump scb"
        log_exec "wl -i wl$i dump ampdu"
        log_exec "wl -i wl$i dump dma"
        log_exec "wl -i wl$i chanim_stats"
        log_exec "wl -i wl$i counters"
        log_exec "wl -i wl$i dump stats"
        log_exec "wl -i wl$i curpower"
        sleep 1
    done
elif [ "$hardware" = "R3D" ]; then
    for i in `seq 0 1`; do
        # wifi
        log_exec "athstats -i wifi$i >> $LOG_TMP_FILE_PATH"
    done
    for i in 0 1 13 14; do
        # wl
        log_exec "iwinfo wl$i info >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i assolist >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i txpowerlist >> $LOG_TMP_FILE_PATH"
        log_exec "iwinfo wl$i freqlist >> $LOG_TMP_FILE_PATH"
        log_exec "wlanconfig wl$i list >> $LOG_TMP_FILE_PATH"
        log_exec "80211stats -a -i wl$i >> $LOG_TMP_FILE_PATH"
	log_exec "iwpriv wl$i txrx_fw_stats 1"
	log_exec "iwpriv wl$i txrx_fw_stats 3"
	log_exec "iwpriv wl$i txrx_fw_stats 19"
	log_exec "iwpriv wl$i txrx_fw_stats 20"
    done
    /usr/sbin/getneighbor.sh ${LOG_TMP_FILE_PATH} > /dev/null 2>&1
else
#On R1CM, The follow cmd will print result to dmesg.
    for i in `seq 0 3`; do
            log_exec "iwinfo wl$i info"
            log_exec "iwinfo wl$i assolist"
            log_exec "iwinfo wl$i txpowerlist"
            log_exec "iwinfo wl$i freqlist"
            log_exec "iwpriv wl$i stat"
            log_exec "iwpriv wl$i show stat"
            log_exec "iwpriv wl$i show stainfo"
            log_exec "iwpriv wl$i rf"
            log_exec "iwpriv wl$i bbp"
    done
    /usr/sbin/getneighbor.sh ${LOG_TMP_FILE_PATH} > /dev/null 2>&1


fi



#On R1D, the follow print to UART.
echo "==========dmesg:" >> $LOG_TMP_FILE_PATH
dmesg >> $LOG_TMP_FILE_PATH
sleep 1
echo "==========meminfo" >> $LOG_TMP_FILE_PATH
cat $LOG_MEMINFO >> $LOG_TMP_FILE_PATH

echo "==========topinfo" >> $LOG_TMP_FILE_PATH
top -b -n1 >> $LOG_TMP_FILE_PATH

echo "==========slabinfo"  >> $LOG_TMP_FILE_PATH
cat $LOG_SLABINFO >> $LOG_TMP_FILE_PATH

[ -f "/usr/sbin/et" ] && {
    echo "==========et port_status:" >> $LOG_TMP_FILE_PATH
    /usr/sbin/et port_status >> $LOG_TMP_FILE_PATH
}

[ -b /dev/sda -a "SATA" = "`getdisk bus sda`" ] && {
    echo "==========smartctl info:" >> $LOG_TMP_FILE_PATH
    smartctl --all /dev/sda >> $LOG_TMP_FILE_PATH
}

#dump ppp and vpn status
log_exec "cat /tmp/pppoe.log"
log_exec "cat /tmp/vpn.stat.msg"
log_exec "ubus call turbo_ccgame get_pass"


iptables-save -c > $IPTABLES_SAVE
ubus call trafficd hw '{"debug":true}' > $TRAFFICD_LOG

# list enabled plugin's name
list_plugin /userdisk/appdata/app_infos $PLUGIN_LOG

list_messages_gz

MICLOUD_LOG_PATH="/userdisk/data/.pluginConfig/2882303761517344979/micloudBackup.log"

[ -f $MICLOUD_LOG_PATH ] && {
    FILE_SIZE=`ls -l $MICLOUD_LOG_PATH | awk '{print $5}'`
    [ $FILE_SIZE -lt 4194304 ] && {
        cp $MICLOUD_LOG_PATH $MICLOUD_LOG
    }
}

# busybox's tar requires every source file existing!!
[ -e "$IPTABLES_SAVE" ] || IPTABLES_SAVE=
[ -e "$TRAFFICD_LOG" ] || TRAFFICD_LOG=
[ -e "$PLUGIN_LOG" ] || PLUGIN_LOG=
[ -e "$NETWORK_STRIP" ] || NETWORK_STRIP=
[ -e "$MICLOUD_LOG" ] || MICLOUD_LOG=
move_files="$LOG_TMP_FILE_PATH $IPTABLES_SAVE $TRAFFICD_LOG $PLUGIN_LOG $NETWORK_STRIP $WIRELESS_STRIP $MICLOUD_LOG"
[ -e "$DHCP_LEASE" ] || DHCP_LEASE=
[ -e "$DNSMASQ_CONF" ] || DNSMASQ_CONF=
[ -e "$MACFILTER_FILE_PATH" ] || MACFILTER_FILE_PATH=
[ -e "$CRONTAB" ] || CRONTAB=
[ -e "$QOS_CONF" ] || QOS_CONF=
[ -e "$WIFISHARE_CONF" ] || WIFISHARE_CONF=
dup_files="$DHCP_LEASE $DNSMASQ_CONF $MACFILTER_FILE_PATH $CRONTAB $QOS_CONF $WIFISHARE_CONF"

[ -e "$LOGREAD_FILE_PATH" ] || LOGREAD_FILE_PATH=
[ -e "$LOGREAD0_FILE_PATH" ] || LOGREAD0_FILE_PATH=
[ -e "$PANIC_FILE_PATH" ] || PANIC_FILE_PATH=
[ -e "$LOG_WIFI_AYALYSIS" ] || LOG_WIFI_AYALYSIS=
[ -e "$LOG_WIFI_AYALYSIS0" ] || LOG_WIFI_AYALYSIS0=
[ -e "$GZ_LOGS" ] || GZ_LOGS=
[ -e "$LOG_DIR" ] || LOG_DIR=
[ -e "$TMP_WIFI_LOG" ] || TMP_WIFI_LOG=
if [ "$redundancy_mode" = "1" ]; then
    redundancy_files="$LOGREAD_FILE_PATH $LOGREAD0_FILE_PATH $PANIC_FILE_PATH $LOG_WIFI_AYALYSIS $LOG_WIFI_AYALYSIS0 $GZ_LOGS"
else
    redundancy_files="$LOG_DIR $PANIC_FILE_PATH $TMP_WIFI_LOG"
fi
tar -zcf $LOG_ZIP_FILE_PATH $move_files $dup_files $redundancy_files
rm "$move_files" > /dev/null
