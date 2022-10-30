#!/bin/sh
plugin_chroot_file=$2/chroot_file/
root_path=$1
root_bin=$root_path/bin
root_lib=$root_path/lib
root_userlib=$root_path/usr/lib
root_user=$root_path/usr
root_proc=$root_path/proc
root_dev=$root_path/dev
root_tmp=$root_path/tmp

check_and_umount(){
        exist=`df -h |grep $1`
        if $exist ;then
                umount $1 -f 2>/dev/null
        fi
}

check_and_umount $root_lib
check_and_umount $root_bin
check_and_umount $root_proc
check_and_umount $root_dev
check_and_umount $root_tmp

mkdir -p $root_bin
mkdir -p $root_lib
mkdir -p $root_userlib
mkdir -p $root_path/etc
#mkdir -p $root_proc
mkdir -p $root_tmp

mount --bind -r $plugin_chroot_file/lib $root_lib
mount --bind -r $plugin_chroot_file/usr/lib $root_userlib
mount -t tmpfs tmpfs $root_tmp -o mode=0755,size=128K
mount --bind -r $plugin_chroot_file/bin $root_bin

cp /tmp/TZ $root_path/etc/TZ
cp /etc/passwd $root_path/etc/passwd
cp /etc/group $root_path/etc/group

is_lt=`echo $1 | grep 2882303761517745527`
echo "is_lt is $is_lt"
if [ -n "$is_lt" ]; then
        echo "lt exist."
        uci set vas_user.services.lt_ctrl=1
        uci commit vas_user
        mkdir -p $root_proc
        mount -t proc proc $root_proc
        
        lt_config="$root_path/main.conf"
        _wan_proto=$(uci get network.wan.proto 2>/dev/null)
        if [ "$_wan_proto"x = "pppoe"x ]; then
                _wan_iface="pppoe-wan"
        else
                _wan_iface=$(uci get network.wan.ifname 2>/dev/null)
        fi
        _id_for_vendor=$(matool --method idForVendor --params 2882303761517745527 2>/dev/null)
        _id_for_vendor=$(echo ${_id_for_vendor:0:16})
        sed -i "s/\"iface\":[^,]*/\"iface\":\"$_wan_iface\"/g" $lt_config
        sed -i "s/\"id\":[^,]*/\"id\":\"$_id_for_vendor\"/g" $lt_config
        return
fi

