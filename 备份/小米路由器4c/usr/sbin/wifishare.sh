#!/bin/sh
# Copyright (C) 2016 Xiaomi
. /lib/functions.sh

network_name="guest"
section_name="wifishare"
redirect_port="8999"
dev_redirect_port="8899"
whiteport_list="67 68"
http_port="80"
dns_port="53"
dnsd_port="5533"
dnsd_conf="/var/dnsd.conf"
guest_gw=$(uci get network.guest.ipaddr 2>/dev/null)
fw3lock="/var/run/fw3.lock"

hasctf=$(uci get misc.quickpass.ctf 2>/dev/null)
guest_ifname=$(uci get wireless.guest_2G.ifname 2>/dev/null)
hashwnat=$([ -f /etc/init.d/hwnat ] && echo 1)
auth_timeout_default=90
timeout_default=86400
date_tag=$(date +%F" "%H:%M:%S)
macs_blocked=""

share_block_table="wifishare_block"
share_block_table_input="wifishare_block_input"

share_whitehost_ipset="wifishare_whitehost"
share_whitehost_file="/etc/dnsmasq.d/wifishare_whitehost.conf"

domain_white_list_file="/var/etc/dnsmasq.d/wifishare_domain_list.conf"
ios_white_list_file="/var/etc/dnsmasq.d/wifishare_ios_list.conf"
share_domain_ipset="wifishare_domain_list"
share_ios_ipset="wifishare_ios_list"

share_nat_table="wifishare_nat"
share_filter_table="wifishare_filter"
share_nat_device_table="wifishare_nat_device"
share_filter_device_table="wifishare_filter_device"
share_nat_dev_redirect_table="wifishare_nat_dev_redirect"

hosts_dianping=".dianping.com .dpfile.com"
hosts_apple=""
hosts_nuomi=""
hosts_index="dianping"
filepath=$(cd `dirname $0`; pwd)
filename=$(basename $0;)

daemonfile="/usr/sbin/wifishare_daemon.sh"

active="user business"
#wechat qq dianping nuomi .etc
active_type=""

WIFIRENT_NAME="wifirent"
COUNT_INTERVAL_SECS=300 #1 minites
WFSV2_flag="unchanged"
should_update_flag="false"
guest_miwifi_address="guest.miwifi.com"
guest_miwifi_dnsmasq_conf="/var/etc/dnsmasq.d/guest_miwifi_dnsmasq.conf"
index_cdn_addr="http://bigota.miwifi.com/xiaoqiang/webpage/wifishare/index.html"
html_path="/etc/sysapihttpd/htdocs"
html_name="wifishare.html"

# generate random number between min & max
rand(){
    min=$1
    max=`expr $2 - $min + 1`
    rnd_num=`head -50 /dev/urandom | tr -dc "0123456789" | head -c6`
    echo `expr $rnd_num % $max + $min`
}

################### domain list #############

wifishare_log()
{
    logger -p debug -t wifishare "$1"
}

business_whitehost_add()
{
    for _host in $1
    do
        echo "ipset=/$_host/$share_whitehost_ipset" >>$share_whitehost_file
    done
}

business_init()
{
    rm $share_whitehost_file
    touch $share_whitehost_file

    for _idx in $hosts_index
    do
        _hosts=`eval echo '$hosts_'"$_idx"`
        business_whitehost_add "$_hosts"
    done
}

################### hwnat ###################
hwnat_start()
{
    [ "$hashwnat" != "1" ] && return;

uci -q batch <<-EOF >/dev/null
    set hwnat.switch.${section_name}=0
    commit hwnat
EOF
    /etc/init.d/hwnat start &>/dev/null
}

hwnat_stop()
{
    [ "$hashwnat" != "1" ] && return;

uci -q batch <<-EOF >/dev/null
    set hwnat.switch.${section_name}=1
    commit hwnat
EOF
    /etc/init.d/hwnat stop &>/dev/null
}

_locked="0"
################### lock ###################
fw3_lock()
{
    trap "lock -u $fw3lock; exit 1" SIGHUP SIGINT SIGTERM
    lock $fw3lock
    return $?
}

fw3_trylock()
{
    trap "lock -u $fw3lock; exit 1" SIGHUP SIGINT SIGTERM
    lock -n $fw3lock
    [ $? == 1 ] && _locked="1"
    return $?
}

fw3_unlock()
{
    lock -u $fw3lock
}

################### dnsd ###################
share_dnsd_start()
{

    killall dnsd > /dev/null 2>&1

    guest_gw=$(uci get network.guest.ipaddr)
    [ $? != 0 ] && return;

    #always create/update the dnsd config file (guest gw maybe changed)
    echo "* $guest_gw" > $dnsd_conf
    [ $? != 0 ] && return;

    dnsd -p $dnsd_port -c $dnsd_conf -d > /dev/null 2>&1
    [ $? != 0 ] && {
        rm $dnsd_conf > /dev/null 2>&1
        return ;
    }
}

share_dnsd_stop()
{
    killall dnsd > /dev/null 2>&1

    [ -f $dnsd_conf ] && {
        rm $dnsd_conf > /dev/null 2>&1
    }
}

################### config ###################


