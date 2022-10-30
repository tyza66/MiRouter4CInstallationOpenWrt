#!/bin/sh

CFG_PATH="/proc/sys/net/ipv4/tcp_proxy_action"
LIP=`uci get network.lan.ipaddr 2>/dev/null`
APK_VERSION="HIAPK2"
PROXY_PORT2=8387
PROXY_PORT=8381
PROXY_PASS_PORT=8384
HIMAN_PORT=8080
PROXY_SWITCH_PATH="/proc/sys/net/ipv4/tcp_proxy_switch"
APP_CTF_MGR="/usr/sbin/ctf_manger.sh"
service_name="http_apk_proxy"
PIDFILE="/tmp/apk_query.pid"
REFERER_STR="miwifi.com"
REFERER_PATH="/proc/http_conn/referer"
IPSET_NAME="apk_query"

#/usr/sbin/apk_query &
APK_EXECMD="/usr/sbin/apk_query"
APK_EXTRA_FLAG="/usr/sbin/apk_query"

usage()
{
    echo "usage:"
    echo "http_apk_proxy.sh on|off"
    echo "on -- enable apk proxy"
    echo "off -- disable apk proxy"
    echo ""
}

is_repeater() {
    netmode=`uci -q -S get xiaoqiang.common.NETMODE`
    if [ "$netmode" == "wifiapmode" -o "$netmode" == "lanapmode" ]; then
        is_support_model
        if [ $? -eq 1 ]; then
            return 1
        fi
    fi
    return 0
}

# only for in china region
is_applicable()
{
    local cc=$(nvram get CountryCode)
    cc=${cc:-"CN"}
    if [ $cc != "CN" ]; then
        echo "$service_name: only for China!"
        return 0
    fi
    return 1
}

create_ctf_mgr_entry()
{
    uci -q batch <<EOF > /dev/null
set ctf_mgr.$service_name=service
set ctf_mgr.$service_name.http_switch=off
commit ctf_mgr
EOF
}

reload_iptable_rule()
{
    iptables -t mangle -D fwmark -p tcp -m set --match-set $IPSET_NAME dst -m comment --comment $IPSET_NAME -j MARK --set-xmark 0x40/0x40
    iptables -t mangle -A fwmark -p tcp -m set --match-set $IPSET_NAME dst -m comment --comment $IPSET_NAME -j MARK --set-xmark 0x40/0x40
}

add_iptable_rule()
{
    ipset flush    $IPSET_NAME >/dev/null 2>&1
    ipset destroy  $IPSET_NAME >/dev/null 2>&1
    ipset create   $IPSET_NAME hash:ip >/dev/null 2>&1
    iptables -t mangle -D fwmark -p tcp -m set --match-set $IPSET_NAME dst -m comment --comment $IPSET_NAME -j MARK --set-xmark 0x40/0x40
    iptables -t mangle -A fwmark -p tcp -m set --match-set $IPSET_NAME dst -m comment --comment $IPSET_NAME -j MARK --set-xmark 0x40/0x40

uci -q batch <<-EOF >/dev/null
    set firewall.apk_proxy=include
    set firewall.apk_proxy.path="/lib/firewall.sysapi.loader apk_proxy"
    set firewall.apk_proxy.reload=1
    commit firewall
EOF
}

del_iptable_rule()
{
uci -q batch <<-EOF >/dev/null
    del firewall.apk_proxy
    commit firewall
EOF
    iptables -t mangle -D fwmark -p tcp -m set --match-set $IPSET_NAME dst -m comment --comment $IPSET_NAME -j MARK --set-xmark 0x40/0x40
    ipset flush    $IPSET_NAME >/dev/null 2>&1
    ipset destroy  $IPSET_NAME >/dev/null 2>&1
}

enable_apk_proxy()
{
    fastpath=`uci get misc.http_proxy.fastpath -q`
    [ -z $fastpath ] && return 0

    if [ $fastpath == "ctf" ]; then
        if [ -f $APP_CTF_MGR ]; then
            is_exist=`uci get ctf_mgr.$service_name -q`
            if [ $? -eq "1" ]; then
                create_ctf_mgr_entry
            fi
            $APP_CTF_MGR $service_name http on
        else
            echo "$service_name: no ctf mgr found!"
            return 0
        fi
    elif [ $fastpath == "hwnat" ]; then
        echo "$service_name: can work with hw_nat."
    else
        echo "$service_name: unknown fastpath! Treat as std!"
    fi

    # insert kmod
    insmod nf_conn_ext_http >/dev/null 2>&1
    insmod nf_tcp_proxy >/dev/null 2>&1
    insmod http_apk_plus >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_timestamps=0 >/dev/null 2>&1

    [ -f $PIDFILE ] && kill $(cat $PIDFILE)

    add_iptable_rule

    export PROCLINE="${APK_EXECMD}"
    export PROCFLAG="${APK_EXTRA_FLAG}"
    export PROCNUM='1'
    /usr/sbin/supervisord start
    # ensure start switch
    echo "1" > $PROXY_SWITCH_PATH
    if [ "$APK_VERSION" == "HIAPK2" ]; then
        echo "ADD 12 $LIP $PROXY_PORT2" > $CFG_PATH
    else
        echo "ADD 7 $LIP $PROXY_PORT" > $CFG_PATH
    fi

    echo "ADD 9 $LIP $PROXY_PASS_PORT" > $CFG_PATH
    echo "ADD 10 $LIP $HIMAN_PORT" > $CFG_PATH
    [ -f $REFERER_PATH ] && echo $REFERER_STR > $REFERER_PATH 2>/dev/null
}

disable_apk_proxy()
{
    rmmod http_apk_plus >/dev/null 2>&1
    rmmod nf_tcp_proxy >/dev/null 2>&1

    export PROCLINE="${APK_EXECMD}"
    export PROCFLAG="${APK_EXTRA_FLAG}"
    /usr/sbin/supervisord stop
    [ -f $PIDFILE ] && kill $(cat $PIDFILE)

    del_iptable_rule

    fastpath=`uci get misc.http_proxy.fastpath -q`
    [ -z $fastpath ] && return 0

    if [ $fastpath == "ctf" ]; then
        if [ -f $APP_CTF_MGR ]; then
            $APP_CTF_MGR $service_name http off
        fi
    elif [ $fastpath == "hwnat" ]; then
        echo "$service_name: stopped."
    else
        echo "$service_name: unknown fastpath! Treat as std!"
    fi
}

op=$1
if [ -z $op ]; then
    usage
    return 0
fi

is_applicable
[ $? -eq 0 ] && return 0
is_repeater
[ $? -eq 1 ] && return 0

if [ $op == "on" ]; then
    enable_apk_proxy
elif [ $op == "off" ]; then
    disable_apk_proxy
elif [ $op == "reload_iptable_rule" ]; then
    reload_iptable_rule
else
    echo "wrong parameters!"
    usage
fi
return 0
