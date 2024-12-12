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

    MOUNT_PARAMETERS+="-o "
    case $MODE in
        "mount") mount_parameters_prompt && mount;;
        "unmount") unmount;;
    esac
}

mount_parameters_prompt() {
    printf "Mounting with Permission?\n"
    printf "000 - umask 000\nuser/<username> - owner of this device\n"
    read mount_parameters_ask
    case $mount_parameters_ask in
        "000")  MOUNT_PARAMETERS+="umask=000"           ;;
        user/*)
                local user="${mount_parameters_ask#user/}"
                local user_uid=$(id -u "$user" 2>/dev/null)
                local group_uid=$(id -g "$user" 2>/dev/null)

                if [ $? -eq 0 ] && [ -n "$user_uid" ] && [ -n "$group_uid" ]; then
                    # mount with owner,group and umask is owner r/w/e only
                    MOUNT_PARAMETERS+="gid=$user_uid,uid=$group_uid,umask=077"
                else
                    printf "User id for %s not found!\n" $user
                    mount_parameters_prompt
                fi                                      ;;
        *)      mount_parameters_prompt                 ;;
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