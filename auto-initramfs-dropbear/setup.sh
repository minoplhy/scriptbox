#!/bin/bash

add_feature_to_file() {
    local file="$1"
    local new_feature="$2"
    local key="features"

    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    local line
    line=$(grep "^$key=" "$file")

    if [[ -z "$line" ]]; then
        echo "$key=\"$new_feature\"" >> "$file"
        echo "Added new line: $key=\"$new_feature\""
        return 0
    fi

    local current_features
    current_features=$(echo "$line" | cut -d'"' -f2)

    if [[ " $current_features " =~ " $new_feature " ]]; then
        echo "Feature '$new_feature' already exists in $file"
        return 0
    fi

    local updated_features="$current_features $new_feature"
    local new_line="$key=\"$updated_features\""

    sed -i "s|^$key=\"[^\"]*\"|$new_line|" "$file"
    echo "Added feature '$new_feature' to $file"
}

extlinux_add_value_to_key() {
    local file="$1"
    local key="$2"
    local new_value="$3"

    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    local line
    line=$(grep "^$key=" "$file")

    if [[ -z "$line" ]]; then
        echo "$key=$new_value" >> "$file"
        echo "Created new key '$key' with value '$new_value'"
        return 0
    fi

    local current_values
    current_values="${line#*=}"

    IFS=',' read -ra arr <<< "$current_values"
    for val in "${arr[@]}"; do
        [[ "$val" == "$new_value" ]] && {
            echo "Value '$new_value' already exists under '$key'"
            return 0
        }
    done

    local updated_values="$current_values,$new_value"
    local new_line="$key=$updated_values"

    sed -i "s|^$key=.*|$new_line|" "$file"
    echo "Added value '$new_value' to key '$key'"
}


extlinux_add_kernel_opt() {
    local file="$1"
    local key="default_kernel_opts"
    local new_opt="$2"

    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    local line
    line=$(grep "^$key=" "$file")

    if [[ -z "$line" ]]; then
        echo "$key=\"$new_opt\"" >> "$file"
        echo "Created new $key with '$new_opt'"
        return 0
    fi

    local current_opts
    current_opts=$(echo "$line" | cut -d'"' -f2)

    if [[ " $current_opts " =~ (^|[[:space:]])$new_opt([[:space:]]|$) ]]; then
        echo "Option '$new_opt' already exists in $key"
        return 0
    fi

    local updated_opts="$current_opts $new_opt"
    local new_line="$key=\"$updated_opts\""

    sed -i "s|^$key=\"[^\"]*\"|$new_line|" "$file"
    echo "Added option '$new_opt' to $key"
}

grub_add_module() {
    local module=$1
    local grub_file="/etc/default/grub"

    if [ -z "$module" ]; then
        echo "No module specified."
        return 1
    fi

    local grub_cmdline=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT' $grub_file | cut -d= -f2- | sed 's/\"//g')

    if [[ "$grub_cmdline" == *"modules=$module"* ]]; then
        echo "Module '$module' already exists in GRUB_CMDLINE_LINUX_DEFAULT."
        return 0
    fi

    if [[ "$grub_cmdline" == *"modules="* ]]; then
        grub_cmdline=$(echo "$grub_cmdline" | sed -E "s/(modules=[^ ]*)/\1,$module/")
    else
        grub_cmdline="modules=$module $grub_cmdline"
    fi

    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$grub_cmdline\"|" $grub_file
    echo "Module '$module' added successfully."
}

grub_add_option() {
    local key_value=$1
    local grub_file="/etc/default/grub"

    if [ -z "$key_value" ]; then
        echo "No key-value pair specified."
        return 1
    fi

    local grub_cmdline=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT' $grub_file | cut -d= -f2- | sed 's/\"//g' )

    if [[ "$grub_cmdline" == *"$key_value"* ]]; then
        echo "Key-value pair '$key_value' already exists in GRUB_CMDLINE_LINUX_DEFAULT."
        return 0
    fi

    grub_cmdline="$grub_cmdline $key_value"
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$grub_cmdline\"|" $grub_file
    echo "Key-value pair '$key_value' added successfully."
}

# Mandatory Packages
apk add git dropbear

repository="https://github.com/minoplhy/scriptbox"
scriptbox_directory="/root/scriptbox"

if [ ! -d "$scriptbox_directory" ]; then
    git clone $repository $scriptbox_directory
fi

ip=$1

cp ~/.ssh/authorized_keys /etc/dropbear/authorized_keys
cp $scriptbox_directory/alpine-initramfs-dropbear/features.d/* /etc/mkinitfs/features.d
cp $scriptbox_directory/alpine-initramfs-dropbear/dropbear/unlock_disk /etc/dropbear/unlock_disk
chmod +x /etc/dropbear/unlock_disk
dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key 

add_feature_to_file "/etc/mkinitfs/mkinitfs.conf" "dropbear"
add_feature_to_file "/etc/mkinitfs/mkinitfs.conf" "network"

if [[ -f "/etc/update-extlinux.conf" ]]; then
    extlinux_add_value_to_key "/etc/update-extlinux.conf" "modules" "virtio_pci"
    extlinux_add_value_to_key "/etc/update-extlinux.conf" "modules" "virtio_net"

    extlinux_add_kernel_opt "/etc/update-extlinux.conf" "dropbear=5555"
    extlinux_add_kernel_opt "/etc/update-extlinux.conf" "ip=$ip"

    update-extlinux
    mkinitfs -i $scriptbox_directory/alpine-initramfs-dropbear/initramfs-dropbear
fi

if [[ -f "/etc/default/grub" ]]; then
    cp /etc/default/grub /etc/default/grub.bak

    grub_add_module "virtio_pci"
    grub_add_module "virtio_net"
    # igb is a required network module for Intel machine that i have
    # Find your network module here: https://askubuntu.com/questions/216110/how-do-i-find-what-kernel-module-is-behind-a-network-interface/216116#216116
    grub_add_module "igb"

    grub_add_option "dropbear=5555"
    grub_add_option "ip=$ip"

    update-grub
    mkinitfs -i $scriptbox_directory/alpine-initramfs-dropbear/initramfs-dropbear
fi