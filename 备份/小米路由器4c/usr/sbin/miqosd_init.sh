#!/bin/sh

QOS_FORWARD="miqos_fw"   # for XiaoQiang forward
QOS_INOUT="miqos_io"   # for XiaoQiang input/output
QOS_IP="miqos_id"	# for IP mark
QOS_FLOW="miqos_cg"   # for package flow recognization
QOS_TV="miqos_tv"   # for TV/MIBOX

IPT="/usr/sbin/iptables -t mangle"
SIP=`uci get network.lan.ipaddr 2>/dev/null`
SMASK=`uci get network.lan.netmask 2>/dev/null`
SIPMASK="$SIP/$SMASK"

guest_SIP=`uci get network.guest.ipaddr 2>/dev/null`
guest_SMASK=`uci get network.guest.netmask 2>/dev/null`
guest_SIPMASK="$guest_SIP/$guest_SMASK"

wan_if=`uci get network.wan.ifname 2>/dev/null`

#路由优先端口，逗号分隔，最多15组，准许iptables-multiport规范
#port: 22 ssh/53 dns/123 ntp/1880:1890 msgagent/5353 mdns/514 syslog-ng
xq_prio_tcp_ports="22,53,123,1880:1890,5353"
xq_prio_udp_ports="53,123,514,1880:1890,5353"

#micloud port, 小强源端口,33330~33570 (共计240个端口，TODO:后续可用cgroup统一解决)
xq_micloud_ports="33330:33570"

mark_GAME="0x00100000/0x00f00000"
mark_WEB="0x00200000/0x00f00000"
mark_VIDEO="0x00300000/0x00f00000"
mark_DOWNLOAD="0x00400000/0x00f00000"

mark_HIGHEST="0x00010000/0x000f0000"
mark_SPECIAL="0x00020000/0x000f0000"
mark_HOST_NET="0x00030000/0x000f0000"
mark_GUEST_NET="0x00040000/0x000f0000"
mark_XQ="0x00050000/0x000f0000"

#这里恢复相应的cotent-mark到skb上
mask_QOS="0xffff0020"
mask_FLOW_TYPE="0x00f00000"
mask_SUBNET_TYPE="0x000f0000"
mask_IP_TYPE="0xff000000"

#punish if web connbytes > 3MB default
# closed if web connbytes = 0
threshold_of_punishment=3

#ip_set
set_skip_hwqos_name="SKIP_HWNAT4QOS"


#清除ipt规则
$IPT -D FORWARD -j $QOS_FORWARD &>/dev/null
$IPT -D INPUT -j $QOS_INOUT &>/dev/null
$IPT -D OUTPUT -j $QOS_INOUT &>/dev/null

#清除QOS规则链
$IPT -F $QOS_FORWARD &>/dev/null
$IPT -X $QOS_FORWARD &>/dev/null

$IPT -F $QOS_INOUT &>/dev/null
$IPT -X $QOS_INOUT &>/dev/null

$IPT -F $QOS_FLOW &>/dev/null
$IPT -X $QOS_FLOW &>/dev/null

$IPT -F $QOS_IP &>/dev/null
$IPT -X $QOS_IP &>/dev/null

$IPT -F $QOS_TV &>/dev/null
$IPT -X $QOS_TV &>/dev/null

#新建QOS规则链
$IPT -N $QOS_FORWARD &>/dev/null
$IPT -N $QOS_FLOW &>/dev/null
$IPT -N $QOS_IP &>/dev/null
$IPT -N $QOS_INOUT &>/dev/null
$IPT -N $QOS_TV &>/dev/null

#连接QOS的几条规则链
$IPT -A FORWARD -j $QOS_FORWARD &>/dev/null
$IPT -A INPUT -j $QOS_INOUT
$IPT -A OUTPUT -j $QOS_INOUT

#构建INOUT的规则框架 {}
if [[ 1 ]]; then
    $IPT -A $QOS_INOUT -j CONNMARK --restore-mark --nfmask $mask_QOS --ctmask $mask_QOS
    cgroup_mark=`lsmod 2>/dev/null|grep xt_cgroup_MARK `
    if [ -n "$cgroup_mark" ]; then
        $IPT -A $QOS_INOUT -j cgroup_MARK --mask $mask_SUBNET_TYPE
        $IPT -A $QOS_INOUT -j CONNMARK --save-mark --nfmask $mask_QOS --ctmask $mask_QOS
    fi
    $IPT -A $QOS_INOUT -m mark ! --mark 0/$mask_SUBNET_TYPE -j RETURN
    #------------------------------
    #INOUT特定规则
    #APP<->XQ数据流
    $IPT -A $QOS_INOUT -p tcp -m multiport --ports $xq_prio_tcp_ports -j MARK --set-mark $mark_HIGHEST
    $IPT -A $QOS_INOUT -p udp -m multiport --ports $xq_prio_udp_ports -j MARK --set-mark $mark_HIGHEST
    #小强micloud备份源端口,TCP
    $IPT -A $QOS_INOUT -p tcp -m multiport --sports $xq_micloud_ports -j MARK --set-mark $mark_XQ
    #cgroup_mark=`lsmod 2>/dev/null|grep xt_cgroup_MARK `
    #if [ -n "$cgroup_mark" ]; then
    #    $IPT -A $QOS_INOUT -j cgroup_MARK --mask $mask_SUBNET_TYPE
    #fi
    #XQ默认数据类型
    $IPT -A $QOS_INOUT -m mark --mark 0/$mask_SUBNET_TYPE -j MARK --set-mark $mark_XQ
    #------------------------------
    $IPT -A $QOS_INOUT -j CONNMARK --save-mark --nfmask $mask_QOS --ctmask $mask_QOS
fi

