#!/bin/bash

#
#   7 Test Suite
#

CPU_INFO=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
CPU_AES=$(grep aes /proc/cpuinfo)
CPU_VIRT=$(lscpu | grep "Virtualization:" | awk '{print $2}')
CPU_VIRT_VENDOR=$(systemd-detect-virt 2>/dev/null)

MEM_TOTAL=$(free -h | awk 'NR==2 {print $2}')
MEM_READ_SPEED=$(sysbench memory  --memory-oper=read run | grep -i transferred | grep -o '[0-9]\+\.[0-9]\+ MiB/sec')
MEM_WRITE_SPEED=$(sysbench memory --memory-oper=write run | grep -i transferred | grep -o '[0-9]\+\.[0-9]\+ MiB/sec')

DISK_TOTAL=$(df -h -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs -t swap -t exfat --total 2>/dev/null | grep total | awk '{ print $2 }')

[[ -z "$CPU_AES" ]] || CPU_AES="yes"

curl -SL https://yabs.sh | bash -s -- -4 -5 -6 | perl -pe 's/\e\[?.*?[@-~]//g' | perl -pe 's/.*\r(.*)/$1/' > yabs.txt
curl -sL https://nws.sh | bash | perl -pe 's/\e\[?.*?[@-~]//g' | perl -pe 's/.*\r(.*)/$1/' > nws.txt
curl -sL https://bench.monster | bash -s -- -all > bench.txt

echo "{{< vps_info
cpu=\"$CPU_INFO\"
aesni=\"$CPU_AES\"
virt=\"$CPU_VIRT\"
hypervisor=\"$CPU_VIRT_VENDOR\"
memory_total=\"$MEM_TOTAL\"
memory_read=\"$MEM_READ_SPEED\"
memory_write=\"$MEM_WRITE_SPEED\"
disk_total=\"$DISK_TOTAL\"
>}}
" > vpsinfo.txt