#!/bin/sh
pid_file="/tmp/pid_xxxx"
if [ -f $pid_file ]; then
        exist_pid=`cat $pid_file`
        if [ -n $exist_pid ]; then
                kill -0 $exist_pid 2>/dev/null
                if [ $? -eq 0 ]; then
                        exit 1
                fi
        fi
fi
