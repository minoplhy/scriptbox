# alpine-initramfs-ipv6

ipv6 on alpinelinux initramfs

# /etc/mkinitfs/mkinitfs.conf
```
features+= ip
```
copy `features.d` `/etc/mkinitfs/features.d`