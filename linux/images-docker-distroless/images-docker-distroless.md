---
title: "Images Docker distroless pour Python, C et Rust"
date: "2025-12-10T15:28:14+01:00"
updated: "2025-12-10T15:28:14+01:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [docker, image, distroless, scratch, C, Python, Rust, pyinstaller, staticx]
abstract: "Construction d'images Docker distroless pour des applicatifs Python, C et Rust."
---

L'utilisation d'images Docker/OCI minimalistes permet non seulement de limiter l'espace disque utilisé ainsi que le temps de chargement et d'exécution mais réduit également la surface d'attaque. En revanche ces images présentent des limites concernant les possibilités de déboguage (absence de commandes standards, gestionnaire de paquet, shell, parties de l'arborescence, etc.).


## Utiliser l'image distroless Python fournie par Google
Google fournit [un ensemble d'image distroless](https://github.com/GoogleContainerTools/distroless) plutôt complet avec des variantes couvrant différents cas d'usage (Python, Java, etc.). Bien qu'étant appelées "distroless", ces images reposent en fait sur Debian tout en étant dégrossies au maximum.

Penchons-nous sur l'image Python `gcr.io/distroless/python3-debian12` (identique à `gcr.io/distroless/python3`). Cette image contient la version 3.11 de Python (assez ancienne à l'heure actuelle) sans librairie particulière ni la possibilité d'en compiler. 
```
docker run --rm gcr.io/distroless/python3-debian12:latest -c 'import platform; print(platform.python_version())'
3.11.2
```

Pour ajouter les librairies nécessaires au bon fonctionnement de l'applicatif, nous allons passer par la méthode de contruction d'image multi-stage. Nous ferons appel dans un premier temps à l'image `python:3.11-slim` alignée sur la même version que notre image distroless afin de créer un environnement Python virtuel (venv) compatible embarquant les librairies énumérées dans le `requirements.txt`.

Une fois l'environnement virtuel créé, il suffit de le copier dans l'image distroless et d'indiquer le chemin dans les variables `PYTHONPATH` et `PATH`:
```
FROM python:3.11-slim AS builder

COPY requirements.txt /opt/app/
WORKDIR /opt/app
RUN set -xe; \
    python3 -m venv /opt/app/venv; \
    /opt/app/venv/bin/python3 -m pip install --no-cache-dir -r requirements.txt


gcr.io/distroless/python3-debian12
ENV PYTHONPATH=/opt/app/venv/lib/python3.11/site-packages
ENV PATH="/opt/app/venv/bin:$PATH"

COPY --from=builder /opt/app/venv /opt/app/venv
COPY sources/ /opt/app
WORKDIR /opt/app
ENTRYPOINT ["python3", "/opt/app/app.py"]
```

Cette méthode n'est pas optimale car elle implique la duplication de fichiers amenés avec le venv. D'autre part la version 3.11 de Python n'est plus trop d'actualité et les images distroless ne proposent pas d'autre version.

Pour utiliser une version Python de notre choix il faut utiliser `pyinstaller` afin de construire un paquet exécutable contenant l'intégralité de l'applicatif, l'interpréteur et les librairies. Il est à noter que cet exécutable, bien que plus portable qu'un venv, n'est pas compilé statiquement et dépendra toujours de librairies externes comme Glibc qui devront être disponibles dans l'image distroless.

```
FROM python:3.14.2-slim-bookworm AS builder
WORKDIR /opt/app
COPY sources/ requirements.txt /opt/app/
RUN set -xe; \
    apt-get update; \
    apt-get install --yes --no-install-suggests --no-install-recommends binutils

RUN pip3 install --no-cache-dir --break-system-packages -r requirements.txt
RUN pyinstaller --name app_package --strip --optimize 2 --collect-all adbc_driver_manager --collect-all adbc_driver_postgresql --onefile app.py --add-data "logging.yml:."


FROM gcr.io/distroless/python3-debian12
COPY --from=builder --chmod=755 /opt/app/dist/app_package /app_package
ENTRYPOINT ["./app_package"]
```

Il faut veiller à utiliser une version de Debian (builder) alignée sur la version Debian de l'image distroless (ici Debian 12 Bookworm) autrement il y aura des disparités sur des librairies système comme Glibc ce qui causera des erreurs du type:
```
[PYI-7:ERROR] Failed to load Python shared library '/tmp/_MEIS1hqW6/libpython3.14.so.1.0': /lib/x86_64-linux-gnu/libm.so.6: version `GLIBC_2.38' not found (required by /tmp/_MEIS1hqW6/libpython3.14.so.1.0)
```

Le paramètre `--collect-all` permet de forcer pyinstaller à inclure les libraries qu'il ne détecte pas automatiquement. Le paramètre `--add-data` permet d'ajouter un fichier au paquet.


L'incovénient de cette méthode est qu'en utilisant l'image `gcr.io/distroless/python3-debian12` nos obtenons une image finale comprenant l'interpréteur Python 3.11. Il faudrait donc veiller à supprimer celui-ci avec une image intermédiaire supplémentaire pour en copier le contenu en excluant les fichiers Python 3.11 dans une image `scratch`.
Pour déterminer l'emplacement des fichier relatif à Python:
```
docker run --rm gcr.io/distroless/python3-debian12:latest -c 'import site; print(site.getsitepackages())'
['/usr/local/lib/python3.11/dist-packages', '/usr/lib/python3/dist-packages', '/usr/lib/python3.11/dist-packages']
```

Le Dockerfile incluant l'image `gcr.io/distroless/python3-debian12` sans Python 3.11:
```
FROM python:3.14.2-slim-bookworm AS builder
WORKDIR /opt/app
COPY sources/ requirements.txt /opt/app/
RUN set -xe; \
    apt-get update; \
    apt-get install --yes --no-install-suggests --no-install-recommends binutils

