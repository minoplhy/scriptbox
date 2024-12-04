# Alpine Initramfs Dropbear
This script took a huge references from:

* [https://github.com/Deeplerg/fork-alpine-initramfs-dropbear](https://github.com/Deeplerg/fork-alpine-initramfs-dropbear)

* [https://github.com/mk-f/alpine-initramfs-dropbear](https://github.com/mk-f/alpine-initramfs-dropbear)

* [https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in](https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in)

This script is modified from [alpine/mkinitfs - initramfs-init.in](https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in)

significant changes:

* Add dropbear

* After unlocked, kill all remainings dropbear and nlplug-findfs process, so no struck process reached the system.

Please install `dropbear` before continuing

1. copy `dropbear/unlock_disk` to `/etc/dropbear/unlock_disk`
    * Also Make sure `/etc/dropbear/unlock_disk` is executable! else dropbear will exit with "failed child"W
2. copy `authorized_keys` to `/etc/dropbear/authorized_keys`
3. copy `features.d` to /`etc/mkinitfs/features.d`

Note: 
* if you're using Deeplerg/mk-f scripts before don't forget to change `unlock_disk` as i modified that one too.
* If you're using `grub` make sure to install `syslinux` and possibly checkout `/etc/default/grub` and commented CMDLINE that's conflicted with `update-extlinux` like `GRUB_CMDLINE_LINUX_DEFAULT` and `default_kernel_opts` after that `grub-mkconfig -o /boot/grub/grub.cfg`

### /etc/mkinitfs.conf
```
features="ata base ide scsi usb virtio ext4 cryptsetup keymap dropbear network"
```
* features+= `dropbear` `network`

### /etc/update-extlinux.conf
```
modules=sd-mod,usb-storage,ext4,ata_piix,virtio_net,e1000e,virtio_pci
```
* if network is not working (/sys/class/net/*/address not found etc.) try adding `e1000e` or `virtio_net` `virtio_pci`

```
default_kernel_opts="cryptroot=UUID=xxx cryptdm=root quiet rootfstype=ext4 dropbear=<dropbear_port> ip=<ip>>"
```
* ip= can be both static and dhcp(if supported) `ip=<ip>::<gw>:<mask>::<interface>` `ip=dhcp`


```
update-extlinux
```

```
mkinitfs -i path/to/initramfs-dropbear <Kernel Version(from /lib/modules) incase in emergency CD>
```

## Full Diff:
```diff
325a326,340
> setup_dropbear() {
>       local port="${KOPT_dropbear}"
>       local keys=""
> 
>       # set the unlock_disc script as shell for root
>       sed -i 's|\(root:x:0:0:root:/root:\).*$|\1/etc/dropbear/unlock_disk|' /etc/passwd
>       echo '/etc/dropbear/unlock_disk' > /etc/shells
> 
>       # transfer authorized_keys
>       mkdir /root/.ssh
>       cp /etc/dropbear/authorized_keys /root/.ssh/authorized_keys
> 
>       dropbear -R -E -s -j -k -p $port
> }
> 
512a528
>       dropbear
641c657,665
< if [ -n "$KOPT_cryptroot" ]; then
---
> if [ -n "$KOPT_dropbear" ]; then
>       if [ -n "$KOPT_cryptroot" ]; then
>               configure_ip
>               setup_dropbear
>       fi
> fi
> 
> # Add Workaround for dropbear
> if [ -n "$KOPT_cryptroot" ] && [ ! -b /dev/mapper/"${KOPT_cryptdm}" ]; then
705a730,733
>       # Kill all struck nlplug-findfs jobs and dropbear
>       killall -9 nlplug-findfs
>       killall -9 dropbear
> 
781a810,813
> 
>       # Kill all struck nlplug-findfs jobs and dropbear
>       killall -9 nlplug-findfs
>       killall -9 dropbear
```