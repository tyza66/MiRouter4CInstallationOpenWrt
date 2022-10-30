#!/bin/sh
####################################################################################
#/etc/config/proxy example
#
#config remote "proxy"
#	option enabled "0"
#      	option status "off"
#       option type proxy
#       option domain_file /etc/proxy/proxy.txt
#       option local_port  10080
#       option local_dns_port  10080
#       option remote_ip   54.85.90.122
. /lib/functions.sh
. /lib/functions/network.sh

ipset_name="smartproxy"
ipset_ip_name="smartproxy_ip"
ipset_mark="0x11"

_local_port=1080
proxy_cfg_remoteip="0.0.0.0"

dnsmasq_conf_path="/etc/dnsmasq.d/"
proxy_conf_path="/etc/smartvpn/"
smartproxy_dns_conf_name="smartproxy.conf"
smartproxy_dns_conf="$proxy_conf_path/$smartproxy_dns_conf_name"

rule_file_ip="$proxy_conf_path/smartproxy_ip.txt"

smartvpn_section_name=proxy


proxy_logger()
{
    echo "proxy: $1"
    logger -t smartproxy "$1"
}

proxy_usage()
{
    echo "usage: ./proxy.sh on|off"
    echo "value: on  -- enable proxy"
    echo "value: off -- disable proxy"
    echo "note:  proxy only used when proxy is UP!"
    echo ""
}

dnsmasq_restart()
{
    process_pid=$(ps | grep "/usr/sbin/dnsmasq -C /var/etc/dnsmasq.conf" |grep -v "grep /usr/sbin/dnsmasq -C /var/etc/dnsmasq.conf" | awk '{print $1}' 2>/dev/null)
    process_num=$( echo $process_pid |awk '{print NF}' 2>/dev/null)
    process_pid1=$( echo $process_pid |awk '{ print $1; exit;}' 2>/dev/null)
    process_pid2=$( echo $process_pid |awk '{ print $2; exit;}' 2>/dev/null)

    [ "$process_num" != "2" ] && /etc/init.d/dnsmasq restart

    retry_times=0
    while [ $retry_times -le 3 ]
    do
        let retry_times+=1
        /etc/init.d/dnsmasq restart
        sleep 1

        process_newpid=$(ps | grep "/usr/sbin/dnsmasq -C /var/etc/dnsmasq.conf" |grep -v "grep /usr/sbin/dnsmasq -C /var/etc/dnsmasq.conf" | awk '{print $1}' 2>/dev/null)
        process_newnum=$( echo $process_newpid |awk '{print NF}' 2>/dev/null)
        process_newpid1=$( echo $process_newpid |awk '{ print $1; exit;}' 2>/dev/null)
        process_newpid2=$( echo $process_newpid |awk '{ print $2; exit;}' 2>/dev/null)

        proxy_logger "process_newpid $process_newpid"
        proxy_logger "old: $process_pid1 $process_pid2"
        proxy_logger "new: $process_newpid1 $process_newpid2"

        [ "$process_pid1" == "$process_newpid1" ] && continue;
        [ "$process_pid1" == "$process_newpid2" ] && continue;
        [ "$process_pid2" == "$process_newpid1" ] && continue;
        [ "$process_pid2" == "$process_newpid2" ] && continue;

        break
    done
}

proxy_dns_start()
{
    # move dnsmasq conf
    if [ -f $smartproxy_dns_conf ]; then
        mv $smartproxy_dns_conf $dnsmasq_conf_path
    fi

    # flush dnsmasq
    dnsmasq_restart

    return
}

proxy_dns_stop()
{
    # del proxy dnsmasq conf
    rm "$dnsmasq_conf_path/$smartproxy_dns_conf_name"
    rm "/var/etc/dnsmasq.d/$smartproxy_dns_conf_name"
    rm "/tmp/etc/dnsmasq.d/$smartproxy_dns_conf_name"

    # flush dnsmasq
    dnsmasq_restart

    return
}

proxy_ipset_create()
{
    ipset list | grep $ipset_name  > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        ipset create $ipset_name  hash:ip > /dev/null 2>&1
        ipset create $ipset_ip_name hash:net > /dev/null 2>&1
    fi
}

proxy_ipset_add_by_file()
{
    local _ipfile=$1

    [ -f $_ipfile ] || return

    ipset create $ipset_ip_name hash:net > /dev/null 2>&1

    cat $_ipfile | while read line
    do
        ipset add $ipset_ip_name $line
    done

}

proxy_ipset_delete()
{
    ipset flush $ipset_name
    ipset flush $ipset_ip_name

    ipset destroy $ipset_name # maybe failed, but doesn't matter
    ipset destroy $ipset_ip_name # maybe failed, but doesn't matter

    return
}

proxy_firewall_reload_add()
{
uci -q batch <<-EOF >/dev/null
    set firewall.proxy=include
    set firewall.proxy.path="/lib/firewall.sysapi.loader smartproxy"
    set firewall.proxy.reload=1
    commit firewall
EOF
    return 0
}

proxy_firewall_reload_delete()
{
uci -q batch <<-EOF >/dev/null
    delete firewall.proxy
    commit firewall
EOF
    return 0
}

proxy_device_table="proxy_device"
proxy_mark_table="proxy_mark"

