---
title: "Image Docker scratch avec Python"
date: "2026-03-14T15:06:14+01:00"
updated: "2026-03-14T15:06:14+01:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [docker, scratch, python]
abstract: "Créer une image Docker scratch contenant Python."
---

En complément de l'article précédent sur les images "distroless", voici comment se passer complètement des images fournies par Google.
L'idée principale est d'inclure le strict minimum pour obtenir une image minimaliste viable afin d'exécuter une application Python. 
Une application de ce type repose sur l'interpréteur Python et des librairies tierces (Polars, Flask, etc...). La problématique pourrait être facilement résolue avec l'utilisation des venv si ceux-ci étaient directement utilisable dans une image `scratch`.


## Python et ses dépendances
Pour visualiser les dépendances de l'interpréteur Python (ici en version 3.14):
```
ldd /usr/bin/python
        linux-vdso.so.1 (0x00007fb462031000)
        libpython3.14.so.1.0 => /lib64/libpython3.14.so.1.0 (0x00007fb461800000)
        libc.so.6 => /lib64/libc.so.6 (0x00007fb46160d000)
        libm.so.6 => /lib64/libm.so.6 (0x00007fb461f15000)
        /lib64/ld-linux-x86-64.so.2 (0x00007fb462033000)
```

Il est possible de lister les dépendances systèmes des imports en utilisant la variable d'environnement `LD_DEBUG=libs` lors de l'exécution d'une simple ligne qui importe les librairies requises:
```
LD_DEBUG=libs /usr/bin/python -c "import uuid"
     25207:     find library=libpython3.14.so.1.0 [0]; searching
     25207:      search cache=/etc/ld.so.cache
     25207:       trying file=/lib64/libpython3.14.so.1.0
     25207:
     25207:     find library=libc.so.6 [0]; searching
     25207:      search cache=/etc/ld.so.cache
     25207:       trying file=/lib64/libc.so.6
     25207:
     25207:     find library=libm.so.6 [0]; searching
     25207:      search cache=/etc/ld.so.cache
     25207:       trying file=/lib64/libm.so.6
     25207:
     25207:
     25207:     calling init: /lib64/ld-linux-x86-64.so.2
     25207:
     25207:
     25207:     calling init: /lib64/libc.so.6
     25207:
     25207:
     25207:     calling init: /lib64/libm.so.6
     25207:
     25207:
     25207:     calling init: /lib64/libpython3.14.so.1.0
     25207:
     25207:
     25207:     initialize program: /usr/bin/python
     25207:
     25207:
     25207:     transferring control: /usr/bin/python
     25207:
     25207:     find library=libuuid.so.1 [0]; searching
     25207:      search cache=/etc/ld.so.cache
     25207:       trying file=/lib64/libuuid.so.1
     25207:
     25207:
     25207:     calling init: /lib64/libuuid.so.1
     25207:
     25207:
     25207:     calling init: /usr/lib64/python3.14/lib-dynload/_uuid.cpython-314-x86_64-linux-gnu.so
     25207:
     25207:
     25207:     calling fini:  [0]
     25207:
     25207:
     25207:     calling fini: /lib64/libpython3.14.so.1.0 [0]
     25207:
     25207:
     25207:     calling fini: /lib64/libm.so.6 [0]
     25207:
     25207:
     25207:     calling fini: /usr/lib64/python3.14/lib-dynload/_uuid.cpython-314-x86_64-linux-gnu.so [0]
     25207:
     25207:
     25207:     calling fini: /lib64/libuuid.so.1 [0]
     25207:
     25207:
     25207:     calling fini: /lib64/libc.so.6 [0]
     25207:
     25207:
     25207:     calling fini: /lib64/ld-linux-x86-64.so.2 [0]
     25207:
```

Pour obtenir une liste épurée:
```
LD_DEBUG=libs /usr/bin/python -c "import uuid" 2>&1 | grep "calling init" | awk '{print $NF}'
/lib64/ld-linux-x86-64.so.2
/lib64/libc.so.6
/lib64/libm.so.6
/lib64/libpython3.14.so.1.0
/lib64/libuuid.so.1
/usr/lib64/python3.14/lib-dynload/_uuid.cpython-314-x86_64-linux-gnu.so
```

Nous pouvons mettre en évidence les librairies systèmes requise par les import (ici uuid) en comparant avec une exécution sans import:
```
LD_DEBUG=libs /usr/bin/python -c "" 2>&1 | grep "calling init" | awk '{print $NF}'
/lib64/ld-linux-x86-64.so.2
/lib64/libc.so.6
/lib64/libm.so.6
/lib64/libpython3.14.so.1.0
```

Le résultat est identique à la commande `ldd /usr/bin/python` à l'exception de `linux-vdso.so.1` qui un fichier particulier.
Il est à noter que les librairies systèmes possèdent des dépendances entre elles qui ne sont pas visibles avec notre méthode. L'outil `libtree` permet de visualiser ces liens:

