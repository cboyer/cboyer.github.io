---
title: "Système de fichiers distribué GlusterFS"
date: "2016-10-30T14:24:16-04:00"
updated: "2018-11-04T11:04:32-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [gluster, glusterfs, dfs, système de fichiers distribué, linux]
abstract: |
  Configuration d'un volume GlusterFS sous CentOS.
---

GlusterFS est un système de fichiers distribué simple à mettre en place et possédant des fonctionnalitées avancées (snapshot, recovery, etc.) ainsi qu'une flexibilité (ajout/retrait de noeuds, nombre de noeuds, etc.) qui dépasse de loin ce que proposaient les anciennetés comme DRBD. GlusterFS est en fait une surcouche aux systèmes de fichiers (EXT4, XFS, etc.) car il ne travaille pas avec des périphériques de type block (block devices) pour stocker ses données mais des fichiers. C'est ce qui fait sa force pour sa flexibilité mais aussi sa faiblesse concernant les performances.

Installer les packages:

```console
yum install centos-release-gluster38
yum install glusterfs-server
```

Activer les services au démarrage et les démarrer:

```console
systemctl enable glusterd.service
systemctl start glusterd.service
```

Ajouter les noms des machines dans /etc/hosts pour utiliser les noms d'hôte (ou bien dans le serveur DNS).
Ajouter un noeud au pool (sur le noeud SERVEUR01A-GLUSTERFS):

```console
gluster peer probe SERVEUR01B-GLUSTERFS
```

Vérifier les noeuds:

```console
gluster peer status
gluster pool list
```

Créer les points à exporter:

```console
mkdir -p /export/gluster
```

Créer le volume de type réplica:

```console
gluster volume create dfs_services rep 2 transport tcp SERVEUR01A-GLUSTERFS:/export/gluster SERVEUR01B-GLUSTERFS:/export/gluster
```

Démarrer le volume:

```console
gluster volume start dfs_services
```

Vérifier le volume:

```console
gluster volume status
```

Changer le timeout (42 par défaut):

```console
gluster volume set dfs_services network.ping-timeout 5
```

Monter le volume

```console
mount -t glusterfs localhost:/dfs_services /mnt/gluster/
```

Pour un montage automatique via le `fstab`:

```console
localhost:/dfs_services       /mnt/gluster    glusterfs       defaults,_netdev 0 0
```

## Retours d'utilisation en production

Concernant les performances, GlusterFS possède ses limites: il n'est pas fait pour une activité I/O intense comme une base de données. J'ai pu le constater avec une base de données Zabbix sur GlusterFS entre deux serveurs (en cluster) virtualisés avec Xen (la virtualisation amoindri également les performances), même avec des interfaces réseau dédiées au DFS. Un cluster Galera dédié pour une base de données MySQL/MariaDB est bien plus adaptée dans cette situation.
Il est parfait pour stocker des fichiers de configuration, scripts et logs pour un cluster.

GlusterFS est très bien pensé et comprend notamment les outils qui permettent de se sortir des problèmes de "split-brain" causés par une écriture simultanée (depuis plusieurs serveurs) sur le même fichier du DFS. Il verrouille les fichiers en problème (le système se plaindra d'erreur I/O) et non le système de fichier au complet ce qui permet aux autres fichiers de rester accessible et minimiser l'impact en production. GlusterFS va alors attendre une intervention manuelle pour déterminer quel version du fichier en problème il faut garder sur le DFS.

Pour voir les fichiers en problème:

```console
gluster volume heal NOM_VOLUME info
```

Plusieurs choix s'offrent alors: restaurer le fichier en fonction de la taille (le plus gros):

```console
gluster volume heal NOM_VOLUME split-brain bigger-file FICHIER
```

Restaurer en fonction de la date (`mtime` le plus récent)

```console
gluster volume heal NOM_VOLUME split-brain latest-mtime FICHIER
```
Restaurer depuis la source voulue (brique/serveur):

```console
gluster volume heal NOM_VOLUME split-brain source-brick SERVEUR:BRIQUE FICHIER
```

Toutes les procédures sont détaillées [ici](https://docs.gluster.org/en/v3/Troubleshooting/resolving-splitbrain/).
