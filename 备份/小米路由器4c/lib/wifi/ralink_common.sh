# this file will be included in
# 	/lib/wifi/mt{chipname}.sh

sync_uci_with_dat() {
	local device="$1" logfile
	local datpath="$2"
	local CountryCode

	if [ $device == "mt7628" -o $device == "mt7603e" -o $device == "mt7620" -o $device == "mt7615e2" ]; then
		logfile='/tmp/mt76xx2.sh.log'
	else
		logfile='/tmp/mt76xx5.sh.log'
	fi
	echo "sync_uci_with_dat($1,$2,$3,$4)" >> $logfile

        CountryCode=`nvram get CountryCode`

        if [ $CountryCode ]; then
                uci set wireless.$device.country=$CountryCode
                uci commit wireless
        else
                uci set wireless.$device.country=CN
                uci commit wireless
        fi

#	if [  "$CountryCode" = "TW" ]; then
#		uci set wireless.$device.country=TW
#		uci set wireless.$device.region=0
#		uci set wireless.$device.aregion=19
#		uci commit
#	elif [  "$CountryCode" = "HK" ]; then
#		uci set wireless.$device.country=HK
#		uci set wireless.$device.region=1
#		uci set wireless.$device.aregion=0
#		uci commit
#	elif [  "$CountryCode" = "US" ]; then
#		uci set wireless.$device.country=US
#		uci set wireless.$device.region=0
#		uci set wireless.$device.aregion=0
#		uci commit
#	else
#		uci set wireless.$device.country=CN
#		uci set wireless.$device.region=1
#		uci set wireless.$device.aregion=0
#		uci commit
#	fi

	uci2dat -d $device -f $datpath > /tmp/uci2dat_$device.log
}



# $1=device, $2=module
reinit_wifi() {
	local device="$1" logfile
	local module="$2"

	if [ $device == "mt7628" -o $device == "mt7603e" -o $device == "mt7620" -o $device == "mt7615e2" ]; then
		logfile='/tmp/mt76xx2.sh.log'
	else
		logfile='/tmp/mt76xx5.sh.log'
	fi
	echo "reinit_wifi($1,$2,$3,$4)" >> $logfile

	config_get vifs "$device" vifs
	for vif in $vifs; do
		config_get ifname $vif ifname
		ifconfig $ifname down
	done

	# some changes will lead to reinstall driver. (mbssid eg)
	echo "rmmod $module" >>/dev/null
	rmmod $module
	echo "insmod $module" >> $logfile
	insmod $module
	for vif in $vifs; do
		config_get ifname $vif ifname
		config_get disabled $vif disabled
		if [ "$disabled" == "1" ]; then
			continue
		else
			ifconfig $ifname up
		fi
	done
}

prepare_ralink_wifi() {
	local device=$1 logfile

	if [ $device == "mt7628" -o $device == "mt7603e" -o $device == "mt7620" -o $device == "mt7615e2" ]; then
		logfile='/tmp/mt76xx2.sh.log'
	else
		logfile='/tmp/mt76xx5.sh.log'
	fi
	echo "prepare_ralink_wifi($1,$2,$3,$4)" >> $logfile

	config_get channel $device channel
	config_get ssid $2 ssid
	config_get mode $device mode
	config_get ht $device ht
	config_get country $device country
	config_get regdom $device regdom

	# HT40 mode can be enabled only in bgn (mode = 9), gn (mode = 7)
	# or n (mode = 6).
	HT=0
	[ "$mode" = 6 -o "$mode" = 7 -o "$mode" = 9 ] && [ "$ht" != "20" ] && HT=1

	# In HT40 mode, a second channel is used. If EXTCHA=0, the extra
	# channel is $channel + 4. If EXTCHA=1, the extra channel is
	# $channel - 4. If the channel is fixed to 1-4, we'll have to
	# use + 4, otherwise we can just use - 4.
	EXTCHA=0
	[ "$channel" != auto ] && [ "$channel" -lt "5" ] && EXTCHA=1

}

wifi_service_stop() {
	killall acsc 2>/dev/null
}

