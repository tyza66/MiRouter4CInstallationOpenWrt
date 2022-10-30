#/bin/sh
del_ip(){         
        del_ip=$1                       
        ip_addr_str_all=$(ip addr | grep $del_ip)
        echo $ip_addr_str_all   
        ip_str=${ip_addr_str_all#*inet }
        ip_str=${ip_str%scope*}   
        ifname=${ip_addr_str_all#*global }
        echo $ifname
        echo $ip_str           
        ip addr del $ip_str dev $ifname
}

del_ip 169.254.31.1
del_ip 169.254.31.2


[ -z "$1" ] && echo "Error: dhcpc_do_opt43_act.sh IFNAME" && exit 105

#clean /tmp/replace_router
echo > /tmp/replace_router 2> /dev/NULL

#test ip
 
ip address | grep 169.254.31../30 2> /dev/NULL > /dev/NULL
if [ $? == 0 ]; then
	ip address | grep 169.254.31.2/30 2>/dev/NULL > /dev/NULL
	if [ $? == 0 ]; then
		echo "have 169.254.31.2/30 ip"
		ip address | grep 169.254.31.2/30 | grep $1 2>/dev/NULL > /dev/NULL
		if [ $? != 0 ]; then
			echo "have 169.254.31.2 ip ,but not in $1"
			return 105
		else
			echo "have 169.254.31.2 ip ,and on the $1"
		fi
	else
		echo "have net 169.254.31.0/30 net,but not 169.254.31.2"
		return 106
	fi
else
	echo "set ip"
	ip addr add 169.254.31.2/30 dev $1
	if [ $? != 0 ]; then
		return 107
	fi
fi

#if [ $? != 0 ]; then
#       echo "set self ip 169.254.31.2 error"
#       exit 105
#fi
if [ -n "$2" -a "$2" == "set_ip_with_mac" ]; then 
	udhcpc -i $1 -n -x 0x2b:6332563058326c775832316859776f3d -s /lib/netifd/dhcp.script
else
	udhcpc -i $1 -n -x 0x2b:636d56776247466a5a563979623356305a58494b -s /lib/netifd/dhcp.script
fi
if [ $? != 0 ] ; then
        echo "udhcpc send discover error"
        ping 169.254.31.1 -c 1
        if [ $? == 0 ]; then
		#sucess write file 
		echo "uchcp set ip success ,write file"
		echo "self_ip=169.254.31.2" > /tmp/replace_router
		echo "self_ifname=$1" >> /tmp/replace_router
		echo "peer_ip=169.254.31.1" >> /tmp/replace_router
		echo "peer_ifname=br-lan" >> /tmp/replace_router
        	return 0
        else
        	return 103
        fi
fi
ret=$(cat /tmp/dhcp_opt43_act_tmp)
echo ret=$ret
if [ -n "$ret" ]; then
	if [ $ret == 0 ]; then
		#sucess write file 
		echo "uchcp set ip success ,write file"
		echo "self_ip=169.254.31.2" > /tmp/replace_router
		echo "self_ifname=$1" >> /tmp/replace_router
		echo "peer_ip=169.254.31.1" >> /tmp/replace_router
		echo "peer_ifname=br-lan" >> /tmp/replace_router
	fi
        exit $ret
fi
exit 104

