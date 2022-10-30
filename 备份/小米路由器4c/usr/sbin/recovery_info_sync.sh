#!/bin/sh
# Copyright (C) 2015 Xiaomi

REQUEST_URL="http://api.miwifi.com/report_recovery?"

sync_work_mode()
{
    local device_id=`nvram get nv_device_id`
    local secret=`nvram get nv_channel_secret`
    local nonce=`date | md5sum | cut -d' ' -f1`
    local signature=`echo -n ${secret}${nonce} | md5sum | cut -d' ' -f1`
    local sync=`wget ${REQUEST_URL}"device_id="${device_id}"&nonce="${nonce}"&signature="${signature} -O /tmp/report.log`
    local code=`cat /tmp/report.log | cut -d '{' -f2|cut -d '}' -f1 | awk -F, '{i=1; while(i<=NF){ if($i~/^\"code\":/) { print substr($i,8);break;}; i++}}'`
    [ $code = '0' ] && return 0
    return 1
}

for i in `seq 1 10`
do
   sleep `expr $i \* 30`
   sync_work_mode
   [ $? = '0' ] && return 0
done

return 1