#!/bin/ash
del_ip(){         
        del_ip=$1                       
        ip_addr_str_all=$(ip addr | grep $del_ip)
#        echo $ip_addr_str_all   
        ip_str=${ip_addr_str_all#*inet }
        ip_str=${ip_str%scope*}   
        ifname=${ip_addr_str_all#*global }
#        echo $ifname
#        echo $ip_str           
        ip addr del $ip_str dev $ifname
}

act_base64=$1

if [ $act_base64 == "cmVwbGFjZV9yb3V0ZXIK" ]; then
        act="replace_router"
elif [ $act_base64 == "c2V0X2lwX21hYwo=" ];then
        act="set_ip_mac"
else
        return 101
fi

del_ip 169.254.31.1
del_ip 169.254.31.2

case "$act" in
	replace_router)
		#test and set ip 
		ip address | grep 169.254.31../30 2> /dev/NULL > /dev/NULL
		if [ $? == 0 ]; then
			ip address | grep 169.254.31.1/30 2>/dev/NULL > /dev/NULL
		if [ $? == 0 ]; then
			ip address | grep 169.254.31.1/30 | grep br-lan 2>/dev/NULL > /dev/NULL
				if [ $? != 0 ]; then
					return 115
				else
					return 0
				fi
			else
				return 116
			fi
		else
			ip addr add 169.254.31.1/30 dev br-lan
			exit $?
		fi
		;;
	set_ip_mac)
		#test and set ip 
		ip address | grep 169.254.31../30 2> /dev/NULL > /dev/NULL
		if [ $? == 0 ]; then
			ip address | grep 169.254.31.1/30 2>/dev/NULL > /dev/NULL
		if [ $? == 0 ]; then
			ip address | grep 169.254.31.1/30 | grep br-lan 2>/dev/NULL > /dev/NULL
				if [ $? != 0 ]; then
					return 115
				else
					ifconfig br-lan 169.254.31.1 netmask 255.255.255.252
					prepare_sync.sh $2
					return 0
				fi
			else
				return 116
			fi
		else
			ifconfig br-lan 169.254.31.1 netmask 255.255.255.252
			#ip addr add 169.254.31.1/30 dev br-lan
			ret=$?
			prepare_sync.sh $2
			return ret
		fi
		;;

	*)
		return 102
		;;
esac
exit 102
