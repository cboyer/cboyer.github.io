---
title: "Système embarqué Linux avec Buildroot"
date: "2018-08-09T11:29:00-04:00"
updated: "2018-11-04T12:42:12-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [buildroot, embarqué, raspberry pi, linux]
abstract: |
  Création d'un système embarqué Linux avec Buildroot pour Raspberry Pi 2.
---

Dans le cadre d'un projet de monitoring, j'ai été amené à concevoir une vingtaine de sondes thermiques pouvant être interrogées via Ethernet. Mes choix techniques se sont naturellement tournés vers une solution Raspberry Pi/Linux/capteur DS18B20. Pour le coté applicatif j'ai opté pour la simplicité et la rapidité avec le couple Python/Flask pour acheminer les données via HTTPS. L'applicatif aurait pu être développé en C avec des librairies comme [Libmicrohttpd](https://www.gnu.org/software/libmicrohttpd/) ou encore [Kore](https://kore.io/).

Le ciment permettant de lier l'ensemble est [Buildroot](https://buildroot.org/) qui va nous permettre d'obtenir un système Linux sur mesure. Buildroot est un outil permettant de générer des systèmes Linux sur mesure en prenant en charge la compilation de la toolchain pour l'architecture cible (ARMv7), du noyau, du bootloader (que nous n'utiliserons pas) et de BusyBox pour l'environnement utilisateur. Tout cela avec nos paramètres définis pour chaque élément: modules dans le noyau, librairies standards ([musl](http://www.etalabs.net/compare_libcs.html), glibc, etc.), gestionnaire de services/périphériques (initd, systemd, udev), binaires à inclure dans BusyBoxy, etc. L'utilité de Buildroot se situe principalement dans sa capacité à gérer les dépendances pour la compilation, exactement comme Portage le fait dans Gentoo.

Voici les grandes lignes pour produire un système fonctionnel.

Commençons par récupérer Buildroot:

```bash
git clone https://github.com/buildroot/buildroot
cd buildroot
```

Charger la configuration par défaut pour Raspberry Pi 2 (sera ajustée à nos besoins par la suite):

```bash
make raspberrypi2_defconfig
```

Paramétrer le système (basé sur `raspberrypi2_defconfig`), les applications à inclure et l'image en sortie.
Si on utilise `U-Boot` comme bootloader, mettre la valeur `rpi` dans `Bootloaders > Select U-Boot > U-Boot board name`

```bash
make menuconfig
```

Sauvegarder la configuration Buildroot si on veut la stocker quelque part en particulier:

```bash
make savedefconfig BR2_DEFCONFIG=./buildroot_config
```

Pour la charger dans Buildroot:

```bash
make defconfig BR2_DEFCONFIG=./buildroot_config
```

Copier la configuration du noyau (supprimée après un `make clean`):

```bash
mkdir -p output/build/linux-custom/
cp kernel_config output/build/linux-custom/.config
```

Paramétrer le noyau:

```bash
make linux-menuconfig
```

On a tendance à vouloir retirer beaucoup de chose dans le noyau (supports de périphériques multimédia, radioamateur, joystick, etc.), il peut arriver de retirer quelque chose d'essentiel ou une dépendance ce qui se traduira par quelque chose de non fonctionnel.
Cela a été mon cas avec le driver pour l'interface Ethernet [SMSC95XX](https://cateee.net/lkddb/web-lkddb/USB_NET_SMSC95XX.html) dans `Devices Drivers > Network Device Support > USB Network Adapters > SMSC LAN95XX based USB 2.0 10/100 ethernet devices` qui dépendait de `Multi-purpose USB Networking Framework`.

Pour recompiler le noyau uniquement après un changement dans sa configuration:

```bash
make linux-build
```

Paramétrer Busybox:

```bash
make busybox-menuconfig
```

Paramétrer UBoot (si utilisé):

```bash
make uboot-menuconfig
```

Lancer la compilation:

```bash
make
```

Après un long moment de compilation (notamment pour la toolchain), l'image devrait être disponible dans `output/images/`.
Au final je suis parvenu à un partition `/` de 30Mo, `/boot` de 10Mo et une utilisation de la RAM sur le Raspberry ne dépasse pas 16Mo. Il aurait été possible de descendre encore en retirant des éléments dans BusyBox.


## Tests avec Qemu

L'image générée après compilation m'a posée problème avec Qemu pour faire mes tests: il semble y avoir un problème d'offset dans la table de partition bien que le Raspberry Pi arrive parfaitement à exécuter le système.
J'ai donc généré moi même l'image depuis l'archive `rootfs.tar.gz` et `boot.vfat` produits par Buildroot avec le script suivant (utilise `bsdtar` et nécessite `sudo` pour l'exécution):

