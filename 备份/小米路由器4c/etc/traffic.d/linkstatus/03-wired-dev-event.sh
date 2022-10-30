#!/bin/sh
qosflag=`uci get miqos.settings.enabled 2>/dev/null`
[ "$qosflag" -ne "1" ] && return 0

if [ "$LINK_STATUS" = "linkup" ]; then
    #logger -t miqos -p9 "port up $PORT_NUM $LINK_STATUS"
    /etc/init.d/miqos device_in 00
else
    #logger -t miqos -p9 "port down $PORT_NUM $LINK_STATUS"
    /etc/init.d/miqos device_out 00
fi
