---
title: "Système embarqué Linux avec Buildroot, Qemu et Raspberry Pi 3"
date: "2021-03-07T18:23:00-05:00"
updated: "2021-03-07T18:23:00-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [buildroot, qemu, raspberry, raspberry pi, linux]
abstract: "Création d'un système embarqué Linux avec Buildroot et Qemu pour Raspberry Pi 3."
---


Un autre article sur l'utilisation de Buildroot avec un Raspberry Pi, quelque peu similaire au [précédent](../buildroot-systeme-embarque/) à ceci près qu'il comporte davantage de détails.
Il présente notamment l'intégration d'éléments externes à Buildroot (comme une application) et la prise en charge du réseau sous Qemu.
Nous utilisons ici Buildroot 2021.02-rc3 pour obtenir une image 64 bits compatible avec le Raspberry Pi 3.


## Paramétrage de l'image, du noyau et Busybox

Commençons par télécharger Buildroot depuit son dépôt Github
```Console
git clone https://github.com/buildroot/buildroot
cd buildroot
```

### Paramétrage de l'image

Charger la configuration par défaut pour Raspberry Pi 3 qui nous servira de base pour être ajustée selon nos besoins
```Console
make raspberrypi3_64_defconfig
```

Paramétrage de l'image buildroot
```Console
make menuconfig
```

Quelques modifications depuis la configuration de base `raspberrypi3_64_defconfig`:

| Option                                          | Emplacement          | Symbole Kconfig                      |
|-------------------------------------------------|----------------------|--------------------------------------|
| Enable root login with password                 | System configuration | BR2_TARGET_ENABLE_ROOT_LOGIN         |
| Root password                                   | System configuration | BR2_TARGET_GENERIC_ROOT_PASSWD       |
| System hostname                                 | System configuration | BR2_TARGET_GENERIC_HOSTNAME          |
| System banner                                   | System configuration | BR2_TARGET_GENERIC_ISSUE             |
| remount root filesystem read-write during boot  | System configuration | BR2_TARGET_GENERIC_REMOUNT_ROOTFS_RW |
| exact size *                                    | Filesystem images    | BR2_TARGET_ROOTFS_EXT2_SIZE          |

\* Attention à ne pas mettre une valeur trop petite car Buildroot sera incapable de faire tenir le système sur une image sous-dimensonnée.


La configuration Buildroot peut être sauvegardée à un endroit autre que celui par défaut (`buildroot/.config`). 
Cela va nous permettre plus tard d'exporter la configuration dans un arbre externe.
```Console
make savedefconfig BR2_DEFCONFIG=./buildroot_config
```

Pour la charger dans Buildroot:
```Console
make defconfig BR2_DEFCONFIG=./buildroot_config
```

### Paramétrage du noyau Linux

Paramétrer le noyau:
```Console
make linux-menuconfig
```

Une option importante à définir est la liste des paramètres passés au noyau:
```Text
Boot options
└── Default kernel command string (CMDLINE)

console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait
```

Pour fournir un accès réseau à la machine virtuelle Qemu, il faut le module `cdc_ether` pour utiliser l'ethernet sur USB car le Raspberry ne possède pas de contrôleur permettant d'utiliser VirtIO:
```text
Device Drivers
└── Network device support (NETDEVICES)
    └── USB Network Adapters (USB_NET_DRIVERS)
        └── Multi-purpose USB Networking Framework (USB_USBNET)
            └── CDC Ethernet support (smart devices such as cable modems) (USB_NET_CDCETHER)
```

### Paramétrage de BusyBox
Paramétrer BusyBox permet de sélectionner les binaires à intégrer comme `ls`, `find`, `xargs`, etc. Il ne peuvent pas tous être exclus car certains sont utilisés dans des scripts systèmes (par exemple `xargs` et `touch`).

```Console
make busybox-menuconfig
```

## Création d'un arbre externe contenant une application

### Arborescence

Nous allons créer un arbre externe qui va nous permettre de stocker toutes les particularités pour notre image (applications, overlays, patches pour le noyau, configurations).

La structure du dossier `br-external` (arbre externe), dans la racine Buildroot:

```text
br-external/
├── config                      Stocke nos configurations Buildroot et Linux
├── Config.in                   Regroupe dynamiquement tous les descriptifs Kconfig des packages
├── external.desc               Nom de l'arbre, conditionne la variable $BR2_EXTERNAL_***_PATH
├── external.mk                 Regroupe dynamiquement les Makefiles des packages
├── linux-patches               Pour les patchs du noyau (non utilisé ici)
├── package                     Les packages (applications)
│   └── hello                   Notre application de test
│       ├── Config.in           Descriptif Kconfig
│       ├── S99hello            Script de démarrage init.d
│       ├── external.mk         Script Buildroot pour la compilation/installation
│       └── src             
│           ├── hello.c         Fichier source
│           └── Makefile        Makefile
└── rootfs_overlay              Fichiers à ajouter dans l'image (non utilisé ici)
```