scan_ralink_wifi() {
	local device="$1" logfile
	local module="$2"
	if [ $device == "mt7628" -o $device == "mt7603e" -o $device == "mt7620" -o $device == "mt7615e2" ]; then
		logfile='/tmp/mt76xx2.sh.log'
		echo "2.4G" > $logfile
	else
		logfile='/tmp/mt76xx5.sh.log'
		echo "5G" > $logfile
	fi
	echo "scan_ralink_wifi($1,$2,$3,$4)" >> $logfile
	sync_uci_with_dat $device /etc/Wireless/$device/$device.dat
}

disable_ralink_wifi() {
	local device="$1" logfile
	if [ $device == "mt7628" -o $device == "mt7603e" -o $device == "mt7620" -o $device == "mt7615e2" ]; then
		logfile='/tmp/mt76xx2.sh.log'
	else
		logfile='/tmp/mt76xx5.sh.log'
	fi
	echo "disable_ralink_wifi($1,$2,$3,$4)" >> $logfile
	set_wifi_down "$device"
	config_get vifs "$device" vifs
	for vif in $vifs; do
		config_get ifname $vif ifname
		ifconfig $ifname down
	done
	echo "disable_ralink_wifi($1,$2,$3,$4) done" >> $logfile
}

enable_ralink_wifi() {
	local device="$1" dmode channel radio logfile
	local module="$2"

	if [ $device == "mt7628" -o $device == "mt7603e" -o $device == "mt7620" -o $device == "mt7615e2" ]; then
		logfile='/tmp/mt76xx2.sh.log'
	else
		logfile='/tmp/mt76xx5.sh.log'
	fi
	echo "enable_ralink_wifi($1,$2,$3,$4)" >> $logfile

	echo 3 > /proc/sys/vm/drop_caches
	#reinit_wifi $device $module
	config_get dmode $device mode
	config_get channel $device channel
	config_get radio $device radio
	config_get vifs "$device" vifs
	config_get disabled "$device" disabled
	config_get country $device country
	if [ -f /lib/wifi/singlesku/"$country"_SingleSKU.dat ];then
        if [ -f /etc/Wireless/"$device"/SingleSKU.dat ];then
            rm /etc/Wireless/"$device"/SingleSKU.dat
        fi
		cp /lib/wifi/singlesku/"$country"_SingleSKU.dat /etc/Wireless/"$device"/SingleSKU.dat
	else
		cp /lib/wifi/singlesku/CN_SingleSKU.dat /etc/Wireless/"$device"/SingleSKU.dat
	fi
	[ "$disabled" == "1" ] && return
	for vif in $vifs; do
		local ifname encryption key ssid mode hidden enctype
		config_get ifname $vif ifname
		# [ "$radio" != "" ] && iwpriv $ifname set RadioOn=$radio
		config_get encryption $vif encryption
		config_get key $vif key
		config_get ssid $vif ssid
#		config_get wpa_crypto $vif wpa_crypto
		config_get hidden $vif hidden
		config_get mode $vif mode
		config_get wps $vif wps
		# config_get isolate $vif isolate
		config_get disabled $vif disabled
		if [ "$disabled" == "1" ]; then
			continue
		else
			set_wifi_up "$vif" "$ifname"
			ifconfig $ifname up
                        [ "$radio" != "" ] && iwpriv $ifname set RadioOn=$radio
		fi

		# Skip this interface if no SSID was configured
		[ "$ssid" -a "$ssid" != "off" ] || continue

        if [ "$ssid" == "miwifi_ready" ]; then
            ready_ifname="$ifname"
        fi

		[ "$mode" == "sta" ] && {
			config_get enctype $vif enctype
			case "$encryption" in
				NONE|none)
					iwpriv $ifname set Channel=$channel
					iwpriv $ifname set ApCliEnable=0
					iwpriv $ifname set ApCliAuthMode=OPEN
					iwpriv $ifname set ApCliEncrypType=NONE
					iwpriv $ifname set ApCliSsid="$ssid"
					iwpriv $ifname set ApCliAutoConnect=1
					;;
				WEP|wep)
					iwpriv $ifname set Channel=$channel
					iwpriv $ifname set ApCliEnable=0
					iwpriv $ifname set ApCliAuthMode=OPEN
					iwpriv $ifname set ApCliEncrypType=WEP
					iwpriv $ifname set ApCliDefaultKeyID=1
					iwpriv $ifname set ApCliKey1="$key"
					iwpriv $ifname set ApCliSsid="$ssid"
					iwpriv $ifname set ApCliAutoConnect=1
					;;
				SHARED|shared)
					iwpriv $ifname set Channel=$channel
					iwpriv $ifname set ApCliEnable=0
					iwpriv $ifname set ApCliAuthMode=SHARED
					iwpriv $ifname set ApCliEncrypType=WEP
					iwpriv $ifname set ApCliDefaultKeyID=1
					iwpriv $ifname set ApCliKey1="$key"
					iwpriv $ifname set ApCliSsid="$ssid"
					iwpriv $ifname set ApCliAutoConnect=1
					;;
				WPAPSK|wpa-psk)
					iwpriv $ifname set Channel=$channel
					iwpriv $ifname set ApCliEnable=0
					iwpriv $ifname set ApCliAuthMode=WPAPSK
					if [ -z "$enctype" ]; then
						enctype="TKIP"
					fi
					iwpriv $ifname set ApCliEncrypType=$enctype
					iwpriv $ifname set ApCliSsid="$ssid"
					iwpriv $ifname set ApCliWPAPSK="$key"
					iwpriv $ifname set ApCliAutoConnect=1
					;;
				WPA2PSK|wpa2-psk|mixed-psk)
					iwpriv $ifname set Channel=$channel
					echo "AP Client configure" >> $logfile
					iwpriv $ifname set ApCliEnable=0
					echo "iwpriv $ifname set ApCliEnable=0" >> $logfile
					iwpriv $ifname set ApCliAuthMode=WPA2PSK
					echo "iwpriv $ifname set ApCliAuthMode=WPA2PSK" >> $logfile
					if [ -z "$enctype" ]; then
						enctype="AES"
					fi
					iwpriv $ifname set ApCliEncrypType=$enctype
					echo "iwpriv $ifname set ApCliEncrypType=$enctype" >> $logfile
					iwpriv $ifname set ApCliSsid="$ssid"
					echo "iwpriv $ifname set ApCliSsid=\"$ssid\"" >> $logfile
					iwpriv $ifname set ApCliWPAPSK="$key"
					echo "iwpriv $ifname set ApCliWPAPSK=\"$key\"" >> $logfile
					iwpriv $ifname set ApCliAutoConnect=1
					echo "iwpriv $ifname set ApCliAutoConnect=1" >> $logfile
					echo "AP Client configure done" >> $logfile
					;;
			esac

		}
		[ "$mode" == "sta" ] || {
			[ "$dmode" == "6" ] && wpa_crypto="aes"
			ifconfig $ifname up
			case "$encryption" in
				psk*|wpa*|WPA*|*Mixed*|*mixed*)
					local enc="OPEN"
					local crypto="NONE"
					case "$encryption" in
					    *mixed*|*Mixed*) enc=WPAPSKWPA2PSK crypto=TKIPAES;;
					    psk2*|WPA2*|wpa2*) enc=WPA2PSK crypto=AES;;
					    psk*|WPA*|WPA1*|wpa*|wpa1*) enc=WPAPSK crypto=TKIPAES;;
					esac
					case "$encryption" in
					    *tkip+ccmp) crypto=TKIPAES;;
					    *tkip) crypto=TKIP;;
					    *ccmp) crypto=AES;;
					esac
					iwpriv $ifname set AuthMode=$enc
					iwpriv $ifname set EncrypType=$crypto
					iwpriv $ifname set IEEE8021X=0
					iwpriv $ifname set "WPAPSK=${key}"
