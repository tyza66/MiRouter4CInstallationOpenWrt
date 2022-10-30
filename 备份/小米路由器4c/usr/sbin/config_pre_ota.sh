#!/bin/sh

export PATH=/bin:/sbin:/usr/bin:/usr/sbin
pipedlog(){
	local oneline
	while read oneline
	do
		dlog "$oneline"
	done
}
#
export LOGTAG="PRE_OTA"
#
dlog(){
	local oneline
	oneline="$@"
	if [ -x /usr/bin/logger ]
		then
		logger -s -p 6 -t "$LOGTAG" -- "$oneline"
	else
		echo "`date` ${LOGTAG}[${$}]: $oneline"
	fi
}

filelist="$(ls -A /lib/config_pre_ota/* 2>/dev/null)"
#dlog "INFO: no pre ota script existed."
test -z "$filelist" && return 0

rctimelimit=65
errcnt=0
okcnt=0
totalpre=0
totalesp=0
for onescript in $filelist
do
		#dlog "running $onescript ..."
		export LOGTAG="PRE_OTA $onescript"
		startts=$(date +%s)
		runt $rctimelimit $onescript pre 2>&1 | pipedlog
		if [ $? -ne 0 ]
			then
			let errcnt=$errcnt+1
		else
			let okcnt=$okcnt+1
		fi
		let espts=$(date +%s)-$startts
		let totalesp=$totalesp+$espts
		let totalpre=$totalpre+1
		export LOGTAG="PRE_OTA"
		#dlog "$onescript espts $espts, total esp $totalesp"
done
dlog "total $totalpre scripts, error $errcnt, total esp $totalesp"
exit $errcnt
#
