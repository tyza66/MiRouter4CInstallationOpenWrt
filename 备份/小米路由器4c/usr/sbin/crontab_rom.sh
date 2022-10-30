#!/bin/sh

#check pid exist
pid_file="/tmp/crontab_pid_xxxx"
if [ -f $pid_file ]; then
        exist_pid=`cat $pid_file`
        if [ -n $exist_pid ]; then
                kill -0 $exist_pid 2>/dev/null
                if [ $? -eq 0 ]; then
                        echo ignored >> /var/log/crontab_rom.log
                        exit 1
                else
                        echo $$ > $pid_file
                fi
        else
                echo $$ > $pid_file
        fi
else
        echo $$ > $pid_file
fi

if [ $# -eq 0 ]; then
	lua /usr/sbin/checkupgrade.lua
fi

if [ $# -eq 3 ]; then
	lua /usr/sbin/checkupgrade.lua $1 $2 $3
fi