#### Fichier br-external/external.desc
```Text
name: MONDEPOT
desc: Exemple arbre externe
```

#### Fichier br-external/external.mk
```Console
include $(sort $(wildcard $(BR2_EXTERNAL_MONDEPOT_PATH)/package/*/*.mk))
```


### Intégration d'une application (package)

L'intégration d'une application `hello` dans Buildroot consiste à créer un package qui contient le code source et les directives (Makefile) pour la compilation et l'installation.

#### Fichier br-external/Config.in
```Console
source "$BR2_EXTERNAL_MONDEPOT_PATH/package/hello/Config.in"
```

#### Fichier br-external/package/hello/Config.in
```Text
config BR2_PACKAGE_HELLO
	bool "hello"
	help
	  Application externe de test hello.

	  https://cboyer.github.io/
```

#### Fichier br-external/package/hello/external.mk
```Makefile
################################################################################
#
# hello
#
################################################################################

HELLO_VERSION = 1.0
HELLO_SITE = $(BR2_EXTERNAL_MONDEPOT_PATH)/package/hello/src
HELLO_SITE_METHOD = local

define HELLO_BUILD_CMDS
	$(MAKE) CC="$(TARGET_CC)" LD="$(TARGET_LD)" -C $(@D)
endef

define HELLO_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/hello $(TARGET_DIR)/usr/bin
endef

define HELLO_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(HELLO_PKGDIR)/S99hello \
	$(TARGET_DIR)/etc/init.d/S99hello
endef

$(eval $(generic-package))
```

#### Fichier br-external/package/hello/src/hello.c
```C
#include <stdio.h>

int main(void) {
    puts("hello");
    return 0;
}
```

#### Fichier br-external/package/hello/src/Makefile
```Makefile
CC = gcc

.PHONY: clean

hello: hello.c
	$(CC) -o '$@' '$<'

clean:
	rm hello
```

#### Fichier br-external/package/hello/S99hello
```Bash
#!/bin/sh

case "$1" in
    start)
        printf "Starting hello: "
        /usr/bin/hello --start
        [ $? = 0 ] && echo "OK" || echo "FAIL"
        ;;
    stop)
        printf "Stopping hello: "
        /usr/bin/hello --stop
        [ $? = 0 ] && echo "OK" || echo "FAIL"
        ;;
    restart|reload)
        "$0" stop
        "$0" start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
esac

exit $?
```


Les nouveaux packages de l'arbre externe (`hello`) sont accessibles depuis les paramètres Buildroot dans un nouveau menu `External options` qui est disponible avec:
```Console
make BR2_EXTERNAL=./br-external menuconfig
```

### Intégration des configurations Buildroot et du noyau Linux

Nous pouvons copier notre fichier de configuration Buildroot et celui du noyau dans notre arbre externe. 
Ceci permet de regrouper tous les composants spécifiques à la création de l'image en les séparant des fichiers Buildroot d'origine.

Copier la configuration du noyau
```Console
cp output/build/linux-custom/.config br-external/config/linux.config
```

Pour charger automatiquement le fichier de configuration noyau par Buildroot, il faut activer l'utilisation d'une configuration spécifique puis saisir le chemin vers le fichier en question: `$(BR2_EXTERNAL_MONDEPOT_PATH)/config/linux.config`.
L'opération est identique pour les patches, overlays et scripts en ajustant le dossier cible (non utilisés ici).

```Console
make BR2_EXTERNAL=./br-external menuconfig
```

| Option                                                 | Emplacement                                  | Symbole Kconfig                    |
|--------------------------------------------------------|----------------------------------------------|------------------------------------|
| Using a custom (def)config file                        | Kernel > Linux Kernel > Kernel configuration | BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG |
| Configuration file path                                | Kernel > Linux Kernel                        | BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE|
| global patch directories                               | Build options                                | BR2_GLOBAL_PATCH_DIR               |
| Root filesystem overlay directories                    | System configuration                         | BR2_ROOTFS_OVERLAY                 |
| Custom scripts to run after creating filesystem images | System configuration                         | BR2_ROOTFS_POST_IMAGE_SCRIPT       |



Copie du fichier de configuration Buildroot
```Console
make savedefconfig BR2_DEFCONFIG=./br-external/config/raspberrypi3_64_custom_defconfig
```

