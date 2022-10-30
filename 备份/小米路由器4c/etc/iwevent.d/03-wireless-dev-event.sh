#!/bin/sh
qosflag=`uci get miqos.settings.enabled 2>/dev/null`
[ "$qosflag" -ne "1" ] && return 0

[ -n "$STA" ] && {
	   [ "$ACTION" = "ASSOC" ] && {
          #/etc/init.d/miqos device_in $STA
          {
            flock -e -n 200
            if [ "$?" -ne "1" ]; then
                /usr/sbin/miqosc device_in $STA
            fi
          } 200<>"/tmp/wireless_dev_event.lock"
	   }

       [ "$ACTION" = "DISASSOC" ] && {
          #/etc/init.d/miqos device_out $STA
          {
            flock -e -n 200
            if [ "$?" -ne "1" ]; then
                /usr/sbin/miqosc device_out $STA
            fi
          } 200<>"/tmp/wireless_dev_event.lock"
       }

}

return 0

