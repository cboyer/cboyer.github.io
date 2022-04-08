---
title: "Liaison bluetooth entre ESP32 et Raspberry Pi 3"
date: "2021-07-27T17:37:34-04:00"
updated: "2021-07-27T17:37:34-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [Raspberry, Buildroot, ESP32, bluetooth, rfcomm, BluetoothSerial]
abstract: |
  Liaison bluetooth entre ESP32 et Raspberry Pi 3.
---

L'article a été rédigé en utilisant un Raspberry Pi 3 avec Buildroot 2021.05-514-g74adec4f3a.
L'objectif est de transmettre des données via bluetooth classique d'un ESP32 vers un Raspberry Pi (unidirectionnel) avec le protocol RFCOMM.
L'exemple présenté ici est facilement modifiable pour une liaison bidirectionnelle ainsi que l'implémentation d'une méthode d'authentification/chiffrement.


## ESP32

L'ESP32 va relayer les données entrantes du port série vers bluetooth (rfcomm) grâce à la librairie `BluetoothSerial` qui est utilisable avec l'IDE Arduino et le SDK Espressif.

```C
#include "BluetoothSerial.h"
BluetoothSerial SerialBT;

void setup() {
    Serial.begin(115200);
    SerialBT.begin("Telemetry");
}

void loop() {
    if (Serial.available()) {
        SerialBT.write(Serial.read());
    }
}
```




## Raspberry Pi: configuration Buildroot

```Bash
make raspberrypi3_defconfig
make menuconfig
```

```text
System configuration → System hostname (BR2_TARGET_GENERIC_HOSTNAME="buildrootqt5")
System configuration → Root password (BR2_TARGET_GENERIC_ROOT_PASSWD="root")
System configuration → remount root filesystem read-write during boot (BR2_TARGET_GENERIC_REMOUNT_ROOTFS_RW=n)
System configuration → Root filesystem overlay directories (BR2_ROOTFS_OVERLAY=output/rootfs_overlay)

Target packages → Hardware handling → Firmware → rpi-firmware (BR2_PACKAGE_RPI_BT_FIRMWARE=y)
Target packages → Networking applications → bluez-utils (BR2_PACKAGE_BLUEZ5_UTILS=y)
Target packages → Networking applications → build CLI client (BR2_PACKAGE_BLUEZ5_UTILS_CLIENT=y)
Target packages → Networking applications → install deprecated tools (BR2_PACKAGE_BLUEZ5_UTILS_DEPRECATED=y) pour avoir rfcomm
```


Sauvegarde de la configuration Buildroot:
```Bash
make savedefconfig BR2_DEFCONFIG=./buildroot_bt.config
```


## Configuration du noyau Linux

Pour la configuration du noyau, aucun pilote graphique particulier (DRM, VC4) n'est nécessaire, il faut veiller à la présence des "Firmware Driver" (présents par défaut):
```Bash
make linux-menuconfig
```

```text
Firmware Drivers → Raspberry Pi Firmware Driver (RASPBERRYPI_FIRMWARE=y)
Networking support → Bluetooth subsystem support (CONFIG_BT=m)
Networking support → Bluetooth subsystem support → Bluetooth Classic (BR/EDR) features (CONFIG_BT_BREDR=y)
Networking support → Bluetooth subsystem support → RFCOMM protocol support (CONFIG_BT_RFCOMM=m)
Networking support → Bluetooth subsystem support → RFCOMM TTY support (CONFIG_BT_RFCOMM_TTY=y)
Networking support → Bluetooth subsystem support → Bluetooth device drivers → HCI UART driver (CONFIG_BT_HCIUART=m)
Networking support → Bluetooth subsystem support → Bluetooth device drivers → Broadcom protocol support (CONFIG_BT_HCIUART_BCM=y)
```

> Inutil d'inclure les protocoles BNEP qui sert à l'émulation Ethernet et HIDP pour le support des claviers/souris via bluetooth.
> Le module `rfcomm` doit être compilé en tant que module.


Sauvegarde de la configuration du noyau:
```Bash
cp output/build/linux-custom/.config linux_bt.config
```



## Configuration bluetooth