Pour recharger le fichier de configuration Buildroot depuis l'arbre externe
```Console
make defconfig BR2_DEFCONFIG=./br-external/config/raspberrypi3_64_custom_defconfig
```



## Compilation et création de l'image

Pour compiler/recompiler séparément un élément (noyau, Busybox ou un package)
```Console
make linux-build
make busybox-build
make hello-build

#Nettoyage et recompilation
make linux-dirclean
make linux-rebuild
```

Pour générer l'image buildroot (comprend la compilation de tous les éléments qui compose l'image)
```Console
make
```

Pour retirer le package `hello` sans tout recompiler:
```Console
#Désélectionner le package hello dans External options
make BR2_EXTERNAL=./br-external menuconfig

#Retrait du binaire de l'image
rm output/target/usr/bin/hello 

#Supprime le dossier de compilation, équivaut à rm -rf output/build/hello-1.0/
make hello-dirclean
make
```



## Exécuter l'image avec Qemu

Il s'agit de charger l'image avec Qemu en spécifiant les paramètres comme les fichiers (noyau, image et device tree).
Ici le port 80 de la machine virtuelle Qemu est accessible via le port 5555 sur localhost.
La vm possède également accès au réseau externe et à internet.
Cette configuration peut également être modifiée pour permettre l'accès via SSH en utilisant le port 22 au lieu de 80.

```Console
qemu-system-aarch64 -M raspi3 -m 1024 \
    -kernel output/images/Image \
    -dtb output/images/bcm2710-rpi-3-b.dtb \
    -drive if=sd,driver=raw,file=output/images/sdcard.img \
    -append "console=ttyAMA0 root=/dev/mmcblk0p2 rw rootwait rootfstype=ext4" \
    -device usb-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp::5555-:80 \
    -serial stdio
```

Si Qemu retourne l'erreur suivante, il suffit d'utiliser `qemu-img`
```Console
qemu-system-aarch64: Invalid SD card size: 57 MiB

SD card size has to be a power of 2, e.g. 64 MiB.
You can resize disk images with 'qemu-img resize <imagefile> <new-size>'
(note that this will lose data if you make the image smaller than it currently is).
```

Pour vérifier les dimensions de l'image
```Console
qemu-img info output/images/sdcard.img
```

Redimmensionner l'image
```Console
qemu-img resize -f raw output/images/sdcard.img 64M 
```

Au boot de la vm on peut voir la configuration réseau (ici `cdc_ether` est directement inclus dans le noyau)
```Console
[    2.604357] usb 1-1.1: new full-speed USB device number 3 using dwc_otg
[    2.704194] usb 1-1.1: New USB device found, idVendor=0525, idProduct=a4a2, bcdDevice= 0.00
[    2.704879] usb 1-1.1: New USB device strings: Mfr=1, Product=2, SerialNumber=10
[    2.705936] usb 1-1.1: Product: RNDIS/QEMU USB Network Device
[    2.706784] usb 1-1.1: Manufacturer: QEMU
[    2.707319] usb 1-1.1: SerialNumber: 1-1.1
[    2.731964] cdc_ether 1-1.1:1.0 eth0: register 'cdc_ether' at usb-3f980000.usb-1.1, CDC Ethernet Device, 40:54:00:12:34:57
(...)
Starting network: [    3.859276] random: crng init done
udhcpc: started, v1.33.0
udhcpc: sending discover
udhcpc: sending select for 10.0.2.15
udhcpc: lease of 10.0.2.15 obtained, lease time 86400
deleting routers
adding dns 10.0.2.3
OK
```


Pour effectuer un test réseau nous pouvons utiliser `nc` comme serveur HTTP improvisé sur la vm Qemu:
```Console
while true ; do  echo -e "HTTP/1.1 200 OK\n\n Bonjour réseau!" | nc -l -p 80  ; done
```

La page peut être consulté depuis le host avec un navigateur (ou curl/wget) via l'adresse `http://localhost:5555`.

Notre application est compilée et présente dans l'image: `/usr/bin/hello`, celle-ci est également exécutée au démarrage (en dernier) grâce au script init.d `/etc/init.d/S99hello`.

Pour copier l'image sur une carte SD à destination d'un Raspberry Pi 3:

```Console
dd bs=4M if=output/images/sdcard.img of=/dev/mmcblk0 status=progress
sync
```


## Liens complémentaires

- [Arbre externe](https://github.com/maximeh/buildroot/blob/master/docs/manual/customize-outside-br.txt)
- [Exemple d'arbre externe sur Github](https://github.com/m-ka/br-external)
- [Exemple d'arbre externe pour EBAZ4205](https://github.com/embed-me/ebaz4205_buildroot)
