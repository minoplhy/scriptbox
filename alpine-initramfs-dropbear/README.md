# Alpine Dropbear Initramfs
This script took a huge references from:

* [https://github.com/Deeplerg/fork-alpine-initramfs-dropbear](https://github.com/Deeplerg/fork-alpine-initramfs-dropbear)

* [https://github.com/mk-f/alpine-initramfs-dropbear](https://github.com/mk-f/alpine-initramfs-dropbear)

* [https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in](https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in)

This script is modified from [alpine/mkinitfs - initramfs-init.in](https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in)

significant changes:

* Add dropbear

* Add dropbear session timer, this make typical decryption still works even if dropbear/network is broken

Please install `dropbear` before continuing

1. copy `dropbear/unlock_disk` to `/etc/dropbear/unlock_disk`
2. copy `authorized_keys` to `/etc/dropbear/authorized_keys`
3. copy `features.d` to /`etc/mkinitfs/features.d`

Note: if you're using Deeplerg/mk-f scripts before don't forget to change `unlock_disk` as i modified that one too.

### /etc/mkinitfs.conf
`features="ata base ide scsi usb virtio ext4 cryptsetup keymap dropbear network"`
* features+= `dropbear` `network`

### /etc/update-extlinux.conf
`modules=sd-mod,usb-storage,ext4,ata_piix,virtio_net,e1000e,virtio_pci`
* if network is not working (/sys/class/net/*/address not found etc.) try adding `e1000e` or `virtio_net` `virtio_pci`

`default_kernel_opts="cryptroot=UUID=xxx cryptdm=root quiet rootfstype=ext4 dropbear=<dropbear_port> ip=<ip>>"`
* ip= can be both static and dhcp(if supported) `ip=<ip>::<gw>:<mask>::<interface>` `ip=dhcp`


`update-extlinux`

`mkinitfs -i path/to/initramfs-dropbear <Kernel Version(from /lib/modules) incase in emergency CD>`

## Full Diff:
```diff
325a326,367
> setup_dropbear() {
> 	local port="${KOPT_dropbear}"
> 	local keys=""
> 
> 	# set the unlock_disc script as shell for root
> 	sed -i 's|\(root:x:0:0:root:/root:\).*$|\1/etc/dropbear/unlock_disk|' /etc/passwd
> 	echo '/etc/dropbear/unlock_disk' > /etc/shells
> 
> 	# transfer authorized_keys
> 	mkdir /root/.ssh
> 	cp /etc/dropbear/authorized_keys /root/.ssh/authorized_keys
> 
> 	dropbear -R -E -s -j -k -p $port
> 
> 	# [ -b /dev/mapper/${KOPT_cryptdm} ] 
> 	#|| return 1
> }
> 
> # A simple timer that do nothing but prevent any process to run
> setup_dropbear_timer() {
> 	timer=200
>     while [ $timer -gt 0 ]; do
>         printf "\r%d Press 'c' to cancel or 'p' to add 30 seconds " "$timer"
> 		
>         if read -t 1 -r timer_control; then
> 			case $timer_control in
> 				"c") return 0 ;;
> 				"p") timer=$((timer + 30)) ;;
> 			esac
>         fi
> 
> 		# Check for /tmp/timer_kill to terminate this counter
> 		if [ -f /tmp/timer_kill ]; then
> 			return 0
> 		fi
> 
>         sleep 1
>         timer=$((timer - 1))
>     done
> 	printf "\n"
> }
> 
453c495
< 	s390x_net dasd ssh_key BOOTIF zfcp uevent_buf_size aoe aoe_iflist aoe_mtu wireguard"
---
> 	s390x_net dasd ssh_key BOOTIF zfcp uevent_buf_size aoe aoe_iflist aoe_mtu wireguard dropbear"
581c623,633
< if [ -n "$KOPT_cryptroot" ]; then
---
> if [ -n "$KOPT_dropbear" ]; then
>  	if [ -n "$KOPT_cryptroot" ]; then
> 		configure_ip
>  		setup_dropbear
> 		setup_dropbear_timer
> 		#|| echo "Failed to setup dropbear"
>  	fi
> fi
> 
> # Add Workaround for dropbear
> if [ -n "$KOPT_cryptroot" ] && [ ! -b /dev/mapper/"${KOPT_cryptdm}" ]; then
1003c1055
< reboot
---
> reboot
\ No newline at end of file

```