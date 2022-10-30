#!/bin/sh
clean_jobs() {
    for pid in $(pgrep -P $$); do
       kill $pid
    done
}

trap "clean_jobs" TERM

/usr/sbin/iwevent 2>&1 | /usr/sbin/iwevent-call  &
wait
