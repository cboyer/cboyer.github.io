---
title: "Création de jails FreeBSD"
date: "2023-02-01T17:29:14-04:00"
updated: "2023-02-01T17:29:14-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [FreeBSD, jails]
abstract: "Créer une jail sous FreeBSD."
---


Avec un dataset ZFS (permet de bénéficier des fonctionnalités comme les snapshots)
```console
zfs create -o mountpoint=/jails zroot/jails
zfs create zroot/jails/testjail
```

Sans ZFS
```console
mkdir -p /jails/testjail
```

Installation des fichiers de base par menu interractif
```console
bsdinstall jail /jails/testjail
```

Sans le menu interractif
```console
fetch https://download.freebsd.org/ftp/releases/amd64/13.1-RELEASE/base.txz
tar -zxvf base.txz -C /jails/testjail
rm base.txz
freebsd-update -b /jails/testjail fetch install
```

Configuration de la jail
```console
echo "nameserver 192.168.1.1" > /jails/testjail/etc/resolv.conf
cp /usr/share/zoneinfo/Canada/Eastern /jails/testjail/etc/localtime
```

vi /jails/testjail/etc/rc.conf
```
host_hostname="testjail"
ifconfig_ng0_testjail="inet 192.168.1.30 netmask 255.255.255.0"
defaultrouter="192.168.1.1"
cron_flags="$cron_flags -J 15"
sendmail_enable="NONE"
sendmail_submit_enable="NO"
sendmail_outbound_enable="NO"
sendmail_msp_queue_enable="NO"
syslogd_flags="-c -ss"
ipv6_activate_all_interfaces="NO"
sshd_enable="YES"
```

vi /etc/jail.conf
```
# Configuration par défaut pour toutes les jails
path = "/jails/$name";
host.hostname = "$name.local.lkz";
exec.clean;
exec.start = "/bin/sh /etc/rc";
exec.stop = "/bin/sh /etc/rc.shutdown";
exec.consolelog = "/var/log/jail_$name.log";
mount.devfs;
allow.raw_sockets;
allow.nomount;

# Réseau utilisant la même IP que l'hôte
ip4 = inherit;
ip6 = disable;

# Réseau avec une IP dédiée
#interface = "vtnet0";
#ip4.addr = 10.0.0.17;

# Réseau avec un bridge
#vnet; 
#vnet.interface = "ng0_$name";
#exec.prestart += "jng bridge $name vtnet0";
#exec.poststop += "jng shutdown $name";

# Configuration spécifique pour testjail
testjail {
  mount.fstab = "";
}
```

Création de la jail
```console
jail -c testjail
jls
JID  IP Address      Hostname                      Path
  1                  testjail.local.lkz            /jails/testjail
```

Lancer un shell dans la jail
```console
jexec testjail /bin/sh
```

Activer le service jail au démarrage
```console
sysrc jail_enable=YES
service jail start
```

## Liens complémentaires

 - [https://clinta.github.io/freebsd-jails-the-hard-way](https://clinta.github.io/freebsd-jails-the-hard-way)
 - [https://www.cyberciti.biz/faq/how-to-configure-a-freebsd-jail-with-vnet-and-zfs](https://www.cyberciti.biz/faq/how-to-configure-a-freebsd-jail-with-vnet-and-zfs)
