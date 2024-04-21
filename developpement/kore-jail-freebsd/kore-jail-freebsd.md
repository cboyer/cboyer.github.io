---
title: "Application web Kore et jail FreeBSD"
date: "2024-04-21T17:13:12-04:00"
updated: "2024-04-21T17:13:12-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [Kore, FreeBSD, jail, C,serveur web]
abstract: "Application web Kore et jail FreeBSD."
---

Kore est un framework web en C intègrant son propre serveur web qui permet d'obtenir un seul binaire. Il peut être utilisé dans une jail "allégée" sous FreeBSD 14.
Notons qu'il est possible de compiler Kore avec OpenSSL 3.


## Préparation de l'environnement
Dans /etc/pkg/FreeBSD.conf configurer le dépôt latest pour bénéficier des dernières version:
```
FreeBSD: {
  url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest",
  mirror_type: "srv",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: yes
}
```


Application des mises à jour:
```
freebsd-update fetch install && pkg update && pkg upgrade && pkg audit -F
```


Installation des outils nécessaires pour compiler Kore et clonage du dépôt officiel:
```
pkg install git-tiny gmake openssl
git clone https://git.kore.io/kore.git
cd kore
```


Retirer l'option `-std=gnu99` des CFLAGS du `Makefile` et `kodev/Makefile` pour permettre la compilation avec Clang.
Lancer la compilation de Kore avec:
```
gmake
```


## Création du projet Kore

Créer le projet "test" via kodev:
```
./kodev/kodev create test
```


Modifier le programme `test/src/test.c` pour retourner la chaîne "hello world":
```
#include <kore/kore.h>
#include <kore/http.h>

int page(struct http_request *);

int page(struct http_request *req) {
    char * msg = "hello world";

    http_response_header(req, "content-type", "text/html");
    http_response(req, 200, msg, strlen(msg));
    return (KORE_RESULT_OK);
}
```


Préparer la configuration du projet dans `test/conf/test.conf`:
```
server tls {
    bind 0.0.0.0 8888
}
server notls {
    bind 0.0.0.0 8080
    tls no
}

tls_dhparam     /app/ffdhe4096.pem
rand_file       random.data
pidfile         /var/run/kore.pid
http_server_version kore

domain * {
    attach      notls
    accesslog	/var/log/kore_access.log
    route / {
        handler page
    }
}
domain * {
    attach      tls
    accesslog	/var/log/kore_access_tls.log
    # Ne pas spécifier cert/ car keymgr sera chrooté
    certfile    server.pem
    certkey     key.pem
    route / {
        handler page
    }
}

privsep worker {
        runas           kore
        root            /app/htdocs
}

privsep keymgr {
        runas           kore
        root            /app/cert
}
```


Modifier les paramètres de compilation du projet en changeant les valeurs `single_binary` et `kore_source` dans `test/conf/build.conf`
```
# test build config
# You can switch flavors using: kodev flavor [newflavor]

# Set to yes if you wish to produce a single binary instead
# of a dynamic library. If you set this to yes you must also
# set kore_source together with kore_flavor.
single_binary=yes
kore_source=/root/kore/
#kore_flavor=

# The flags below are shared between flavors
cflags=-Wall -Wmissing-declarations -Wshadow
cflags=-Wstrict-prototypes -Wmissing-prototypes
cflags=-Wpointer-arith -Wcast-qual -Wsign-compare

cxxflags=-Wall -Wmissing-declarations -Wshadow
cxxflags=-Wpointer-arith -Wcast-qual -Wsign-compare

# Mime types for assets served via the builtin asset_serve_*
#mime_add=txt:text/plain; charset=utf-8
#mime_add=png:image/png
#mime_add=html:text/html; charset=utf-8

dev {
        # These flags are added to the shared ones when
        # you build the "dev" flavor.
        cflags=-g
        cxxflags=-g
}

#prod {
#       You can specify additional flags here which are only
#       included if you build with the "prod" flavor.
#}
```


Compiler le projet pour obtenir le binaire `test`:
```
cd test
../kodev/kodev build
```


## Configuration de la jail
Créer l'arborescence:
```
mkdir -p /usr/local/jail/www/{app,dev,lib,libexec,var,tmp,etc}
mkdir -p /usr/local/jail/www/var/{log,run}
mkdir -p /usr/local/jail/www/usr/lib
mkdir -p /usr/local/jail/www/app/htdocs
```


Copier les librairies nécessaires du système pour permettre l'exécution de Kore:
```
cp /libexec/ld-elf.so.1 /usr/local/jail/www/libexec/
cp /lib/{libc.so.7,libgcc_s.so.1,libm.so.5,libthr.so.3,libcrypto.so.30} /usr/local/jail/www/lib/
cp /usr/lib/libssl.so.30 /usr/local/jail/www/usr/lib
cp /lib/libutil.so.9 /usr/local/jail/www/lib/ # Pour daemon
```

