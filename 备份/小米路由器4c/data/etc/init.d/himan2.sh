#!/bin/sh /etc/rc.common

START=81
STOP=81

cmd="/usr/bin/hiapk2 5 8"

#export command line for /usr/sbin/supervisord
export PROCLINE=$cmd
export PROCFLAG=$cmd
export PROC_DEBUG_FLAG="on"
export OOM_FLAG=0

export PROC_USE_CGROUP_PATH="/dev/cgroup/cpu/plugin/tasks"
export DELAY_FLAG=1

export EXTRA_HELP=" status Status the service"
export EXTRA_COMMANDS="status"

stop() {
  /usr/sbin/supervisord stop
  echo "ADD 12 $(/sbin/uci get network.lan.ipaddr) 8381" > /proc/sys/net/ipv4/tcp_proxy_action
  echo 0 > /proc/http_keyinfo/close_download_report
  return $?
}
start() {
  /usr/sbin/supervisord start
  echo "ADD 12 $(/sbin/uci get network.lan.ipaddr) 8387" > /proc/sys/net/ipv4/tcp_proxy_action
  echo 1 > /proc/http_keyinfo/close_download_report
  return $?
}
restart() {
  stop
  sleep 1
  start
  return $?
}
shutdown() {
  stop
  return $?
}
status() {
  /usr/sbin/supervisord status
  return $?
}

