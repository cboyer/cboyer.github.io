---
title: "Création manuelle d'un LPAR AIX depuis le VIOS"
date: "2015-07-09T13:23:14-04:00"
updated: "2018-11-17T13:09:10-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [IBM, AIX, LPAR, HMC, VIOS, création, manuelle]
abstract: |
  Monter manuellement un LPAR AIX 7.1 depuis le VIOS.
---


Quelques notes pour le montage d'un LPAR AIX 7.1 depuis le VIOS sans utiliser d'HMC.


Accepter la license du VIOS:

```console
license -accept
```

Passer en root:

```console
oem_setup_env
id
```

Installer la mise à jour du VIOS:

```console
updateios -accept -dev /home/padmin/Extact/ -install
```

Changer le prompt:

```bash
echo "export ENV=/home/padmin/.kshrc" >> /home/padmin/.profile
```

Créer le /home/padmin/.kshrc avec:

```bash
export HOST="$(/usr/bin/uname -n)"
if [ "`whoami`" = "root" ]; then
  PS1="`whoami`@$HOST:$PWD # "
else
  PS1="`whoami`@$HOST:$PWD $ "
fi
set -o vi
```

Changer la date (mmJJHHMMAAAA):

```console
chdate 070913232015
```

Détails des interfaces:

```console
entstat ent0
entstat -d ent0
```

Statut des interfaces:

```console
netstat -state
lstcpip
lstcpip -interfaces
netstat -v en0 | egrep -i "link|speed"
```

Outil de configuration:

```console
smit
```

Configuration IP:

```console
mktcpip -hostname violab02 -inetaddr 192.168.0.22 -interface en0 -start -netmask 255.255.255.0 -gateway 192.168.0.100 -nsrvaddr 192.168.0.15 -nsrvdomain ibmlabo.lab
smitty tcpip
```

Afficher les routes:

```console
netstat -routinfo
netstat -rn
```

Lister les périphériques:

```console
lsdev
```

Lister les slots des périphériques:

```console
lsdev -slots
```

Lister les lecteur CD:

```console
lsdev -type optical
```

Lister les disques durs:

```console
lsdev -type disk
lspv
lspv hdisk1
```

Statistiques mémoire:

```console
lshwres -r mem --level sys
```

Lister les LPAR:

```console
lssyscfg -r lpar -F lpar_id,name,state
```

Reset de la configuration IP:

```console
rmtcpip -interface en1
```

Créer une interface partagée SEA:

```console
mkvdev -sea ent1 -vadapter ent5 -default ent5 -defaultid 1
```

Lister le mappage des interfaces:

```console
lsmap -all -net
```

Trouver le port_vlan_id pour le slot de l'interface réseau:

```console
lshwres --level lpar -r virtualio --rsubtype eth
```

Créer le LPAR (`virtual_eth_adapters` = *slot_num/ieee_virtual_eth/port_vlan_id/addl_vlan_ids/is_trunk/trunk_priority*):

```console
mksyscfg -r lpar -i 'name=aixlab02,profile_name=aixlab02,lpar_env=aixlinux,min_mem=8192,desired_mem=16384,max_mem=32768,proc_mode=shared,min_procs=1,desired_procs=2,max_procs=4,min_proc_units=1,desired_proc_units=2,max_proc_units=4,sharing_mode=uncap,uncap_weight=128,boot_mode=norm,auto_start=1,"virtual_scsi_adapters=2/client/1/vioserver/11/1","virtual_eth_adapters=4/0/2//0/0"'
```

Éditer un profil LPAR (le LPAR doit être off):

```console
chsyscfg -r prof -i 'name=aixlab02,lpar_name=aixlab02,"virtual_eth_adapters=4/0/2//0/0"'
```

Changer le nom d'une LPAR:

```console
chsyscfg -r lpar -i "name=LPAR_Name,new_name=New_LPAR_Name"
```

Changer le min/desired/maximum memory:

```console
chsyscfg -r prof -i "name=Profile_Name,lpar_name=LPAR_Name,min_mem=512,desired_mem=19456,max_mem=20480"
```

Changer le min/desired/maximum processor units:

```console
chsyscfg -r prof -i "name=Profile_Name,lpar_name=LPAR_Name,min_proc_units=0.2,desired_proc_units=0.5,max_proc_units=2.0"
```

Changer le min/desired/maximum virtual processor:

```console
chsyscfg -r prof -i "name=Profile_Name,lpar_name=LPAR_Name,min_procs=1,desired_procs=2,max_procs=6"
```

Changer le capped/uncapped (sharing_mode=cap|uncap;uncap_weight=[0;128]):

```console
chsyscfg -r prof -i "name=Profile_Name,lpar_name=LPAR_Name,sharing_mode=uncap,uncap_weight=128"
```

Lister les LPAR:

```console
lssyscfg -r lpar
```

Afficher le profil d'un LPAR:

```console
lssyscfg -r prof
lssyscfg -r prof --filter lpar_names=aixlba02
lssyscfg -r prof --filter lpar_ids=2
```

Recharger la liste des disques visibles par le VIOS:

```console
cfgdev
```

Lister les virtual SCSI server (vhostX):

```console
lsdev -virtual
```

Vérifier les slots vhost:

```console
lsmap -all
```

Créer un vg pour créer les disques virtuels à l'intérieur:

```console
mkvg -f -vg aixlab02_vg hdisk4
```

Ajouter un disk dans le vg:

```console
extendvg aixlab02_vg hdisk5
```

Lister les vg:

```console
lsvg
```

Afficher détails d'un vg:

```console
lsvg aixlab02_vg
```

Créer un lv dans le vg qui va servir de disque virtuel au LPAR:

```console
mklv -lv aixlab02 aixlab02_vg 140G
```

Assigner le disque à un vhost et lister les vhosts:

```console
mkvdev -vdev aixlab02 -vadapter vhost0 -dev vaixlab02
lsdev -virtual
lsmap -all
```

Assigner le lecteur CD à un vhosts:

```console
mkvdev -vdev cd0 -vadapter vhost0 -dev vcd
```

Booter le LPAR en SMS menu et afficher son statut:

```console
chsysstate -r lpar -o on -b sms --id 2
```

Créer un terminal virtuel pour se connecter au LPAR:

```console
mkvt -id 2
```

Supprimer le terminal virtuel:

```console
rmvt -id 2
```

Récupérer l'id du CD dans le LPAR pour le supprimer après:

```console
lsdev -l cd0 -F parent
```

Supprimer le CD du LPAR:

```console
rmdev -dl vscsiXX -R
```

Rattacher le CD dans un autre LPAR:

```console
cfgmgr
```

Éteindre le LPAR:

```console
chsysstate -o shutdown -r lpar --immed -n aixlab02
```

Démarrer le LPAR en mode normal:

```console
chsysstate -o on -b norm -r lpar -n aixlab02
```