```bash
IMG_SIZE="60M"
IMG_DIR="/opt/buildroot/buildroot/output/images"
IMG_OUTPUT="rpi2.img"

echo -e "\nCREATING IMAGE FILE"
rm -f "$IMG_OUTPUT"
fallocate -l "$IMG_SIZE" "$IMG_OUTPUT"

echo -e "CREATING IMAGE FILESYSTEMS"
LOOP=$(losetup -f)
losetup "$LOOP" "$IMG_OUTPUT"

fdisk "$LOOP" <<EOF
o
n
p
1

+10M
t
c
n
p
2

+50M
n
p
3


p
w
EOF

losetup -d "$LOOP"
losetup -P "$LOOP" "$IMG_OUTPUT"

echo -e "FORMAT IMAGE FILESYSTEMS"
sleep 3
mkfs.vfat "${LOOP}p1"
mkfs.ext4 "${LOOP}p2"

echo -e "MOUNTING IMAGE FILESYSTEMS"
mkdir -p mnt/boot_temp
mount -t vfat -o loop "${IMG_DIR}/boot.vfat" "mnt/boot_temp"
mkdir -p mnt/boot
mount "${LOOP}p1" mnt/boot
mkdir -p mnt/root
mount "${LOOP}p2" mnt/root

echo -e "EXTRACTING ROOTFS TO IMAGE"
bsdtar -xpf "$IMG_DIR/rootfs.tar.gz" -C mnt/root
echo -e "EXTRACTING BOOTFS TO IMAGE"
cp mnt/boot_temp/* mnt/boot

echo -e "UNMOUNTING IMAGE FILESYSTEMS"
sync
umount mnt/boot mnt/root mnt/boot_temp
losetup -d "$LOOP"

chown cyril:cyril "$IMG_OUTPUT"
echo -e "Done !"
```

Lancer l'image avec Qemu pour les tests

```bash
qemu-system-arm -M raspi2 -cpu arm1176 -m 1G -smp 4 \
-append "ro earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 rootfstype=ext4 root=/dev/mmcblk0p2 rootwait" \
-dtb output/images/bcm2709-rpi-2-b.dtb -drive if=sd,driver=raw,file=rpi2.img \
-kernel output/images/zImage -serial stdio
```

Pour envoyer votre image sur un support physique (carte SD dans notre cas):

```bash
dd bs=4M if=rpi2.img of=/dev/mmcblk0 status=progress
sync
```

## Modification manuelle de l'image

Il est nécessaire d'ajouter des fichiers `.dtb` dans la partition `/boot` afin de faire fonctionner certains composants comme le capteur DS18B20.
Pour cela, monter la partition `/boot` du fichier `rpi2.img` avec `losetup` et `mount` comme dans le script précédent puis:

```bash
mkdir mnt/boot/overlays
dtc -O dtb -o w1-gpio-overlay.dtb output/build/linux-custom/arch/arm/boot/dts/overlays/w1-gpio-overlay.dts
cp w1-gpio-overlay.dtb mnt/boot/overlays
echo "dtoverlay=w1-gpio,pullup=1,gpiopin=4" >> mnt/boot/config.txt
```

Pour faire correctement les choses, il faudrait utiliser un *post-script* ou encore un *overlay* dans Builroot pour insérer des fichiers dans l'image produite. C'est également de cette manière qu'il faut intégrer sa partie applicative.

## Les bonnes pratiques

 - Ne pas utiliser le compte `root` pour l'applicatif, question de sécurité (implique d'utiliser un port réseau > 1024).
 - Configurer `/` en lecture seule pour la sécurité et surtout éviter les problème de corruption de la carte SD en cas de coupure électrique.
 - Ne pas inclure de service d'accès à distance `OpenSSH`.
 - Laisser éventuellement un accès physique via un TTY sur la sortie HDMI pour la configuration IP et investiguer en cas de problème.
 - Ne pas configurer d'autologin sur TTY au boot pour maintenir l'authentification via login/mot de passe.
 - Inclure les modules `iptables` dans le noyau et définir des règles de parfeu via `initd` afin de protéger l'applicatif si l'environnement réseau est jugé incertain.
 - Lancer l'applicatif via un script `initd` composée d'une boucle pour le relancer automatiquement en cas de crash.

## Les alternatives à Buildroot

Il existe d'autres outils pour construire un système embarqué Linux: [Yocto](https://www.yoctoproject.org/) est très utilisé dans le domaine, des constructeurs comme Xilinx, Intel et TI fournissent des "layers" pour intégrer des composants matériels/logiciels à votre système.

Citons le très intéressant [Nerves](https://nerves-project.org/) qui utilise Buildroot afin de créer un système extrêmement optimisée/minimaliste pour exécuter une machine virtuelle BEAM et des applications Elixir.

Notons également qu'il existe l'équivalent de Buildroot pour FreeBSD: [Crochet](https://github.com/freebsd/crochet).
