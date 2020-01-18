---
title: "Filtrer les publicités avec un serveur DNS Unbound"
date: "2018-05-04T17:56:14-04:00"
updated: "2018-11-01T18:08:32-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [dns, publicité, unbound, linux]
abstract: |
  Utiliser un serveur DNS Unbound pour filtrer les noms de domaine de régies publicitaires.
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
	interface: 0.0.0.0
	verbosity: 1
	use-syslog: yes
	username: "unbound"
	directory: "/etc/unbound"
	pidfile: "/var/run/unbound/unbound.pid"
	logfile: "/var/log/unbound/unbound.log"
	include: /etc/unbound/local.conf
	include: /etc/unbound/blacklist.conf
	log-time-ascii: yes
	do-ip4: yes
        do-ip6: no
        do-udp: yes
        do-tcp: yes
        do-daemonize: yes
	so-sndbuf: 8m
	msg-cache-size: 8m
	rrset-cache-size: 8m
	cache-min-ttl: 3600s
	cache-max-ttl: 86400
	cache-max-negative-ttl: 86400

remote-control:
        control-enable: no

forward-zone:
	name: "."
	forward-addr: 1.1.1.1@853
	forward-addr: 1.0.0.1@853
   	forward-ssl-upstream: yes
	#forward-addr: 80.67.169.12
	#forward-addr: 80.67.169.40
```

Vous trouverez la description de tous ces paramètres dans la documentation officielle d'Unbound: [https://www.unbound.net/documentation/unbound.conf.html](https://www.unbound.net/documentation/unbound.conf.html)

Pour résumer, Unbound fait office de cache DNS en résolvant les requêtes avec les DNS Cloudflare (connexion sécurisée par TLS). Les deux autres adresses commentées correspondent aux serveurs DNS de la [FDN](https://www.fdn.fr/actions/dns) dans le cas où vous ne feriez pas confiance à Cloudflare. Les DNS de Google sont vraiment à éviter pour des raisons évidentes.

Le fichier `/etc/unbound/local.conf` contiendra nos entrées locales, par exemple:

```console
local-zone: "serveur" redirect
local-data: "serveur A 192.168.10.100"

local-zone: "patate" redirect
local-data: "patate A 192.168.10.12"
```

Le fichier `/etc/unbound/blacklist.conf` contiendra les domaines à bloquer.
Pour cela, je vous propose les listes de Steven Black qui sont tenues à jour fréquemment et disponibles sur son dépôt Github: [https://github.com/StevenBlack/hosts](https://github.com/StevenBlack/hosts).
Le problème est que le formatage de cette liste est adapté pour un fichier hosts et non pour Unbound.
Remédions à la situation avec un simple script Bash:


```bash
#!/bin/bash

wget https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts
egrep '^0.0.0.0' hosts | awk '{print $2}' | sed '1d' | sed -e 's/^/local-zone: "/' | sed -e 's/$/" refuse/' > /etc/unbound/blacklist.conf
rm -f hosts

```

Adaptez l'URL selon votre choix parmi les différentes listes disponibles. Ce script peut parfaitement être ajouté dans la crontab pour une synchronisation régulière: pour cela ajoutez un redémarrage du service en dernière ligne.


Pour redémarrer Unbound:

```console
systemctl restart unbound
```

Il ne reste plus qu'à faire pointer vos clients vers le serveur DNS en ajoutant l'adresse IP dans la configuration de vos machines et/ou dans votre DHCP (routeur).


## Sources:

 - [https://etherarp.net/build-an-adblocking-dns-server/index.html](https://etherarp.net/build-an-adblocking-dns-server/index.html)
 - [https://wiki.archlinux.org/index.php/unbound](https://wiki.archlinux.org/index.php/unbound)
 - [https://www.unbound.net/documentation/unbound-control.html](https://www.unbound.net/documentation/unbound-control.html)
 - [https://github.com/StevenBlasck/hosts](https://github.com/StevenBlasck/hosts)