Pour inclure nos fichiers nous allons utiliser un overlay, tous les fichiers contenu dans `output/rootfs_overlay` (considéré par Buildroot comme référence à la racine) seront présents dans l'image finale.

Le périphérique bluetooth du Raspberry est interfacé via UART.
Pour un Pi Zero W et Pi 3, avec la présence de la ligne `dtoverlay=miniuart-bt` dans `boot/config.txt`, le périphérique bluetooth est accessible via `/dev/ttyS0` et non `/dev/ttyAMA0`.


### Configuration avec btattach/bluetoothctl

Ajouter un script dans l'overlay `output/rootfs_overlay/root/bt.sh` pour activer le bluetooth:
```Bash
#!/bin/sh

#attache le périphérique pour obtenir l'interface hci0 (charge les modules nécessaires comme btbcm et hci_uart). Fonctionne en arrière plan en permanence.
/usr/bin/btattach -B /dev/ttyS0 -P bcm -S 921600 -N &
/bin/sleep 10

#active l'interface sans la rendre visible via bluetooth
/usr/bin/bluetoothctl power on
/usr/bin/bluetoothctl discoverable off

#obtient le port série /dev/rfcomm0 (pas besoin de "pairer" ni connecter)
/sbin/modprobe rfcomm
/usr/bin/rfcomm bind rfcomm0 11:22:33:44:55:66
```

> `btattach` doit être exécuté en arrière plan et induit un certain délais pour rendre l'interface disponible.


### Configuration avec hciattach/hciconfig (outils désuets)

Le script `output/rootfs_overlay/root/bt.sh` pour activer le bluetooth avec les outils BlueZ désuets:
```Bash
#!/bin/sh

#attache le périphérique pour obtenir l'interface hci0 (charge les modules nécessaires comme btbcm et hci_uart)
/usr/bin/hciattach /dev/ttyS0 bcm43xx 921600 noflow -

#active l'interface
/usr/bin/hciconfig hci0 up

#obtient le port série /dev/rfcomm0 (pas besoin de "pairer" ni connecter)
/sbin/modprobe rfcomm
/usr/bin/rfcomm bind rfcomm0 11:22:33:44:55:66
```

> Bien que désuet, `hciattach` présente l'avantage de s'exécuter très rapidement et de rendre la main ce qui n'implique pas de `sleep` dans le script.

Pour tester l'interface bluetooth: `l2ping 11:22:33:44:55:66`.


### Compilation

Lancer la compilation et la création de l'image:
```Bash
make
```

Copie de l'image générée vers la carte SD:
```Bash
sudo dd if=output/images/sdcard.img of=/dev/mmcblk0 status=progress
```

Après avoir démarré le système sur le Raspberry, exécuter `bt.sh`:
```Bash
sh bt.sh
```

Les données reçues sont disponibles via le port série `/dev/rfcomm0` (affichables avec `cat`).



## Se passer de rfcomm et des outils désuets

