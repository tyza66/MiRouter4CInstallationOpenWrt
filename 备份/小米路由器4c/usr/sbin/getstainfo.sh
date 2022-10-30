LOGGER="/usr/bin/logger"
IWINFO="/usr/bin/iwinfo"
IWPRIV="/usr/sbin/iwpriv"

LOG_STR="wifi_log: "

#wificount=`cat /etc/config/wireless | grep "wifi-device" | wc -l`
wificount=2
subnum=16
stainfo_idx=7

wl_dump_assoclist()
{
	local ifname
	ifname=$1

	ssid="`${IWINFO} ${ifname} assoclist | grep "ssid:" | awk -F " " '{print $2}'`"
	bssid="`${IWINFO} ${ifname} assoclist | grep "bssid:" | awk -F " " '{print $2}'`"
	channel="`${IWINFO} ${ifname} assoclist | grep "channel:" | awk -F " " '{print $2}'`"
	stacount="`${IWINFO} ${ifname} assoclist | grep "stacount:" | awk -F " " '{print $2}'`"
	noise="`${IWINFO} ${ifname} assoclist | grep "noise:" | awk -F " " '{print $2}'`"

	if [ ! ${stacount} -eq 0 ]; then
		
		dump_info="${LOG_STR}Ifname=\"${ifname}\", Noise=\"${noise} dBm\", Stacount=\"${stacount}\", SSID=\"$ssid\", Bssid=\"$bssid\", Channel=\"$channel\""
		echo ${dump_info}
		${LOGGER} ${dump_info}

		for j in `seq ${stacount}`
		do
			i=$(($j + $stainfo_idx))
			sta_mac="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $1}'`"
			sta_phy="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $2}'`"
			sta_security="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $3}'`"
			sta_rssi="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $4}'`"
			sta_noise="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $5}'`"
			sta_snr="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $6}'`"
			sta_rx_rate="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $7" Mbit/s"}'`"
			sta_rx_upkts="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $8" Pkts"}'`"
			sta_rx_ukbyte="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $9" Kbytes"}'`"
			sta_rx_mpkts="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $10" Pkts"}'`"
			sta_rx_mkbyte="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $11" Kbytes"}'`"
			sta_tx_rate="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $12" Mbit/s"}'`"
			sta_tx_upkts="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $13" Pkts"}'`"
			sta_tx_ukbyte="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $14" Kbytes"}'`"
			sta_tx_mpkts="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $15" Pkts"}'`"
			sta_tx_mkbyte="`${IWINFO} ${ifname} assoclist | awk -F " " 'NR=='"${i}"'{print $16" Kbytes"}'`"
			dump_stainfo="${LOG_STR}sta_mac=\"${sta_mac}\", Phy=\"${sta_phy}\", Security=\"${sta_security}\", RSSI=\"${sta_rssi}\", Noise=\"${sta_noise}\",snr=\"${sta_snr}\", RX=\"${sta_rx_rate}\", RX_UCAST_PKT=\"${sta_rx_upkts}\", RX_UCAST_KBYTE=\"${sta_rx_ukbyte}\", RX_MCAST_PKTS=\"${sta_rx_mpkts}, RX_MCAST_KBYTE=\"${sta_rx_mkbyte}\", TX=\"${sta_tx_rate}\", RX_UCAST_PKT=\"${sta_rx_upkts}\", TX_UCAST_KBYTE=\"${sta_tx_ukbyte}\", TX_MCAST_PKTS=\"${sta_tx_mpkts}\", TX_MCAST_KBYTE=\"${sta_tx_mkbyte}\""
			echo $dump_stainfo
			${LOGGER} $dump_stainfo
		done
	fi
}

for n in `seq ${wificount}`
do
        let n=n-1
        ifname="wl$n"

        cat /proc/net/dev | grep -q "wl$n"
        if [ $? -eq 1 ]; then
                continue
        fi
	wl_dump_assoclist "wl$n"
        for sub in `seq $subnum`; do
		cat /proc/net/dev | grep -q "wl$n.$sub"
		if [ $? -eq 1 ]; then
			continue
		fi
		wl_dump_assoclist "wl$n.$sub"
	done
done
