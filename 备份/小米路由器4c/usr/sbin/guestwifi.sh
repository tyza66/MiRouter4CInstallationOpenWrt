#!/bin/sh
# Copyright (C) 2015 Xiaomi

network_name="guest"
ip_range="192.168.32.1"
netmask="255.255.255.0"

#r1cm
#misc.wireless.guest_2G
#network_ifname="wl2"
#
#network_device="mt7620"

#r1d
#misc.wireless.guest_2G
#network_ifname="wl1.2"
#misc.wireless.if_2G
#network_device="wl1"
#start->on<->off->stop

#plantfrom related.
network_ifname=`uci -q get misc.wireless.guest_2G`
network_device=`uci -q get misc.wireless.if_2G`

guest_usage()
{
    echo "$0:"
    echo "    open: start guest wifi, delete all config"
    echo "         $0  open guest_ssid encryption_type password"
    echo "    close: stop guest wifi, delete all config"
    echo "    enable:  enable guest wifi, need start first"
    echo "    disable: disable guest wifi, need start first"
    echo "    other: usage"
    return;
}

guest_ipnet_make()
{
    local guest_lan=""
    . /lib/functions/network.sh
    network_get_subnet subnet lan

    guest_lan=`echo "$subnet" |awk -F "[./]" '{mask=$5;
        if(mask<16 && $2<254)
        {
            print $1"."$2+1".0.1 255.255.0.0";
        }
        if(mask>=16 && $3<254)
        {
            print $1"."$2"."$3+1".1 255.255.255.0"
        }
        if(mask<16 && $2>=254)
        {
            print $1"."$2-1".0.1 255.255.0.0";
        }
        if(mask>=16 && $3>=254)
        {
            print $1"."$2"."$3-1".1 255.255.255.0"
        }
    }'`

    ip_range=`echo $guest_lan |awk '{print $1}'`
    netmask=`echo $guest_lan |awk '{print $2}'`

    echo "subnet $subnet"
    echo "$guest_lan"
    echo "range $ip_range"
    echo "mask $netmask"
    return;
}

guest_ip_make()
{
    local lan_ip="$(uci get network.lan.ipaddr 2>/dev/NULL)"
    echo "$lan_ip"
    local new_ip="$(lua /usr/sbin/guestwifi_mkip.lua "$lan_ip")"
    echo "lua calc new_ip: $new_ip"

    if [ "$new_ip" != "" ]
    then
        echo "get calc ip $new_ip"
        ip_range=$new_ip
        netmask="255.255.255.0"
    fi

    echo "newip $ip_range"
    echo "netmask $netmask"
    return;
}

