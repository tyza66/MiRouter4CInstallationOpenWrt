#!/bin/sh /etc/rc.common

START=49
#STOP=50

num='2'

config_load misc
config_get num messagingagent thread_num

#export command line for /usr/sbin/supervisord
export PROCLINE="/usr/bin/mald $num"
export PROCFLAG="/usr/bin/messagingagent --handler_threads $num"
export PROC_DEBUG_FLAG="on"
export OOM_FLAG=0

export EXTRA_HELP="	status	Status the service"
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
