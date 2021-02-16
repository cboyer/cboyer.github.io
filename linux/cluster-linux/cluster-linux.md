---
title: "Cluster Linux avec Pacemaker/Corosync/PCS"
date: "2016-10-30T13:23:14-04:00"
updated: "2016-10-30T13:23:14-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [Linux, Cluster, Pacemake, Corosync, PCS, Redhat]
abstract: "Cluster Linux avec Pacemaker/Corosync/PCS"
---

Installer les packages
```console
yum -y install corosync pacemaker pcs
```

Démarrage de pcsd
```console
systemctl enable pcsd.service
systemctl start pcsd.service
```

Changer le mot de passe de l'utilisateur `hacluster` créé par pcsd
```console
passwd hacluster
```

Authantification de pcsd sur les noeuds (ip ou noms si résolution)
```console
pcs cluster auth SRV-TEST01A SRV-TEST01B
```

Création du cluster
```console
pcs cluster setup --name DMZSVC01 SRV-TEST01A SRV-TEST01B
```

Démarrer tous les services (corosync et pacemaker) sur tous les noeuds
```console
pcs cluster start --all
```

Activer les services au démarrage
```console
systemctl enable corosync.service
systemctl enable pacemaker.service
```

Vérifier les status
```console
crm_mon -1
pcs status
pcs status nodes
pcs status corosync
```

Désactiver le STONITH et le quorum (quorum inutile car juste 2 noeuds)
```console
pcs property set stonith-enabled=false
pcs property set no-quorum-policy=ignore
```

Lster les paramètres disponibles pour un type de ressource
```console
pcs resource describe ocf:heartbeat:IPaddr2
```

Créer une IP virtuelle comme ressource
```console
pcs resource create virtual_ip ocf:heartbeat:IPaddr2 ip=142.101.210.23 cidr_netmask=25 op monitor interval=10s
```

Vérifier les paramètres définis pour une ressource
```console
pcs resource show virtual_ip
```

Modifier les paramètres définis pour une ressource
```console
pcs resource update virtual_ip ip=142.101.210.23
```

Vérifier les ressources
```console
pcs status resources
```

Ajouter une contrainte (ip virtuelle de préférence sur SRV-TEST01A score de 50)
```console
pcs constraint location virtual_ip prefers SRV-TEST01A=50
```

Vérifier les contraintes
```console
pcs constraint
```

Créer la ressource `postfix` après avoir configurer les chemins vers GlusterFS et SSMTP comme MTA par défaut
```console
pcs resource create smtp_postfix ocf:heartbeat:postfix binary="/usr/sbin/postfix" config_dir="/mnt/gluster/postfix/conf" op monitor interval="60s" timeout="20s"
```

Créer les contraintes pour postfix ou un resource group
```console
pcs constraint location smtp_postfix prefers SRV-TEST01A=50
pcs constraint colocation add smtp_postfix virtual_ip INFINITY
pcs constraint order start virtual_ip then start smtp_postfix kind=Mandatory symmetrical=true
```

Les contraintes précédentes sont équivalentes à créer un groupe (l'ordre des resources est important)
```console
pcs resource group add mail_group virtual_ip smtp_postfix
```

Créer un monitoring mail pour chaque evenement sur le cluster
```console
pcs resource create cluster_monitoring ClusterMon user=root update=30 extra_options="-E /mnt/gluster/monitoring.pl" op monitor interval="120s" --clone
```

Arreter les services sur un noeud
```console
pcs cluster stop SRV-TEST01A
```

Mettre un noeud en standby
```console
pcs cluster standby SRV-TEST01A
```

Réactiver un noeud en standby
```console
pcs cluster unstandby SRV-TEST01A
```

Réactiver une ressource Failed Unmanaged
```console
pcs resource cleanup smtp_postfix
pcs resource manage smtp_postfix
pcs resource enable smtp_postfix
```

Déplacer une ressource
```console
pcs resource move smtp_postfix SRV-TEST01A
```

La déplacer sur le noeud d'origine (défini par constraint
```console
pcs resource clear smtp_postfix SRV-TEST01A
```


# Liens complémentaires
 - [https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Configuring_the_Red_Hat_High_Availability_Add-On_with_Pacemaker/ch-pcscommand-HAAR.html](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Configuring_the_Red_Hat_High_Availability_Add-On_with_Pacemaker/ch-pcscommand-HAAR.html)
 - [http://linux-ha.org/doc/man-pages/re-ra-postfix.html](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Configuring_the_Red_Hat_High_Availability_Add-On_with_Pacemaker/ch-pcscommand-HAAR.html)