#构建FORWARD的规则框架 {}
if [[ 1 ]]; then
    if [ "$threshold_of_punishment" -gt "0" ]; then
        #connection bytes pulishment for web-flow
        threshold=$(($threshold_of_punishment*1024*1024))
        $IPT -A $QOS_FORWARD -m connmark --mark $mark_WEB -m connbytes --connbytes $threshold --connbytes-dir both --connbytes-mode bytes -j CONNMARK --set-mark $mark_DOWNLOAD
    fi

    $IPT -A $QOS_FORWARD -j CONNMARK --restore-mark --nfmask $mask_QOS --ctmask $mask_QOS
    $IPT -A $QOS_FORWARD -m mark --mark 0/$mask_FLOW_TYPE -j flowMARK --ip $SIP --mask $SMASK
    $IPT -A $QOS_FORWARD -j CONNMARK --save-mark --nfmask $mask_QOS --ctmask $mask_QOS
    $IPT -A $QOS_FORWARD -m mark ! --mark 0/$mask_IP_TYPE -j RETURN
    #------------------------------
    #FORWARD特定规则
    # to set ip mark
    $IPT -A $QOS_FORWARD -m mark --mark 0/$mask_IP_TYPE -j $QOS_IP
    # to set video/audio mark
    $IPT -A $QOS_FORWARD -m mark --mark 0/$mask_FLOW_TYPE -j $QOS_TV
    #to set special flow mark
    $IPT -A $QOS_FORWARD -m mark --mark 0/$mask_FLOW_TYPE -j flowMARK --ip $SIP --mask $SMASK
    #to set flow mark by tcp/udp port/tos
    $IPT -A $QOS_FORWARD -m mark --mark 0/$mask_FLOW_TYPE -j $QOS_FLOW
    #to set device type mark
    $IPT -A $QOS_FORWARD -m mark --mark 0/$mask_SUBNET_TYPE -j MARK --set-mark $mark_HOST_NET
    #------------------------------
    $IPT -A $QOS_FORWARD -j CONNMARK --save-mark --nfmask $mask_QOS --ctmask $mask_QOS
fi

#构建IP规则链
if [[ 1 ]]; then
    #构建GUEST网络的IP规则
    if [ -n "$guest_SIP" -a -n "$guest_SMASK" ]; then
        $IPT -A $QOS_IP -d $guest_SIPMASK -j MARK --set-mark-return $mark_GUEST_NET
        $IPT -A $QOS_IP -s $guest_SIPMASK -j MARK --set-mark-return $mark_GUEST_NET
    fi

    $IPT -A $QOS_IP -s $SIPMASK -j IP4MARK --addr src
    $IPT -A $QOS_IP -d $SIPMASK -j IP4MARK --addr dst
fi

#构建数据流FLOW规则链
#1.game,2.web,3.video,4.download
if [[ 1 ]]; then
    CLASS_NUM=4
    for c in $(seq $CLASS_NUM); do
        TCP_PORTS=`uci get miqos.p${c}.tcp_ports 2>/dev/null`
        UDP_PORTS=`uci get miqos.p${c}.udp_ports 2>/dev/null`
        TOS=`uci get miqos.p${c}.tos 2>/dev/null`
        if [ -n "$TCP_PORTS" ]; then
            $IPT -A $QOS_FLOW -p tcp -m mark --mark 0/$mask_FLOW_TYPE -m multiport --ports ${TCP_PORTS} -j MARK --set-mark-return 0x${c}00000/$mask_FLOW_TYPE
        fi
        if [ -n "$UDP_PORTS" ]; then
            $IPT -A $QOS_FLOW -p udp -m mark --mark 0/$mask_FLOW_TYPE -m multiport --ports ${UDP_PORTS} -j MARK --set-mark-return 0x${c}00000/$mask_FLOW_TYPE
        fi
        if [ -n "$TOS" ]; then
            $IPT -A $QOS_FLOW -p udp -m mark --mark 0/$mask_FLOW_TYPE -m tos --tos ${TOS} -j MARK --set-mark-return 0x${c}00000/$mask_FLOW_TYPE
        fi
    done
fi

#since 2015-8-10, content mark startup at init script.
#恒定开启http-content分流功能
#http_content_type_mark.sh on >/dev/null 2>&1

#开启ctf的流量惩罚
ctf_act_punish="/proc/sys/net/ipv4/mark_web_flow/mark_web_exceed_flow"
if [ -f "$ctf_act_punish" ]; then
    echo "$threshold_of_punishment:$mask_FLOW_TYPE:$mark_WEB:$mark_DOWNLOAD" > $ctf_act_punish
fi

#开启ipset, 使一部分IP不进HWQOS,而直接走soft-QoS
hwnat_dev="/dev/hwnat0"
if [ -e /usr/sbin/ipset -a -c $hwnat_dev ]; then
    /usr/sbin/ipset -q $set_skip_hwqos_name
    /usr/sbin/ipset -q create $set_skip_hwqos_name hash:ip

    $IPT -D PREROUTING -m set --match-set $set_skip_hwqos_name src -j MARK --set-mark 0x20/0x20
    $IPT -I PREROUTING -m set --match-set $set_skip_hwqos_name src -j MARK --set-mark 0x20/0x20
    $IPT -D POSTROUTING -m set --match-set $set_skip_hwqos_name dst -j MARK --set-mark 0x20/0x20
    $IPT -I POSTROUTING -m set --match-set $set_skip_hwqos_name dst -j MARK --set-mark 0x20/0x20
fi

#dev redirect
[ -f /proc/sys/net/dev_redirect_map ] && [ -n "$wan_if" ] && {
    echo "+ $wan_if ifb0" > /proc/sys/net/dev_redirect_map
}