#					iwpriv $ifname set DefaultKeyID=2
					iwpriv $ifname set "SSID=${ssid}"
#					if [ "$wps" == "1" ]; then
#						iwpriv $ifname set WscConfMode=7
#					else
#						iwpriv $ifname set WscConfMode=0
#					fi
					;;
				WEP*|wep*)
					local enc="OPEN"
					local crypto="WEP"
					case "$encryption" in
					    *open) enc=OPEN;;
					    *shared) enc=SHARED;;
					esac
					iwpriv $ifname set AuthMode=$enc
					iwpriv $ifname set EncrypType=$crypto
					[ -n "$key" ] && iwpriv $ifname set "Key1=${key}"
					iwpriv $ifname set DefaultKeyID=1
					iwpriv $ifname set "SSID=${ssid}"
					#iwpriv $ifname set WscConfMode=0
					iwpriv $ifname set WscModeOption=0
					;;
				none|open)
					iwpriv $ifname set AuthMode=OPEN
					iwpriv $ifname set EncrypType=NONE
					#iwpriv $ifname set WscConfMode=0
					;;
			esac
		}

		local net_cfg bridge
		net_cfg="$(find_net_config "$vif")"
		[ -z "$net_cfg" ] || {
			bridge="$(bridge_interface "$net_cfg")"
			config_set "$vif" bridge "$bridge"
			start_net "$ifname" "$net_cfg"
		}

		# If isolation is requested, disable forwarding between
		# wireless clients (both within the same BSSID and
		# between BSSID's, though the latter is probably not
		# relevant for our setup).
		# iwpriv $ifname set NoForwarding="${isolate:-0}"
		# iwpriv $ifname set NoForwardingBTNBSSID="${isolate:-0}"
	done

    apmode=`uci get xiaoqiang.common.NETMODE 2> /dev/null`

    echo "ap $apmode mi $ready_ifname" >> $logfile
    if [ "$apmode" == "wifiapmode" -o "$apmode" == "lanapmode" ]; then
        echo "ifconfig $ready_ifname down" >> $logfile
        ifconfig $ready_ifname down
    fi

    if [ "$device" == "mt7628" -o "$device" == "mt7620" ]; then
        acsc > /dev/null
    fi
	echo "enable_ralink_wifi($1,$2,$3,$4) done" >> $logfile
}

