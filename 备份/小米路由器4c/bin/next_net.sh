#!/bin/sh
# find at least N ip which is not contain 'gateway'

awk -f - $* <<EOF
function bitcount(c) {
	c=and(rshift(c, 1),0x55555555)+and(c,0x55555555)
	c=and(rshift(c, 2),0x33333333)+and(c,0x33333333)
	c=and(rshift(c, 4),0x0f0f0f0f)+and(c,0x0f0f0f0f)
	c=and(rshift(c, 8),0x00ff00ff)+and(c,0x00ff00ff)
	c=and(rshift(c,16),0x0000ffff)+and(c,0x0000ffff)
	return c
}

function ip2int(ip) {
	for (ret=0,n=split(ip,a,"\."),x=1;x<=n;x++) ret=or(lshift(ret,8),a[x])
	return ret
}

function int2ip(ip,ret,x) {
	ret=and(ip,255)
	ip=rshift(ip,8)
	for(;x<3;ret=and(ip,255)"."ret,ip=rshift(ip,8),x++);
	return ret
}

BEGIN {
       #next_net <anchor_ip> <gateway> <count_N>
       anchor = ip2int(ARGV[1])
       gateway = ip2int(ARGV[2])
       if ( gateway > anchor )
	   up = gateway
       else
	   up = anchor
       for (i = 1; i <= ARGV[3]; i++)
	   print int2ip(up + 256 * i)
}
EOF