RUN pip3 install --no-cache-dir --break-system-packages -r requirements.txt
RUN pyinstaller --name app_package --strip --optimize 2 --collect-all adbc_driver_manager --collect-all adbc_driver_postgresql --onefile app.py --add-data "logging.yml:."

FROM scratch AS base
COPY --from=gcr.io/distroless/python3-debian12 --exclude=**/python3.11 --exclude=**/python3 / /

FROM base
COPY --from=builder --chmod=755 /opt/app/dist/app_package /app_package
ENTRYPOINT ["./app_package"]
```


Pour aller plus loin, il existe l'outil `staticx` qui permet l'édition de lien statique sur un exécutable (comme le paquet exécutable produit par `pyinstaller`) pour y inclure les librairies système et rendre possible l'utilisation d'image distroless plus minimaliste comme `scratch`. En revanche `staticx` ne semble pas aboutir à coup sûr dès lors que l'applicatif comprend certaines/trop de librairies Python.



## Utiliser l'image scratch et le langage C
L'utilisation du langage C passe par une étape de compilation avec édition de lien. Le soin est laissé au lecteur d'utiliser une image Docker intermédiaire pour la compilation du projet C.
On considère le programme C suivant `main.c`:

```C
#include <glib.h>

int main(void) {
    g_print ("OK\n");
    return 0;
}
```

Pour le compiler (nécessite le paquet `glib2-devel`):
```
gcc $(pkgconf --cflags glib-2.0) main.c $(pkgconf --libs glib-2.0) -o test
```

L'exécutable produit est dynamiquement lié aux librairies suivantes:
```
ldd test 
        linux-vdso.so.1 (0x00007efcb3d04000)
        libglib-2.0.so.0 => /lib64/libglib-2.0.so.0 (0x00007efcb3b8b000)
        libc.so.6 => /lib64/libc.so.6 (0x00007efcb3997000)
        libpcre2-8.so.0 => /lib64/libpcre2-8.so.0 (0x00007efcb38ea000)
        /lib64/ld-linux-x86-64.so.2 (0x00007efcb3d06000)
```

En l'état cet exécutable n'est pas utilisable dans l'image `scratch` qui est dépourvue de ces librairies. Pour les y ajouter il faut au préalable les copier dans le dossier courant (contexte Docker) puis utiliser la directive COPY dans le Dockerfile:
```
FROM scratch
COPY libglib-2.0.so.0 /lib64/libglib-2.0.so.0
COPY ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY libc.so.6 /lib64/libc.so.6
COPY libpcre2-8.so.0 /lib64/libpcre2-8.so.0
COPY --chmod=755 test /bin/
ENTRYPOINT ["test"]
```

Allons plus loin dans les options de compilation pour une édition de lien statique afin de rendre l'exécutable produit directement utilisable dans `scratch`, la plus minimaliste des images Docker. Pour compiler le programme (nécessite les paquets `glibc-static` et `glib2-static`):
```
gcc -s -static $(pkgconf --cflags glib-2.0) main.c $(pkgconf --static --libs glib-2.0) -o test
```

L'option `-s` pour "strip" permet de réduire la taille de l'exécutable. Après quelques warnings, on obtient un exécutable non dynamique:
```
ldd test 
        n'est pas un exécutable dynamique
```

Nous pouvons alors l'inclure dans l'image `scratch`:
```
FROM scratch
COPY test /opt/app/
WORKDIR /opt/app
ENTRYPOINT ["./test"]
```


## Utiliser l'image scratch et le langage Rust
Rust compile ses programmes avec un linking dynamique sur Glibc. Pour passer en statique il faut utiliser `musl`, une librairie C alternative qui permet l'édition de liens statique plus facile.
Le soin est laissé au lecteur d'utiliser une image Docker intermédiaire pour la compilation du projet Rust.

Installer la cible de compilation `x86_64-unknown-linux-musl`:
```
rustup target add x86_64-unknown-linux-musl
```

Dans le projet, éditer le fichier `Cargo.toml` pour y ajouter l'option `strip` dans la section `profile.release` afin de rendre l'exécutable produit plus léger:
```toml
[package]
name = "myapp"
version = "0.1.0"
edition = "2025"

[dependencies]
rayon = "1.11.0"
walkdir = "2.5.0"

[profile.release]
opt-level = 3
lto = true
codegen-units = 1
strip = true
```

Compiler le projet comme suit:
```
cargo build --release --target x86_64-unknown-linux-musl
```

Le Dockerfile pour produire une image à partir de `scratch`:
```
FROM scratch
COPY target/x86_64-unknown-linux-musl/release/myapp /opt/app/myapp
WORKDIR /opt/app
ENTRYPOINT ["./myapp"]
```


## Considérations légales concernant les exécutables statiques
L'édition de liens statique est discutable sur le plan technique (non abordé ici) mais également légal. En effet la licence de certaines librairies peuvent contraindre le développeur à publier son code source comme c'est le cas pour la librairie Glibc. Ce problème ne se pose pas pour musl qui est publiée sous licence MIT, plus permissive. Cependant musl peut amener des problèmes d'incompatibilité avec d'autres librairies qui dépendent fortement de Glibc.



## Liens complémentaires
 - [What's Inside Distroless Container Images: Taking a Closer Look](https://labs.iximiuz.com/tutorials/gcr-distroless-container-images)
 - [https://github.com/GoogleContainerTools/distroless](https://github.com/GoogleContainerTools/distroless)

