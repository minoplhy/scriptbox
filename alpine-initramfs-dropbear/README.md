# Alpine Initramfs Dropbear
This script took a huge references from:

* [https://github.com/Deeplerg/fork-alpine-initramfs-dropbear](https://github.com/Deeplerg/fork-alpine-initramfs-dropbear)

* [https://github.com/mk-f/alpine-initramfs-dropbear](https://github.com/mk-f/alpine-initramfs-dropbear)

* [https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in](https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in)

This script is modified from [alpine/mkinitfs - initramfs-init.in](https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in)

significant changes:

* Add dropbear

* After unlocked, kill all remainings dropbear and nlplug-findfs process, so no struck process reached the system.

* optional support IPv6 unlock

## Fileinfo:

`alpine-initramfs-base`  : normal alpine initramfs file which the code is based on

`initramfs-dropbear`     : normal dropbear version

`initramfs-dropbear-ipv6`: dropbear with IPv6 support

`*.patch` : patch file version of the code

## Install

Please install `dropbear` before continuing

1. copy `dropbear/unlock_disk` to `/etc/dropbear/unlock_disk`
    * Also Make sure `/etc/dropbear/unlock_disk` is executable! else dropbear will exit with "failed child"W
2. copy `authorized_keys` to `/etc/dropbear/authorized_keys`
3. copy `features.d` to /`etc/mkinitfs/features.d`
    * If using IPv6 mode, don't forget to also include `features.d` from `alpine-initramfs-ipv6` folder.

Note: 
* if you're using Deeplerg/mk-f scripts before don't forget to change `unlock_disk` as i modified that one too.
* If you're using `grub` make sure to install `syslinux` and possibly checkout `/etc/default/grub` and commented CMDLINE that's conflicted with `update-extlinux` like `GRUB_CMDLINE_LINUX_DEFAULT` and `default_kernel_opts` after that `grub-mkconfig -o /boot/grub/grub.cfg`

### /etc/mkinitfs.conf
```
features="ata base ide scsi usb virtio ext4 cryptsetup keymap dropbear network"
```
* features+= `dropbear` `network`

* add `ip` if using in ipv6 mode

### /etc/update-extlinux.conf
```
modules=sd-mod,usb-storage,ext4,ata_piix,virtio_net,e1000e,virtio_pci
```
* if network is not working (/sys/class/net/*/address not found etc.) try adding `e1000e` or `virtio_net` `virtio_pci`
  * Sidenote: Please resort to this guide for a more info about your module [Click](https://askubuntu.com/questions/216110/how-do-i-find-what-kernel-module-is-behind-a-network-interface/216116#216116)

```
default_kernel_opts="cryptroot=UUID=xxx cryptdm=root quiet rootfstype=ext4 dropbear=<dropbear_port> ip=<ip> ip6=<ip6>"
```
* ip= can be both static and dhcp(if supported) `ip=<ip>::<gw>:<mask>::<interface>` `ip=dhcp`

* ip6= only static is supported `ip6=client-ip/gateway-ip/interface/dns1/dns2`

* `ip` and `ip6` is not compatible with each others! only use one.

```
update-extlinux
```

```
mkinitfs -i path/to/initramfs-dropbear <Kernel Version(from /lib/modules) incase in emergency CD>
```