# $1 smart redirect ipset name
# $2 reomte proxy server ip
# $3 local  proxy listen port
proxy_proxy_mark_redirect_open()
{
    allowmacs="$(uci get proxy.device.mac 2>/dev/null)"


    iptables -t nat -F $proxy_device_table 2>/dev/null
    iptables -t nat -X $proxy_device_table 2>/dev/null
    iptables -t nat -N $proxy_device_table 2>/dev/null

    iptables -t nat -F $proxy_mark_table 2>/dev/null
    iptables -t nat -X $proxy_mark_table 2>/dev/null
    iptables -t nat -N $proxy_mark_table 2>/dev/null

    #which dest not transfer through VPN
    if [ "$_notnets" != "" ]
    then
        for notnet in $_notnets
        do
            iptables -t nat -A $proxy_device_table  -d $notnet -j ACCEPT
        done
    fi


    #allowmacs not NULL
    if [ "$allowmacs" != "" ]
    then
        for mac in $allowmacs
        do
            iptables -t nat -A $proxy_device_table  -m mac --mac-source $mac -j RETURN
        done
        iptables -t nat -A $proxy_device_table -j ACCEPT
    else
        iptables -t nat -A $proxy_device_table -j RETURN
    fi

    #dns mark not NULL
    if [ ! -f "$dnsmasq_conf_path/$smartproxy_dns_conf_name" ]
    then
        iptables -t nat -A $proxy_mark_table -p tcp -j REDIRECT --to-ports $_local_port
    else
        iptables -t nat -A $proxy_mark_table -m set --match-set $ipset_name  dst -p tcp -j REDIRECT --to-ports $_local_port
        iptables -t nat -A $proxy_mark_table -m set --match-set $ipset_ip_name  dst -p tcp -j REDIRECT --to-ports $_local_port
    fi

    iptables -t nat -A PREROUTING -j $proxy_device_table
    iptables -t nat -A PREROUTING -j $proxy_mark_table

}

# $1 smart redirect ipset name
proxy_proxy_mark_redirect_close()
{
    iptables -t nat -D PREROUTING -j $proxy_device_table 2>/dev/null
    iptables -t nat -D PREROUTING -j $proxy_mark_table 2>/dev/null

    iptables -t nat -F $proxy_device_table 2>/dev/null
    iptables -t nat -X $proxy_device_table 2>/dev/null

    iptables -t nat -F $proxy_mark_table 2>/dev/null
    iptables -t nat -X $proxy_mark_table 2>/dev/null

}

proxy_set_off()
{
    uci set smartvpn.proxy.status=off
    uci commit smartvpn
}

proxy_set_on()
{
    uci set smartvpn.proxy.status=on
    uci commit smartvpn
}

proxy_config_load()
{
    config_load "smartvpn"
    config_get _local_port      $smartvpn_section_name local_port
    config_get _local_dns_port  $smartvpn_section_name local_dns_port
    config_get _remote_ip       $smartvpn_section_name remote_ip
    config_get _type            $smartvpn_section_name type
    config_get _domain_file     $smartvpn_section_name domain_file
    config_get _domain_disabled $smartvpn_section_name domain_disabled
    config_get _mac             $smartvpn_section_name mac
    config_get _mac_disabled    $smartvpn_section_name mac_disabled
    config_get _status          $smartvpn_section_name status
    config_get _disabled        $smartvpn_section_name disabled
    config_get _notnets         dest notnet
    return
}

proxy_start()
{

    [ -f $_domain_file ] && {
        [ $_local_dns_port != "0" ] && gensmartdns.sh  $_domain_file $smartproxy_dns_conf $rule_file_ip $ipset_name 127.0.0.1#$_local_dns_port
        [ $_local_dns_port == "0" ] && gensmartdns.sh  $_domain_file $smartproxy_dns_conf $rule_file_ip $ipset_name
    }

    [ "$proxy_cfg_devicedisabled" == "1" ] && proxy_cfg_devicemac=""

    [ ! -f "$smartproxy_dns_conf" -a "$proxy_cfg_devicemac" == "" ] && {
        proxy_logger "smartdns config $smartproxy_dns_conf doesn't exist or device list $proxy_cfg_devicemac equel NULL, return!"
        return 1
    }

    ### enable proxy
    proxy_ipset_create

    [ -f $rule_file_ip ] && {
        proxy_ipset_add_by_file $rule_file_ip
        rm $rule_file_ip
    }

    proxy_dns_start

    proxy_proxy_mark_redirect_open

    proxy_firewall_reload_add

    proxy_logger "status set on."
    proxy_set_on

    proxy_logger "proxy enabled!"

    return
}

proxy_stop()
{
    proxy_firewall_reload_delete

    proxy_proxy_mark_redirect_close

    proxy_dns_stop

    proxy_ipset_delete

    proxy_logger "status set off."
    proxy_set_off

    proxy_logger "proxy disabled!"

    return
}

proxy_flush()
{

    if [ $_disabled -ne 0 ]
    then
        proxy_logger "proxy not enabled."
        return 1
    fi

    if [  $_type != "proxy" ]
    then
        proxy_logger "proxy not in vpn."
        return 1
    fi

    if [ $_status != "on" ];
    then
        proxy_logger "proxy not run."
        return 1
    fi

    proxy_proxy_mark_redirect_close

    proxy_proxy_mark_redirect_open

    return
}


usage()
{
    echo "usage: $0 open|close"
    echo "    open : $0 open proxy_port dns_proxy_port remote_ip [domain_file]"
    echo "           set third party proxy config."
    echo "           proxy_port: the local port we sent traffic to. 0 means don't need this config."
    echo "           dns_proxy_port: the local por