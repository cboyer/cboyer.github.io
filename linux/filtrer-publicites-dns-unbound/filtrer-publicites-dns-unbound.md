---
title: "Filtrer les publicités avec un serveur DNS Unbound"
date: "2018-05-04T17:56:14-04:00"
updated: "2022-02-03T17:42:32-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [dns, publicité, unbound, linux]
abstract: "Utiliser un serveur DNS Unbound pour filtrer les noms de domaine de régies publicitaires."
---

Les publicités sont devenues depuis quelques années une véritable plaie sur Internet. Rares sont les sites et autres blogues qui en sont exempts, l'appât du gain ouvrant grand les portes à la monétisation. Ce qui est d'autant plus dérangeant c'est qu'elles ne se limitent plus à afficher (de manière intempestive ou non) un produit quelconque: les régies publicitaires ciblent des annonces en fonctions des données accessibles depuis votre navigateur (cookies, user-agent, recoupement avec d'autres données, etc.).

Il existe des moyens de contrer ce fléau avec des plugins s'installant dans votre navigateur comme AdBlock, uBlock Origin ou encore Disconnect.
Une autre alternative est possible: filtrer la source de ces annonces avec un serveur de noms (DNS) local. Une suite d'outils pour Raspberry Pi reposant sur ce concept à même vu le jour: [Pi-Hole](https://pi-hole.net). Ainsi, vous accélérez votre navigation en ne téléchargeant plus les données associées aux publicités.

Nous allons voir comment monter son propre serveur DNS local avec Unbound pour filtrer les indésirables.
Commençons par installer le package Unbound dépendamment de votre distribution (en root):

```console
dnf install unbound
apt-get install unbound
yum install unbound
```

La configuration d'Unbound `/etc/unbound/unbound.conf`:

```yaml
server:
        username: unbound
        directory: /etc/unbound
        chroot: /etc/unbound
        pidfile: /var/run/unboun/unbound.pid
        interface: 0.0.0.0
        port: 53
        module-config: "validator iterator"
        access-control: 127.0.0.1 allow
        access-control: 192.168.10.0/24 allow
        unblock-lan-zones: no
        insecure-lan-zones: no
        domain-insecure: "mondomaine.local."
        aggressive-nsec: yes
        cache-max-ttl: 86400s
        cache-max-negative-ttl: 86400s
        msg-cache-size: 32m
        neg-cache-size: 32m
        rrset-cache-size: 32m
        rrset-roundrobin: yes
        #num-threads: 4
        #logfile: unbound.log
        verbosity: 1
        log-time-ascii: yes
        val-log-level: 2
        use-syslog: no
        do-ip4: yes
        do-ip6: no
        do-tcp: yes
        do-udp: yes
        do-daemonize: no
        hide-identity: yes
        hide-version: yes
        qname-minimisation: yes
        minimal-responses: yes
        harden-glue: yes
        harden-dnssec-stripped: yes
        disable-dnssec-lame-check: yes
        prefetch: yes
        prefetch-key: yes
        val-clean-additional: yes
        unwanted-reply-threshold: 10000
        tls-cert-bundle: "/usr/local/share/certs/ca-root-nss.crt"
        ssl-cert-bundle: "/usr/local/share/certs/ca-root-nss.crt"
        use-caps-for-id: yes
        include: local.d/blacklist.conf
        include: local.d/lan.conf

remote-control:
        control-enable: yes
        control-interface: 127.0.0.1
        control-use-cert: no

forward-zone:
        name: "."
        #forward-ssl-upstream: yes
        forward-tls-upstream: yes
        #forward-addr: 1.1.1.1@853#Cloudflare.com
        #forward-addr: 1.0.0.1@853#Cloudflare.com
        #forward-addr: 8.8.8.8@853#Google.com
        #forward-addr: 80.241.218.68@853#fdns1.dismail.de
        #forward-addr: 159.69.114.157@853#fdns2.dismail.de
        #forward-addr: 146.255.56.98@853#dot1.applied-privacy.net
        forward-addr: 116.202.176.26@853#dot.libredns.gr

include: /var/unbound/conf.d/*.conf	
```

> Sous FreeBSD il faut définir `do-daemonize: yes` pour ne pas bloquer le démarrage du système. Installer également `security/ca_root_nss` pour `/usr/local/share/certs/ca-root-nss.crt` (dont `/etc/ssl/cert.pem` est un lien symbolique).



Vous trouverez la description de tous ces paramètres dans la documentation officielle d'Unbound: [https://www.unbound.net/documentation/unbound.conf.html](https://www.unbound.net/documentation/unbound.conf.html)

Pour résumer, Unbound fait office de cache DNS en résolvant les requêtes avec le DNS LibreDNS (connexion sécurisée par TLS). Les DNS de Google/Cloudflare sont vraiment à éviter pour des raisons évidentes.

Le fichier `/etc/unbound/local.d/lan.conf` contiendra nos entrées locales, par exemple:

```console
local-zone: "mondomaine.local." transparent
local-data: "host1.mondomaine.local IN A 192.168.10.114"

local-zone: "serveur" redirect
local-data: "serveur A 192.168.10.104"

local-zone: "patate" redirect
local-data: "patate A 192.168.10.12"
```

Le fichier `/etc/unbound/local.d/blacklist.conf` contiendra les domaines à bloquer.
Pour cela, je vous propose les listes de Steven Black qui sont tenues à jour fréquemment et disponibles sur son dépôt Github: [https://github.com/StevenBlack/hosts](https://github.com/StevenBlack/hosts).
Le problème est que le formatage de cette liste est adapté pour un fichier hosts et non pour Unbound.
Remédions à la situation avec un simple script Bash:


```bash
#!/bin/bash

curl -s https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts | grep "^0.0.0.0" | awk '{ print "local-zone: \"" $2 "\" redirect\nlocal-data: \"" $2 " A 127.0.0.1\""  }' > /etc/unbound/local.d/blacklist.conf
unbound-control reload
```

Adaptez l'URL selon votre choix parmi les différentes listes disponibles. Ce script peut parfaitement être ajouté dans la crontab pour une synchronisation régulière: pour cela ajoutez un redémarrage du service en dernière ligne.


Pour redémarrer Unbound:

```console
systemctl restart unbound
```

> Sur certains système Linux, un service écoute déjà sur le port 53: `systemd-resolved`, pour le désactiver/arrêter: `systemctl disable systemd-resolved && systemctl stop systemd-resolved`.

Pour envoyer depuis un client des requêtes DNS afin de tester la configuration:
```console
dig @192.168.45.123 patate +short
```

Il ne reste plus qu'à faire pointer vos clients vers le serveur DNS en ajoutant l'adresse IP dans la configuration de vos machines et/ou dans votre DHCP (routeur).
```console
#Pour CentOS/Fedora
nmcli con mod enp1s0 ipv4.dns "192.168.45.123 192.168.45.122"
```

Les statistiques Unbound peuvent être consultés sur le serveur avec:
```console
unbound-control stats_noreset
```


## Liens complémentaires

 - [https://etherarp.net/build-an-adblocking-dns-server/index.html](https://etherarp.net/build-an-adblocking-dns-server/index.html)
 - [https://wiki.archlinux.org/index.php/unbound](https://wiki.archlinux.org/index.php/unbound)
 - [https://www.unbound.net/documentation/unbound-control.html](https://www.unbound.net/documentation/unbound-control.html)
 - [https://github.com/StevenBlasck/hosts](https://github.com/StevenBlasck/hosts)
