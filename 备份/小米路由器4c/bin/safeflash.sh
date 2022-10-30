#!/bin/sh
if [ $# != 1 ] ; then
	echo "USAGE: $0 <factory.bin>"
	exit 1;
fi
if [ ! -s "$1" ]
	then
	echo "ERROR: $1 no exist or empty."
	exit 1
fi

find_mtd_part() {
	local PART="$(grep "\"$1\"" /proc/mtd | awk -F: '{print $1}')"
	local PREFIX=/dev/mtdblock
	PART="${PART##mtd}"
	[ -d /dev/mtdblock ] && PREFIX=/dev/mtdblock/
	echo "${PART:+$PREFIX$PART}"
}

echo "begin ugrading..."
nsum=`md5sum $1 | awk '{print $1}'`
echo "$0 $@ MD5: $nsum"

src=`cat /proc/cmdline`;
dst="root=31:04"

echo $src | grep -q $dst
if [ $? -eq 0 ]
	then
	WRITECMD="mtd write $1 firmware"
	exroot="firmware $nsum"
else
	WRITECMD="mtd write $1 firmware2"
	exroot="firmware2 $nsum"
fi
#save checksum first
echo "$exroot" > /etc/expectroot
if [ $? -ne 0 ]
	then
	echo "-----"
	echo "WARNING: overlay filesystem unusable, can not save expectroot $exroot to /etc/expectroot."
	echo "-----"
fi

#TODO: save checksum in sysflag MTD block
echo "$nsum" > /etc/romchecksum 2>/dev/null
if [ $? -ne 0 ]
	then
	echo "-----"
	echo "WARNING: overlay filesystem unusable,can not save rom checksum to /etc/romchecksum."
	echo "-----"
fi
$WRITECMD
writecode=$?
if [ $writecode -ne 0 ]
	then
	echo "ERROR: mtd write failed."
	exit 1
fi

mtdpart="$(find_mtd_part flag_where_reboot)"
if [ -n "$mtdpart" ]
	then
	echo 1 > $mtdpart
else
	echo "WARNING: mtd flag_where_reboot no found."
	uname -a
	bootinfo
fi

echo "upgrade finished..., rebooting"
reboot