detect_ralink_wifi() {
	local channel ssid
	local device="$1" logfile
	local module="$2"
	local ifname
    local CountryCode

	if [ $device == "mt7628" -o $device == "mt7603e" -o $device == "mt7620" -o $device == "mt7615e2" ]; then
		logfile='/tmp/mt76xx2.sh.log'
	else
		logfile='/tmp/mt76xx5.sh.log'
	fi
	echo "detect_ralink_wifi($1,$2,$3,$4)" >> $logfile

    CountryCode=`bdata get CountryCode`
    if [ !$CountryCode ]; then
        CountryCode="CN"
    fi

	cd /sys/module/
	[ -d $module ] || return
	config_get channel $device channel
	[ -z "$channel" ] || return
	case "$device" in
		mt7628 | mt7602 | mt7620 )
			ifname="wl1"
			ssid=`nvram get wl1_ssid`
			hwband="2_4G"
			hwmode="11ng"
			;;
		mt7610e | mt7612 )
			ifname="wl0"
			ssid=`nvram get wl0_ssid`
			hwband="5G"
			hwmode="11ac"
			;;
		* )
			echo "device $device not recognized!! " >> $logfile
			;;
	esac
	cat <<EOF
config wifi-device	'$device'
	option type     '$device'
	option vendor   'ralink'
	option channel  '0'
	option bw 	'0'
	option autoch   '2'
	option radio    '1'
	option txpwr	'max'
	option hwband   '$hwband'
	option hwmode   '$hwmode'
	option disabled '0'
	option country '$CountryCode'
	option region '1'
	option aregion '0'

config wifi-iface
	option device   '$device'
	option ifname	'$ifname'
	option network  'lan'
	option mode     'ap'
	option ssid 	'$ssid'
	option encryption 'none'

EOF
	if [ "$device" = "mt7628" ]; then
		cat <<EOF
config wifi-iface 'miwifi_ready'
        option disabled '0'
        option device 'mt7628'
        option ifname 'wl2'
        option network  'ready'
        option mode 'ap'
        option ssid 'miwifi_ready'
        option hidden '1'
        option encryption 'none'
        option dynbcn '1'

EOF
	fi
    if [ "$device" = "mt7628" ]; then
        cat <<EOF
config wifi-iface 'guest_2G'
        option disabled '1'
        option device 'mt7628'
        option ifname 'wl3'
        option network 'guest'
        option mode 'ap'

EOF
        fi
}
