#!/bin/bash

#
#   7 Test Suite
#
os=$(uname -s 2>/dev/null || echo "Unknown")
arch=$(uname -m 2>/dev/null || echo "Unknown")

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

GOECS_VERSION=v0.1.29
case $os in
    Linux|linux|LINUX)
        case $arch in
            x86_64|amd64|x64) zip_file="amd64" ;;
            i386|i686) zip_file="386" ;;
            aarch64|arm64|armv8|armv8l) zip_file="arm64" ;;
            arm|armv7l) zip_file="arm" ;;
            mips) zip_file="mips" ;;
            mipsle) zip_file="mipsle" ;;
            s390x) zip_file="s390x" ;;
            riscv64) zip_file="riscv64" ;;
            *) zip_file="amd64" ;;
        esac
    ;;
esac

wget -O goecs.zip https://github.com/oneclickvirt/ecs/releases/download/$GOECS_VERSION/goecs_linux_$zip_file.zip
unzip goecs.zip && rm goecs.zip
./goecs -l en -menu=false -upload=false
rm goecs

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