```
libtree /usr/lib64/python3.14/lib-dynload/_uuid.cpython-314-x86_64-linux-gnu.so -vvv -p
/usr/lib64/python3.14/lib-dynload/_uuid.cpython-314-x86_64-linux-gnu.so 
├── /lib64/libuuid.so.1 [default path]
│   └── /lib64/libc.so.6 [default path]
│       └── /lib64/ld-linux-x86-64.so.2 [default path]
└── /lib64/libc.so.6 [default path]
    └── /lib64/ld-linux-x86-64.so.2 [default path]
```

## Construire l'image
Nous avons maintenant un moyen de déterminer l'ensemble des librairies systèmes requises pour l'exécution de notre application.
Il nous reste désormais à établir un Dockerfile intégrant la récupération de ces librairies (script `distroclean.sh`), notre application et ses imports (venv) ainsi que l'interpréteur et ses librairies standards.

L'arborescence de notre projet:
```
├── Dockerfile
├── requirements.txt
└── sources
    ├── distroclean.sh
    └── app.py
```

Script app.py:
```Python
import uuid
print("OK")
```

Le script distroclean.sh (qui prend en paramètre le chemin vers le venv):
```
#!/bin/bash
set -euo pipefail

OUTPUT="/tmp/package"
VENV_PATH=$(realpath "$1")

# Récupère les librairies appelées lors des imports dans chaque fichier source (en excluant le venv)
IMPORTS=$(find ~+ -type f -name "*.py" -not -path "$VENV_PATH/*" -print0 | xargs -0 grep -E "^import | import " | sort -u | awk '{print $2}' | paste -s -d ',')
LD_DEBUG=libs "$VENV_PATH/bin/python3" -c "import $IMPORTS" 2>&1 | grep "calling init" | awk '{print $NF}' | sort -u > /tmp/libs.txt

# Copie des librairies identifiées dans /tmp/package
while read f; do
  # Exclusion des librairies du venv car elles seront récupérées avec le venv au complet
  if [[ ! "$f" =~ ^"$VENV_PATH" ]]; then
    echo "$f"
    mkdir -p "$OUTPUT$(dirname $f)"
    cp $f "$OUTPUT$f"
  fi
done </tmp/libs.txt
```

Le Dockerfile:
```
FROM python:3.14.3-slim-trixie AS builder
RUN set -xe; \
    useradd --uid 10000 --home-dir /opt/app --shell /usr/bin/bash app; \
    apt-get update; \
    apt-get upgrade --yes

USER app
WORKDIR /opt/app
COPY --chown=app:app sources/ requirements.txt /opt/app/

RUN set -xe; \
    python3 -m venv /opt/app/venv; \
    /opt/app/venv/bin/python3 -m pip install --no-cache-dir -r requirements.txt; \
    bash distroclean.sh /opt/app/venv


FROM scratch
COPY<<EOF /etc/group
root:x:0:
app:x:10000:
EOF
COPY <<EOF /etc/passwd
root:x:0:0:root:/root:/sbin/nologin
app:x:10000:10000:app:/opt/app:/sbin/nologin
EOF

USER app
COPY --from=builder --chown=app:app --exclude=**/pip* --exclude=**/activate* --exclude=**/Activate* --exclude=**/*.sh --exclude=**/*.c --exclude=**/*.h --exclude=**/__pycache__ /opt/app /opt/app
COPY --from=builder --chown=app:app /tmp/package /
COPY --from=builder --chown=app:app --exclude=**/pip* /usr/local/lib/python3.14 /usr/local/lib/python3.14
COPY --from=builder --chown=app:app /usr/local/bin/python3 /usr/local/bin/python3

ENTRYPOINT ["/opt/app/venv/bin/python3", "app.py"]
```

Les fichiers `/etc/group` et `/etc/passwd` sont générés pour avoir un utilisateur autre que root car l'image scratch ne contient pas le nécessaire.
Par ailleurs il pourrait être nécessaire d'ajouter les certificats contenus dans `/etc/ssl/certs/` si votre application utilise SSL et également `/usr/share/zoneinfo/` pour les fuseaux horaires.

Construction de l'image:
```
docker build . -t scratch-python:1.0.0
```

Pour lancer l'interpréteur Python interactif depuis l'image générée et lancer l'application pour vérifier que tout fonctionne bien:
```
docker run --rm -it --entrypoint /opt/app/venv/bin/python3 scratch-python:1.0.0
exec(open("/opt/app/app.py").read())
```

L'image résultante occupe 27,3 Mo contre 41,3 Mo pour l'image parente `python:3.14.3-slim-trixie` et ne comprend rien d'autre que le nécessaire pour exécuter l'application (plus de gestionnaire Apt, Bash, etc.).

D'autres tests avec des applications plus complexes important des librairies comme Polars et Arrow montrent un gain d'espace de 130 Mo. Cette méthode reste utilisable pour d'autres exécutables que Python.


## Liens complémentaires
 - [Building Container Images FROM Scratch: 6 Pitfalls That Are Often Overlooked](https://labs.iximiuz.com/tutorials/pitfalls-of-from-scratch-images)
