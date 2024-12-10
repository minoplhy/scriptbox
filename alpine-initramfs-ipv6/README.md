# alpine-initramfs-ipv6

This add ipv6 support for alpine initramfs.

# /etc/mkinitfs/mkinitfs.conf
```
features+= ip
```

* copy `features.d` `/etc/mkinitfs/features.d`

# /etc/update-extlinux.conf

```
ip6=client-ip/gateway-ip/interface/dns/dns
```