Pour se passer des outils désuets `hci*` (dont l'outil `rfcomm`), il est possible d'écrire un programme C similaire qui va nous permettre de réceptionner les données.
Le module `rfcomm` est toujours nécessaire coté noyau.
Le programme affiche sur STDOUT les données dès leur réception sans réassembler le message (une chaîne de caractères peut être reçue en plusieurs fois).

Programme `clientrfcomm.c`
```C
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <bluetooth/bluetooth.h>
#include <bluetooth/rfcomm.h>
#include <signal.h>
#include <stdbool.h>

bool volatile keep_running = true;

void exit_handle(int sig) {
    keep_running = false;
}


int main(int argc, char **argv) {
    struct sockaddr_rc addr = { 0 };
    struct sigaction act;
    int s, status, bytes_read;
    char dest[18] = { '\0' };
    char buf[1024] = { '\0' };
    uint8_t channel = 1;

    if (argc != 3) {
        fprintf(stderr, "Usage: %s <address> <channel>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    snprintf(dest, sizeof dest, "%s", argv[1]);
    channel = atoi(argv[2]);

    act.sa_handler = exit_handle;
    sigemptyset (&act.sa_mask);
    act.sa_flags = 0;
    sigaction(SIGINT,  &act, 0);
    sigaction(SIGTERM, &act, 0);

    s = socket(AF_BLUETOOTH, SOCK_STREAM, BTPROTO_RFCOMM);

    addr.rc_family = AF_BLUETOOTH;
    addr.rc_channel = channel;
    str2ba(dest, &addr.rc_bdaddr);

    status = connect(s, (struct sockaddr *)&addr, sizeof addr);

    if (status < 0) {
        perror("Connection error");
        exit(EXIT_FAILURE);
    }

    while(keep_running) {
        bytes_read = read(s, buf, sizeof buf);
        buf[bytes_read] = '\0';

        if (bytes_read > 0) {
            printf("received: %s\n", buf);
            fflush(stdout);
            buf[0] = '\0';
        }
    }

    close(s);
    return EXIT_SUCCESS;
}
```

Pour compiler/tester le programme sur la machine host:

```Bash
sudo dnf install bluez-libs-devel
gcc -Wall -Werror -O2 clientrfcomm.c -lbluetooth
client_rfcomm 11:22:33:44:55:66 1
```

Pour inclure ce programme dans l'image destinée au Raspberry sous forme de package, il faut construire un arbre externe avec la structure suivante (depuis la racine Buildroot):

```text
br-external/
├── Config.in                   Regroupe dynamiquement tous les descriptifs Kconfig des packages
├── external.desc               Nom de l'arbre, conditionne la variable $BR2_EXTERNAL_***_PATH
├── external.mk                 Regroupe dynamiquement les Makefiles des packages
└── package                     Les packages (applications)
    └── clientrfcomm            Notre application de test
        ├── Config.in           Descriptif Kconfig
        ├── external.mk         Script Buildroot pour la compilation/installation
        └── src             
            ├── clientrfcomm.c  Fichier source
            └── Makefile        Makefile
```

*br-external/external.desc*
```text
name: BTCOMPONENTS
desc: Bluetooth components for Raspberry Pi 3
```

*br-external/Config.in:* 
```text
source "$BR2_EXTERNAL_BTCOMPONENTS_PATH/package/clientrfcomm/Config.in"
```

*br-external/external.mk*
```text
include $(sort $(wildcard $(BR2_EXTERNAL_BTCOMPONENTS_PATH)/package/*/*.mk))
```

*br-external/package/clientrfcomm/Config.in*
```text
config BR2_PACKAGE_CLIENTRFCOMM
    bool "Client RFCOMM"
    help
      Client bluetooth RFCOMM.

      https://cboyer.github.io/
```

*br-external/package/clientrfcomm/external.mk*
```text
################################################################################
#
# clientrfcomm
#
################################################################################

CLIENTRFCOMM_VERSION = 1.0
CLIENTRFCOMM_SITE = $(BR2_EXTERNAL_BTCOMPONENTS_PATH)/package/clientrfcomm/src
CLIENTRFCOMM_SITE_METHOD = local

define CLIENTRFCOMM_BUILD_CMDS
    $(MAKE) CC="$(TARGET_CC)" LD="$(TARGET_LD)" -C $(@D)
endef

define CLIENTRFCOMM_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/clientrfcomm $(TARGET_DIR)/usr/bin
endef

$(eval $(generic-package))
```

*br-external/package/clientrfcomm/src/Makefile*
```text
CC = gcc
CFLAGS = -Wall -Werror -O2

.PHONY: clean

clientrfcomm: clientrfcomm.c
	$(CC) $(CFLAGS) -lbluetooth -o '$@' '$<'

clean:
	rm clientrfcomm
```

Ne pas oublier le code source dans *br-external/package/clientrfcomm/src/clientrfcomm.c*.


Pour inclure notre package "Client RFCOMM" (présent dans le menu "External options")
```Bash
make BR2_EXTERNAL=./br-external menuconfig
````



## Liens complémentaires

- [https://buildroot.org/downloads/manual/manual.html](https://buildroot.org/downloads/manual/manual.html)
- [https://people.csail.mit.edu/albert/bluez-intro/x502.html](https://people.csail.mit.edu/albert/bluez-intro/x502.html)

