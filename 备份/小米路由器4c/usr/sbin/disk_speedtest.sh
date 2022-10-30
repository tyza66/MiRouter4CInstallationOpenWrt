#!/bin/sh
# simple device speed test script @xiaomi

fail_log() {
	echo "Error:" "$1"
	[ -f "$mountpoint"/.1.bin ] && rm -f "$mountpoint"/.1.bin
	exit 1
}

drive="$1"
timeout="$2"

[ -z "$timeout" ] && timeout=5

[ -z "$drive" ] && fail_log "Input test drive"
[ -e "$drive" ] || fail_log "Device not found"

mount | grep -q "$drive" || fail_log "USB device mount failed"
mountpoint=`cat /proc/mounts | grep "$drive" | head -n 1 | cut -d " " -f 2`

echo 3 > /proc/sys/vm/drop_caches
date1=`date +%s`
dd if=/dev/zero of="$mountpoint"/1.bin bs=4096 count=2k &> /dev/null
sync
echo 3 > /proc/sys/vm/drop_caches
md5=`md5sum "$mountpoint"/1.bin | cut -d " " -f 1`
[ "$md5" = "96995b58d4cbf6aaa9041b4f00c7f6ae" ] || fail_log "md5 sum failed"
date2=`date +%s`

[ "$(($date2-$date1))" -gt "$timeout" ] && fail_log "usb too slow"

rm -f "$mountpoint"/1.bin
sync

echo "PASS"