Copier les fichiers du projet:
```
cp /usr/sbin/daemon /usr/local/jail/www/app
cp test /usr/local/jail/www/app/
cp ../misc/ffdhe4096.pem /usr/local/jail/www/app/
cp -r cert /usr/local/jail/www/app/
openssl rand 1024 > /usr/local/jail/www/app/htdocs/random.data
openssl rand 1024 > /usr/local/jail/www/app/cert/random.data
chown -R 1001:1001 /usr/local/jail/www/app/{cert,htdocs}
```

Le fichier `random.data` doit être présent dans chaque dossier htdocs et cert à cause du chroot appliqué aux processus keymgr et worker. Il faut également attribuer les droits de lecture/écriture sur ces mêmes dossiers et leurs contenus pour l'utilisateur 1001, autrement cela causera l'erreur: failed to unlink random.data: Permission denied.

Arborescence obtenue:
```
/usr/local/jail/www/
├── app
│   ├── cert
│   │   ├── key.pem
│   │   ├── random.data
│   │   └── server.pem
│   ├── daemon
│   ├── ffdhe4096.pem
│   ├── htdocs
│   │   └── random.data
│   └── test
├── dev
├── etc
├── ld-elf.so.1
├── lib
│   ├── libc.so.7
│   ├── libcrypto.so.30
│   ├── libgcc_s.so.1
│   ├── libm.so.5
│   ├── libthr.so.3
│   └── libutil.so.9
├── libexec
│   └── ld-elf.so.1
├── tmp
├── usr
│   └── lib
│       └── libssl.so.30
└── var
    ├── log
    └── run
```



Configuration de la jail www dans `/etc/jail.conf`:
```
www {
  host.hostname = "www";
  ip4 = inherit;
  #ip4.addr = "vtnet0|192.168.122.100/24";
  path = "/usr/local/jail/www";
  sysvshm = "new";
  exec.start = "/app/daemon -r \
                -P /var/run/daemon.pid
                -o /var/log/kore.log \
                /app/test";
  exec.stop = "";
}
```

Nous utilisons `daemon` pour permettre un redémarrage automatique de Kore et récupérer stdout/stderr dans un fichier dédié.
Kore utilisant la fonction `shmget()` à l'initialisation des workers, il est nécessaire d'utiliser `sysvshm = "new"`. Ce paramètre est à préférer à `allow.sysvipc = 1` afin de donner à la jail un namespace dédié et réduire les risques de sécurité.


Kore utilise la fonction `getpwuid()` qui nécessite la présence du fichier `passwd` dans la jail, pour le générer:
```
echo "root::0:0::0:0:Charlie &:/root:/bin/sh" > passwd
echo "kore::1001:1001::0:0:kore:/app:/bin/sh" >> passwd
pwd_mkdb -d /usr/local/jail/www/etc/ -p passwd
```

Démarrer la jail:
```
sysrc jail_enable=YES
service jail start www
```

Le journal devrait contenir les informations de démarrage:
```
cat /usr/local/jail/www/var/log/kore.log

2024-04-21 00:12:54.674 UTC proc=[parent] log=[tls serving https on 0.0.0.0:8888]
2024-04-21 00:12:54.674 UTC proc=[parent] log=[notls serving http on 0.0.0.0:8080]
2024-04-21 00:12:54.674 UTC proc=[parent] log=[test master-6fbb6d18 starting, built=2024-04-20]
2024-04-21 00:12:54.674 UTC proc=[parent] log=[memory pool protections: disabled]
2024-04-21 00:12:54.674 UTC proc=[parent] log=[built-ins: ]
2024-04-21 00:12:54.674 UTC proc=[parent] log=[TLS backend OpenSSL 3.0.12 24 Oct 2023]
2024-04-21 00:12:54.674 UTC proc=[parent] log=[starting worker processes]
2024-04-21 00:12:54.995 UTC proc=[parent] log=[all worker processes started]
2024-04-21 00:12:54.995 UTC proc=[parent] log=[accesslog vacuum is enabled]
2024-04-21 00:12:54.995 UTC proc=[keymgr] log=[(re)loading certificates, keys and CRLs]
2024-04-21 00:12:54.995 UTC proc=[keymgr] log=[loaded private key for '*']
2024-04-21 00:12:54.995 UTC proc=[keymgr] log=[started (#14033 chroot=/app/cert user=kore)]
2024-04-21 00:12:54.995 UTC proc=[wrk 1] log=[started (#14031 chroot=/app/htdocs user=kore)]
2024-04-21 00:12:54.997 UTC proc=[wrk 2] log=[started (#14032 chroot=/app/htdocs user=kore)]
```

Tester via curl (modifier l'adresse IP au besoin):
```
curl https://192.168.122.100:8888 -k
curl http://192.168.122.100:8080
```

## Liens complémentaires
- [https://git.kore.io/kore/file/conf/kore.conf.example](https://git.kore.io/kore/file/conf/kore.conf.example)
- [https://gist.github.com/hiway/2b526fc64748e8d6e9f36f289003f843](https://gist.github.com/hiway/2b526fc64748e8d6e9f36f289003f843)
- [https://www.skyforge.at/posts/a-note-in-sysvipc-and-jails-on-freebsd](https://www.skyforge.at/posts/a-note-in-sysvipc-and-jails-on-freebsd)