guest_add()
{
    local ssid="$1"
    local encryption="$2"  #mixed-psk
    local key="$3"  #12345678

    [ "$2" == "" ] && { encryption="none"; key=""; }
    [ "$1" == "" ] && ssid="xiaomi_guest_2G"

    # use new method calc guest ip, not guest_ipnet_make
    guest_ip_make

#wifi
guest_2G="$(uci get wireless.${network_name}_2G 2>/dev/NULL)"
if [ "$guest_2G" == "" ]
then

    uci -q batch <<-EOF >/dev/null
        set wireless.${network_name}_2G=wifi-iface
        set wireless.${network_name}_2G.ifname="$network_ifname"
        set wireless.${network_name}_2G.network="${network_name}"
        set wireless.${network_name}_2G.encryption="$encryption"
        set wireless.${network_name}_2G.device="${network_device}"
        set wireless.${network_name}_2G.key="$key"
        set wireless.${network_name}_2G.mode=ap
        set wireless.${network_name}_2G.ap_isolate=1
        set wireless.${network_name}_2G.ssid="$ssid"
        set wireless.${network_name}_2G.disabled=0
        commit wireless
EOF

fi

#force ap isolate
uci -q batch <<-EOF >/dev/null
        set wireless.${network_name}_2G.ap_isolate=1
        commit wireless
EOF

#network
guest_network="$(uci get network.${network_name} 2>/dev/NULL)"
if [ "$guest_network" == "" ]
then

    uci -q batch <<-EOF >/dev/null
        set network.${network_name}=interface
        set network.${network_name}.ifname=" "
        set network.${network_name}.type=bridge
        set network.${network_name}.proto=static
        set network.${network_name}.ipaddr=$ip_range
        set network.${network_name}.netmask=$netmask
        commit network
EOF

else

    #clean guestwifi ifname="eth0.3" for history fault
    uci -q batch <<-EOF >/dev/null
        set network.${network_name}.ifname=" "
        commit network
EOF

fi

#dhcp
guest_dhcp="$(uci get dhcp.${network_name} 2>/dev/NULL)"
if [ "$guest_dhcp" == "" ]
then

    uci -q batch <<-EOF >/dev/null
        set dhcp.${network_name}=dhcp
        set dhcp.${network_name}.interface=${network_name}
        set dhcp.${network_name}.start=100
        set dhcp.${network_name}.limit=150
        set dhcp.${network_name}.leasetime=12h
        set dhcp.${network_name}.force=1
        set dhcp.${network_name}.dhcp_option_force="43,XIAOMI_ROUTER"
        commit dhcp
EOF

fi

#firewall
guest_firewall="$(uci get firewall.${network_name}_forward 2>/dev/NULL)"
if [ "$guest_firewall" == "" ]
then

    uci -q batch <<-EOF >/dev/null
        set firewall.${network_name}_forward=forwarding
        set firewall.${network_name}_forward.src=guest
        set firewall.${network_name}_forward.dest=wan

        set firewall.${network_name}_zone=zone
        set firewall.${network_name}_zone.name="${network_name}"
        set firewall.${network_name}_zone.network="${network_name}"
        set firewall.${network_name}_zone.input=REJECT
        set firewall.${network_name}_zone.forward=REJECT
        set firewall.${network_name}_zone.output=ACCEPT

        set firewall.${network_name}_dns=rule
        set firewall.${network_name}_dns.name="Allow Guest DNS Queries"
        set firewall.${network_name}_dns.src=guest
        set firewall.${network_name}_dns.dest_port=53
        set firewall.${network_name}_dns.proto=tcpudp
        set firewall.${network_name}_dns.target=ACCEPT

        set firewall.${network_name}_dhcp=rule
        set firewall.${network_name}_dhcp.name="Allow Guest DHCP request"
        set firewall.${network_name}_dhcp.src=guest
        set firewall.${network_name}_dhcp.src_port=67-68
        set firewall.${network_name}_dhcp.dest_port=67-68
        set firewall.${network_name}_dhcp.proto=udp
        set firewall.${network_name}_dhcp.target=ACCEPT

        commit firewall
EOF

fi

    return
}

guest_delete()
{

uci -q batch <<-EOF >/dev/null
    delete firewall.${network_name}_dhcp
    delete firewall.${network_name}_dns
    delete firewall.${network_name}_zone
    delete firewall.${network_name}_forward

    delete wireless.${network_name}_2G
    delete network.${network_name}
    delete dhcp.${network_name}

    commit firewall
    commit wireless
    commit network
    commit dhcp
EOF

    return 0
}

guest_start()
{
    local ssid="$1"
    local encryption="$2"  #mixed-psk
    local key="$3"  #12345678

    guest_add "$ssid" "$encryption" "$key"

    /etc/init.d/network restart
    /etc/init.d/dnsmasq restart
    /etc/init.d/firewall reload

    return 0
}

guest_stop()
{
    guest_delete

    /etc/init.d/network restart
    /etc/init.d/dnsmasq restart
    /etc/init.d/firewall reload

    return 0
}

OPT=$1

[ "$network_ifname" == "" ] && exit 1

[ "$network_device" == "" ] && exit 1

#main
case $OPT in
    open)
        guest_start "$2" "$3" "$4"
        return $?
    ;;

    close)
        guest_stop
        return $?
    ;;

    * )
        guest_usage
        return 0
    ;;
esac



