#!/bin/sh
# Copyright (C) 2015 Xiaomi

wanip_status="/tmp/router_in_xiaomi"
local interval=5

security_check_log()
{
    logger -p debug -t wifi_security_check "$1"
}

# check guest wifi config status
# return 0: close
# return 1: open
get_guestwifi_status()
{
    # get guestwifi config
    local guest_config="$(uci show |grep wifishare  2>/dev/NULL)"
    if [ "$guest_config" != "" ]
    then
        return 1;
    else
        return 0;
    fi
}

# if router in xiaomi office, shutdown guest wifi.
guestwifi_shutdown()
{
    local guest_name="$(uci get misc.wireless.guest_2G 2>/dev/NULL)"
    #local lan_ip="$(uci get network.lan.ipaddr 2>/dev/NULL)"
    local guestwifi_up="$(ifconfig $guest_name |grep RUNNING  2>/dev/NULL)"
    local route_in_xiaomi="$(cat  $wanip_status)"

    #security_check_log $guest_name
    #security_check_log $route_in_xiaomi
    #security_check_log $guestwifi_up

    local date_tag=$(date +%F" "%H:%M:%S)

    # get guestwifi config status
    get_guestwifi_status
    local guest_config_open=$?

    #security_check_log "guest_config_open is $guest_config_open"

    # if router in xiaomi, shutdown
    if [ $route_in_xiaomi == 0 ]; then
        if [ $guest_config_open == 1 ]; then
            # if not in xiaomi, but not running, ifconfig up it.
            if [ "$guestwifi_up" == "" ]; then
                #echo "guest wifi is down and not in xiaomi, ifconfig up it."
                ifconfig $guest_name up
                logger -p info -t wifishare "stat_points_none guest wifi is down but not in xiaomi, open it. $date_tag"
                security_check_log "guest wifi is down and not in xiaomi, ifconfig up it."
            fi
        fi
    else
        # other condition: if guest wifi is running, shutdown it !!!!
        if [ "$guestwifi_up" != "" ]; then
            #echo "guest wifi is up in xiamo, shutdown it."
            ifconfig $guest_name down
            security_check_log "guest wifi is up in xiamo, shutdown it."
            logger -p info -t wifishare "stat_points_none guest wifi is up in xiaomi, shutdown it. $date_tag"
        fi
    fi
}

# security check logic
security_check_start()
{
    return
    # kill old deamon first, if exist.
    security_check_stop
    while true
    do
        # check router whether in xiaomi office, for guest wifi.
        guestwifi_shutdown

        # other check
        sleep $interval
    done
}

# kill all start deamon
security_check_stop()
{
    return
    local date_tag=$(date +%F" "%H:%M:%S)
    local this_pid=$$
    local one_pid=""
    local _pid_list=""
    echo $$ >/tmp/security_check.pid

    _pid_list=$(ps w|grep security_check.sh|grep -v grep |grep -v counting|awk '{print $1}')
    for one_pid in $_pid_list
    do
        echo "get security check pid "$one_pid" end"
        [ "$one_pid" != "$this_pid" ] && {
            echo "security check kill "$one_pid
            kill -9 $one_pid
        }
    done

    local guest_name="$(uci get misc.wireless.guest_2G 2>/dev/NULL)"
    local guestwifi_up="$(ifconfig $guest_name |grep RUNNING  2>/dev/NULL)"
    local guest_config="$(uci show |grep wifishare  2>/dev/NULL)"

    # make guest wifi down, when guest wifi off. for R4 ...
    if [ "$guestwifi_up" != "" ] && [ "$guest_config" == "" ]; then
        ifconfig $guest_name down
        security_check_log "security check stop, shutdown guest wifi."
        logger -p info -t wifishare "stat_points_none guest wifi security check stop, shutdown it. $date_tag"
    fi
    security_check_log "security check daemon stop"
}

OPT=$1

security_check_log "$OPT"

case $OPT in
    on)
        security_check_start
        return $?
    ;;

    off)
        security_check_stop
        return $?
    ;;
esac