share_parse_global()
{
    local section="$1"
    auth_timeout=""
    #timeout=""

    config_get disabled  $section disabled &>/dev/null;

    config_get auth_timeout  $section auth_timeout &>/dev/null;
    [ "$auth_timeout" == "" ] && auth_timeout=${auth_timeout_default}

    config_get timeout  $section timeout &>/dev/null;
    [ "$timeout" == "" ] && timeout=${timeout_default}

    config_get _business  $section business &>/dev/null;
    [ "$_business" == "" ] && _business=${business_default}

    config_get _sns  $section sns &>/dev/null;
    [ "$_sns" == "" ] && _sns=${sns_default}

    config_get _active  $section active &>/dev/null;
    [ "$_active" == "" ] && _active=${active_default}

    if [ "$_active" == "business" ]
    then
        active_type="$_business"
    else
        active_type="$_sns"
    fi

    #echo "active   -- $_active"
    #echo "sns      -- $_sns"
    #echo "business -- $_business"
    #echo "type     -- $active_type"
}

share_parse_block()
{
    config_get macs_blocked $section mac &>/dev/null;
}


share_ipset_create()
{
    _rule_ipset=$1
    [ "$_rule_ipset" == "" ] && return;

    ipset flush   $_rule_ipset >/dev/null 2>&1
    ipset destroy $_rule_ipset >/dev/null 2>&1
    ipset create  $_rule_ipset hash:net >/dev/null

    return
}


share_ipset_destroy()
{
    _rule_ipset=$1
    [ "$_rule_ipset" == "" ] && return;

    ipset flush   $_rule_ipset >/dev/null 2>&1
    ipset destroy $_rule_ipset >/dev/null 2>&1

    return
}

################### iptables ###################
ipt_table_create()
{
    iptables -t $1 -F $2 >/dev/null 2>&1
    iptables -t $1 -X $2 >/dev/null 2>&1
    iptables -t $1 -N $2 >/dev/null 2>&1
}

ipt_table_destroy()
{
    iptables -t $1 -F $2 >/dev/null 2>&1
    iptables -t $1 -X $2 >/dev/null 2>&1
}

################### firewall ###################
share_fw_add_default()
{
    [ "$hasctf" == "1" ] && iptables -t mangle -I PREROUTING -i br-guest  -j SKIPCTF

    ipt_table_create nat     $share_nat_table
    ipt_table_create nat     $share_nat_device_table
    ipt_table_create nat     $share_nat_dev_redirect_table
    ipt_table_create filter  $share_filter_table
    ipt_table_create filter  $share_filter_device_table

    iptables -t nat -I zone_guest_prerouting -i br-guest -j $share_nat_table >/dev/null 2>&1
    iptables -t filter -I forwarding_rule -i br-guest -j $share_filter_table >/dev/null 2>&1

    iptables -t nat -A wifishare_nat -p tcp -m tcp  --dport 80 -j REDIRECT --to-ports 8999
    #iptables -t nat -A $share_nat_table -p tcp -j REDIRECT --to-ports ${redirect_port}
    #iptables -t nat -A $share_nat_table -p udp -j REDIRECT --to-ports ${redirect_port}

    #dns redirect
    local dnsd_ok="0"
#    ps | grep dnsd | grep -v grep >/dev/null 2>&1
#    [ $? == 0 ] && {
#        dnsd_ok="1"
#    }
#
#    [ "$dnsd_ok" == "1" ] && {
#        iptables -t nat -I $share_nat_table -p udp -m udp --dport ${dns_port} -j REDIRECT --to-port ${dnsd_port}
#    }

    #device list
    iptables -t filter -I $share_filter_table -j $share_filter_device_table
    iptables -t nat -I $share_nat_table -j $share_nat_device_table


    if [ "$dnsd_ok" == "0" ];
    then
        iptables -t nat -I $share_nat_dev_redirect_table -j ACCEPT
        iptables -t nat -I $share_nat_dev_redirect_table -p tcp --dst ${guest_gw} --dport ${http_port} -j REDIRECT --to-ports ${dev_redirect_port}
        iptables -t nat -I $share_nat_dev_redirect_table -p tcp -m set --match-set ${share_whitehost_ipset} dst -j ACCEPT
    else
        iptables -t nat -I $share_nat_table -p udp -m udp --dport ${dns_port} -j ACCEPT
    fi

    for _port in ${whiteport_list}
    do
        iptables -t nat -I $share_nat_table -p udp -m udp --dport ${_port} -j ACCEPT
    done



    #white host
    iptables -t filter -I $share_filter_table -p tcp -m set --match-set ${share_whitehost_ipset} dst -j ACCEPT
    iptables -t filter -I $share_filter_table -p tcp -m tcp --dport 80 -j ACCEPT
    iptables -t filter -I $share_filter_table -o br-lan -j REJECT
    iptables -t filter -A $share_filter_table -p tcp -j REJECT
    iptables -t filter -A $share_filter_table -p udp -j REJECT

    iptables -t nat -I $share_nat_table -p tcp -m set --match-set ${share_whitehost_ipset} dst -j ACCEPT
}

is_active_type()
{
#　$1 type
# $2 type list
    local _type=""
    [ "$1" == "" ] && return 1;
    [ "$2" == "" ] && return 1;

    #reload
    local _is_wechat_pay=$(echo $2 | grep "wifirent_wechat_pay")
    [ "$_is_wechat_pay" != "" ] && {
        [ "$1" == "$WIFIRENT_NAME" ] && return 0;
    }

    #wifishare enable
    [ "$1" == "$WIFIRENT_NAME" ] && return 0;

    for _type in $2
    do
        [ "$_type" == "$1" ] && return 0;
    done

    return 1;
}

share_fw_add_device()
{
    local section="$1"
    local _src_mac=""
    local _start=""
    local _stop=""

    config_get disabled $section disabled &>/dev/null;
    [ "$disabled" == "1" ] && return

    config_get _start $section datestart &>/dev/null;
    [ "$_start" == "" ] && return

    config_get _stop $section datestop &>/dev/null;
    [ "$_stop" == "" ] && return

    config_get _src_mac $section mac 