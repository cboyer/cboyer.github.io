---
title: "Ajouter l'authentification LDAP à NGINX"
date: "2018-05-31T19:14:12-04:00"
updated: "2018-11-01T18:08:32-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [nginx, ldap, authentification, linux]
abstract: |
  Ajout du support LDAP en compilant le module d'authentification LDAP avec la version open source d'NGINX.
---

La version gratuite de NGINX n'intègre pas le module d'authentification via LDAP par défaut. Pour y remédier, il faut passer par une compilation des sources avec le module `nginx-auth-ldap`.

Récupérer le module:

```console
cd /tmp
git clone https://github.com/kvspb/nginx-auth-ldap
cd nginx-auth-ldap
```

La dernière version comporte un bogue qui empêche l'authentification selon un groupe et provoque l'erreur "*Bad search filter*" (cf. sources en bas de page). Pour contourner le problème, on rolllback à un commit ultérieur:

```console
git checkout 5fd5a40851d8b7c1ba832b893d369a51825ff720
```

Téléchargeons les sources pour NGINX, compilons-les et installons le programme:
```console
wget http://nginx.org/download/nginx-1.14.0.tar.gz
tar zxvf nginx-1.14.0.tar.gz
cd nginx-1.14.0
./configure --add-module=/tmp/nginx-auth-ldap/ --with-http_ssl_module --with-http_v2_module
make
sudo make install
```

Après compilation, NGINX s'installe dans `/usr/local/nginx`.

Intègrons NGINX à systemd avec le fichier `/usr/lib/systemd/system/nginx.service`:

```ini
[Unit]
Description=nginx - high performance web server
Documentation=http://nginx.org/en/docs/
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID

[Install]
WantedBy=multi-user.target
```

On recharge les fichiers services:

```console
sudo systemctl daemon-reload
```

Pour la suite, il suffit de suivre la documentation du module et modifier le fichier `/usr/local/nginx/conf/nginx.conf`.

## Sources

 - [https://github.com/kvspb/nginx-auth-ldap/issues/180](https://github.com/kvspb/nginx-auth-ldap/issues/180)
 - [https://github.com/kvspb/nginx-auth-ldap](https://github.com/kvspb/nginx-auth-ldap)
