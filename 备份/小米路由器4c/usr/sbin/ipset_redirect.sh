#!/bin/sh

usage()
{
    echo "ipset redirect usage:"
    echo "ipset_redirect create ipset_name src_port redirect_port"
    echo "ipset_redirect destroy ipset_name src_port redirect_port"
    echo ""
}

module="ipset_redirect"
LOADER="/lib/firewall/ipset_redirect.loader"

create_redirect()
{
    #echo "$module create: $@"
    cfg_name=$1
    src_port=$2
    dest_port=$3
    if [ -z $cfg_name ] || [ -z $src_port ] || [ -z $dest_port ]; then
        echo "$module: args not valid!"
        return
    fi

    # set firewall rule config
    #iptables -t nat -I PREROUTING -p tcp -i br-lan -m set --match-set $cfg_name dst -j DNAT --to $local_ip:$local_port
    [ -f '/etc/config/ipset_redirect' ] || touch /etc/config/ipset_redirect
    uci -q batch <<EOF > /dev/null
set ipset_redirect.$cfg_name=redirect
set ipset_redirect.$cfg_name.src_port=$src_port
set ipset_redirect.$cfg_name.dest_port=$dest_port
set ipset_redirect.$cfg_name.match_set=$cfg_name
set ipset_redirect.$cfg_name.enabled=1
commit ipset_redirect
EOF
    uci -q batch <<EOF > /dev/null
set firewall.$module=include
set firewall.$module.path=$LOADER
set firewall.$module.reload=1
commit firewall
EOF

    # create ipset group
    ipset create $cfg_name hash:ip > /dev/null 2>&1
    # when first start(on), add fw rule manually
    #/etc/init.d/firewall restart
    iptables -t nat -D PREROUTING -i br-lan -p tcp --dport $src_port -m set --match-set $cfg_name dst -j REDIRECT --to-ports $dest_port > /dev/null 2>&1
    iptables -t nat -I PREROUTING -i br-lan -p tcp --dport $src_port -m set --match-set $cfg_name dst -j REDIRECT --to-ports $dest_port > /dev/null 2>&1
}

destroy_redirect()
{
    #echo "$module destroy: $@"
    cfg_name=$1
    src_port=$2
    dest_port=$3
    if [ -z $cfg_name ] || [ -z $src_port ] || [ -z $dest_port ]; then
        echo "$module: arg not valid!"
        return
    fi

    # destroy iptable rule, for fw restart
    uci -q delete ipset_redirect.$cfg_name
    uci commit ipset_redirect

    # when off, del fw rule, do not restart fw
    iptables -t nat -D PREROUTING -i br-lan -p tcp --dport $src_port -m set --match-set $cfg_name dst -j REDIRECT --to-ports $dest_port > /dev/null 2>&1

    # destroy ipset if possible
    ipset flush $cfg_name >/dev/null 2>&1
    ipset destroy $cfg_name >/dev/null 2>&1
}

case "$1" in
    create)
        shift
        create_redirect "$@"
        ;;
    destroy)
        shift
        destroy_redirect "$@"
        ;;
    *)
        usage
        ;;
esac

