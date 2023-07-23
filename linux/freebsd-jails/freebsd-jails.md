---
title: "Création de jails FreeBSD"
date: "2023-02-01T17:29:14-04:00"
updated: "2023-03-19T22:28:14-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [FreeBSD, jails, bastille, bastillebsd]
abstract: "Créer une jail sous FreeBSD."
---


## Jails avec les outils de base du système

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

Installer des paquets depuis l'hôte
```
pkg -j testjail install -y nginx
sysrc -j testjail "nginx_enable"=YES
service -j testjail nginx start
```

Activer le service jail au démarrage
```console
sysrc jail_enable=YES
service jail start
```


## Jails avec Bastille

Installer Bastille
```console
pkg install bastille
```

Créer le dataset zroot/bastille (utilisé dans la configuration Bastille via `bastille_zfs_prefix`)
```
zfs create -o mountpoint=/usr/local/bastille zroot/bastille
```

Pour démarrer automatiquement les Jails Bastille ajouter dans `/etc/rc.conf`
```console
sysrc bastille_enable=YES
```

Configuration de Bastille
```console
mkdir -p /usr/local/etc/bastille/
vi /usr/local/etc/bastille/bastille.conf
```

```text
# Chemin par défaut
bastille_prefix=/usr/local/bastille
bastille_backupsdir=${bastille_prefix}/backups
bastille_cachedir=${bastille_prefix}/cache
bastille_jailsdir=${bastille_prefix}/jails
bastille_logsdir=${bastille_prefix}/logs
bastille_releasesdir=${bastille_prefix}/releases
bastille_templatesdir=${bastille_prefix}/templates

# bastille scripts directory (assumed by bastille pkg)
bastille_sharedir=/usr/local/share/bastille

# Archive pour les bootstraps (base, lib32, ports, src, test)
bastille_bootstrap_archives="base"

# Fuseau horaire, par défaut "Etc/UTC"
bastille_tzdata="America/Montreal"

# default jail resolv.conf
bastille_resolv_conf="/etc/resolv.conf"

# bootstrap urls
bastille_url_freebsd="http://ftp.freebsd.org/pub/FreeBSD/releases/"
bastille_url_hardenedbsd="https://installer.hardenedbsd.org/pub/HardenedBSD/releases/"

# ZFS options
bastille_zfs_enable="YES"                                             # default: ""
bastille_zfs_zpool="zroot"                                            # default: ""
bastille_zfs_prefix="bastille"                                        # default: "${bastille_zfs_zpool}/bastille"
bastille_zfs_options="-o compress=lz4 -o atime=off"

# Export/Import options
bastille_compress_xz_options="-0 -v"
bastille_decompress_xz_options="-c -d -v"

# Networking
bastille_network_loopback="bastille0"
bastille_network_shared=""
bastille_network_gateway=""
```

Cloner l'interface lo pour l'utiliser comme interface dédiée (bastille0) à la jail 
```console
sysrc cloned_interfaces+=lo1
sysrc ifconfig_lo1_name="bastille0"
service netif cloneup
```

Configurer le parfeu dans `/etc/pf.conf` pour autoriser le traffic entrant sur 22/tcp pour bastille0 et bloquer le reste
```console
ext_if="vtnet0"

set block-policy return
scrub in on $ext_if all fragment reassemble
set skip on lo

table <jail> persist
nat on $ext_if from <jail> to any -> ($ext_if:0)
rdr-anchor "rdr/*"

block in all
pass out quick keep state
antispoof for $ext_if inet
pass in inet proto tcp from any to any port ssh flags S/SA keep state
```

Active et démarrer pf
```console
sysrc pf_enable=YES
service pf start
```

Récupérer l'image de base FreeBSD et créer la jail `bastille_test`
```console
bastille bootstrap 13.1-RELEASE update
bastille create bastille_test 13.1-RELEASE 192.168.122.55

bastille list
JID             IP Address      Hostname                      Path
bastille_test   192.168.122.55  bastille_test                 /usr/local/bastille/jails/bastille_test/root
```

Activer SSH
```console
bastille sysrc bastille_test sshd_enable=YES
bastille service bastille_test sshd start
```

Rendre SSH accessible depuis le réseau externe sur le port 222 en utilisant l'adresse IP de l'hôte
```console
bastille rdr bastille_test tcp 222 22
bastille rdr bastille_test list
# Retournera: 
# rdr pass on vtnet0 inet proto tcp from any to any port = 222 -> 192.168.122.55 port 22
```

Rentrer dans la jail
```console
bastille console bastille_test
```

Créer le template `htop`
```console
mkdir -p /usr/local/bastille/templates/cboyer/htop
vi /usr/local/bastille/templates/cboyer/htop/Bastillefile
```

```text
SYSRC sshd_enable=YES
SERVICE sshd start
PKG htop
```

Appliquer le template `htop` à `bastille_test` (pour appliquer le template à toutes les jails: utiliser `ALL` au lieu de `bastille_test`)
```console
bastille template bastille_test cboyer/htop
```

Exécuter `htop` depuis l'hôte
```console
bastille htop bastille_test
```


## Liens complémentaires

 - [https://clinta.github.io/freebsd-jails-the-hard-way](https://clinta.github.io/freebsd-jails-the-hard-way)
 - [https://www.cyberciti.biz/faq/how-to-configure-a-freebsd-jail-with-vnet-and-zfs](https://www.cyberciti.biz/faq/how-to-configure-a-freebsd-jail-with-vnet-and-zfs)
 - [https://bastille.readthedocs.io/en/latest/chapters/usage.html](https://bastille.readthedocs.io/en/latest/chapters/usage.html)
 - [https://bastille.readthedocs.io/en/latest/chapters/template.html](https://bastille.readthedocs.io/en/latest/chapters/template.html)
 - [https://github.com/DtxdF/AppJail](https://github.com/DtxdF/AppJail)
 - [https://vermaden.wordpress.com/2023/06/28/freebsd-jails-containers/](https://vermaden.wordpress.com/2023/06/28/freebsd-jails-containers/)
 
