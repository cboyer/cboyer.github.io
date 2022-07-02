---
title: "Serveur web embarqué avec Kore"
date: "2022-07-02T14:30:12-04:00"
updated: "2022-07-02T14:30:12-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [Kore, C, serveur web, embarqué]
abstract: |
  Serveur web embarqué avec Kore.
---

Kore est un framework web en C intègrant son propre serveur web. Selon la configuration, il est même possible d'obtenir un seul binaire.

## Installation d'OpenSSL 1.1.1
Comme indiqué dans la documentation Kore n'est pas encore compatible avec OpenSSL version 3. Pour vérifier la version installé sur le système:
```
openssl version
OpenSSL 3.0.3 3 May 2022 (Library: OpenSSL 3.0.3 3 May 2022)
```

Compiler OpenSSL en version 1 et l'installer en marge de la version 3 dans `/tmp/openssl` (avec la variable `prefix`)
```
wget https://ftp.openssl.org/source/openssl-1.1.1p.tar.gz
tar zxvf openssl-1.1.1p.tar.gz
cd openssl-1.1.1p
./config --prefix=/tmp/openssl --openssldir=/tmp/openssl no-shared
make
make test
make install
```

Vérifier la nouvelle version
```
/tmp/openssl/bin/openssl version
OpenSSL 1.1.1p  21 Jun 2022 (Library: OpenSSL 1.1.1o  FIPS 3 May 2022)
```

## Compilation de Kore
```
wget https://kore.io/releases/kore-4.2.0.tar.gz
tar zxvf kore-4.2.0.tar.gz
cd kore-4.2.0
```

La compilation du binaire `kodev` ne tient pas compte de la variable `OPENSSL_PATH` contrairement au Makefile principal. Ceci aura pour effet d'utiliser le chemin par défaut et utiliser OpenSSL en version 3.
Pour corriger le problème il suffit d'ajouter le bloc suivant dans `kodev/Makefile`:
```
ifneq ("$(OPENSSL_PATH)", "")
	CFLAGS+=-I$(OPENSSL_PATH)/include
	LDFLAGS+=-L$(OPENSSL_PATH)/lib -lssl
endif
```

Compiler et installer Kore dans `/tmp/kore` avec la variable `prefix`:
```
OPENSSL_PATH="/tmp/openssl" PREFIX="/tmp/kore" make
PREFIX="/tmp/kore" make install
```

## Créer une application test
Pour utiliser les binaires fournis par Kore, ajouter `/tmp/kore/bin` dans `$PATH` avant de créer un nouveau projet `test`
```
export PATH="/tmp/kore/bin:$PATH"
kodev create test
cd test
```

Éditer le fichier `src/test.c` pour retourner un message dans la réponse HTTP
```C
#include <kore/kore.h>
#include <kore/http.h>

int		page(struct http_request *);

int
page(struct http_request *req)
{
	char * msg = "hello world";

	http_response(req, 200, msg, strlen(msg));
	return (KORE_RESULT_OK);
}
```

Configurer le routage dans `conf/test.conf` pour utiliser TLS sur localhost:8888 et localhost:8080 sans TLS
```
server tls {
	bind 127.0.0.1 8888
}
server notls {
    bind 127.0.0.1 8080
    tls no
}

load		./test.so

domain * {
	attach		notls
	route / {
		handler page
	}
}
domain * {
	attach		tls
	certfile	cert/server.pem
	certkey		cert/key.pem
	route / {
		handler page
	}
}
```

Compiler et démarrer l'application avec `kodev` puis tester avec `curl`:
```
kodev run

curl https://localhost:8888 -k
curl http://localhost:8080
```

## Liens complémentaires
- [https://wiki.openssl.org/index.php/Compilation_and_Installation](https://wiki.openssl.org/index.php/Compilation_and_Installation)
- [https://docs.kore.io/4.2.0/applications/koreconf.html](https://docs.kore.io/4.2.0/applications/koreconf.html)
