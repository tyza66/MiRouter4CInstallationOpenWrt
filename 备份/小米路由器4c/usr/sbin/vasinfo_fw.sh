#!/bin/sh

vasinfo_fwon()
{
    uci set vas.services.vasinfo=1
    uci commit vas
}

vasinfo_fwoff()
{
    uci set vas.services.vasinfo=0
    uci commit vas
}

is_vasinfo()
{
    [ "$(uci -q get vas.services.vasinfo)" = '1' ] && [ "$(nvram get flag_show_upgrade_info)" = '1' ]
}

OPT=$1
#main
case $OPT in
    off)
        vasinfo_fwoff
	nvram set flag_show_upgrade_info=0
	nvram commit
	ipset flush rr_sj
        return $?
    ;;

    post_ota)
        vasinfo_fwon
        return $?
    ;;

    status)
	is_vasinfo
	return $?
    ;;
esac
