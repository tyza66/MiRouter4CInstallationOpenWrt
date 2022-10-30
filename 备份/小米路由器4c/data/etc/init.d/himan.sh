#!/bin/sh /etc/rc.common

START=80
STOP=80

sn=`/usr/sbin/nvram get SN`
deviceId=`/sbin/uci get /etc/config/messaging.deviceInfo.DEVICE_ID`
hardware=`/sbin/uci get /usr/share/xiaoqiang/xiaoqiang_version.version.HARDWARE`
rom=`/sbin/uci get /usr/share/xiaoqiang/xiaoqiang_version.version.ROM`
channel=`/sbin/uci get /usr/share/xiaoqiang/xiaoqiang_version.version.CHANNEL`
proxyParams="sn=$sn&deviceId=$deviceId&hardware=$hardware&rom=$rom&channel=$channel"
cmd="/usr/bin/himan --proxy https://api.miwifi.com/utils/proxy --rule https://api.miwifi.com/data/himan_rule?$proxyParams --proxyParams $proxyParams"

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
  return $?
}
start() {
  /usr/sbin/supervisord start
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

