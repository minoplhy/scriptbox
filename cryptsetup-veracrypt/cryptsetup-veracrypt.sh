#!/bin/bash

#   Veracrypt Cryptsetup script.
#   
#   Mount Veracrypt drive using cryptsetup
#   Currently, only working as promting script, CLI style is not Yet supported.

mount(){
    ${SUDOERS} cryptsetup --type tcrypt --veracrypt open /dev/$drive $container_name

    if [ -e "/dev/mapper/$container_name" ]; then
        ${SUDOERS} mkdir -p "/mnt/$container_name"
        printf "Directory /mnt/%s created.\n" $container_name
    else
        printf "Device /dev/mapper/%s does not exist.\n" $container_name
        exit 1
    fi


    ${SUDOERS} mount ${MOUNT_PARAMETERS[@]} /dev/mapper/$container_name /mnt/$container_name
}

unmount(){
    ${SUDOERS} umount /mnt/$container_name
    
    if [ -e "/dev/mapper/$container_name" ]; then
        DIRECTORY_CLEANUP=true
    else
        printf "Device /dev/mapper/%s does not exist.\n" $container_name
        exit 1
    fi

    ${SUDOERS} cryptsetup close /dev/mapper/$container_name

    if [[ "$DIRECTORY_CLEANUP" == true ]]; then
        ${SUDOERS} rmdir /mnt/$container_name
    fi
}

prompting() {
    MODE=$1
    printf "Available Disks:\n%s\n\nChoose: " "$DISKS"
    read drive

    printf "\nSelect Container Name: "
    read container_name

    case $MODE in
        "mount") mount_permission_prompt && mount;;
        "unmount") unmount;;
    esac
}

mount_permission_prompt() {
    printf "Currently the Mount Parameters is hardcoded, so you have not much choice!\n"
    printf "Mounting with '-o umask=000' (Y/n)? "
    read mount_permission
    case $mount_permission in
        "Y"|"y") MOUNT_PARAMETERS+="-o umask=000"   ;;
        "N"|"n")                                    ;;
        *)       mount_permission_prompt            ;;
    esac
}

if sudo --validate; then
    SUDOERS=sudo
else
    SUDOERS=""
fi

DISKS=$(lsblk -n -o NAME,SIZE,TYPE)
MOUNT_PARAMETERS=()

printf "NOTICE! This script is intended to work with Veracrypt drives in linux only!\n"
printf "Mode: mount/unmount -> "
read MODE

MODE="${MODE,,}"
case $MODE in
    "mount") prompting "mount";;
    "unmount"|"umount") prompting "unmount";;
esac