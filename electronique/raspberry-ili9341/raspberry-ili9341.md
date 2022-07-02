---
title: "Écran à contrôleur ILI9341 et Raspberry Pi"
date: "2021-07-21T10:34:12-04:00"
updated: "2021-07-21T10:34:12-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Électronique"
keywords: [ILI9341, Raspberry, fbcp-ili9341, spi]
abstract: |
  Utiliser un écran à base de contrôleur ILI9341 avec un Raspberry Pi pour dupliquer la sortie HDMI.
---

fbcp-ili9341 permet de cloner la sortie HDMI sur un écran doté d'un contrôleur ILI9341 (bus SPI). 
Il prend en charge le redimensionnement automatique vers 320x240 pixel au coût d'une consommation CPU accrue. Pour ne pas utiliser cette fonctionnalité et limiter l'utilisation du CPU il faut définir la résolution HDMI à 320x240 en modifiant le fichier `config.txt`:

```text
hdmi_group=2
hdmi_mode=87
hdmi_cvt=320 240 60 1 0 0 0
hdmi_force_hotplug=1
```

Concernant l'interconnexion Raspberry/ILI9341, fbcp-ili9341 utilise par défaut les GPIO SPI_0 (non configurables). Seuls DC et Reset sont paramétrables, MISO (GPIO 9) n'est pas utilisé.

| Raspberry | ILI9341 | Fonction          |
|-----------|---------|--------------------
| 2         | VCC     | Alimentation 3.3v |
| 6         | GND     | Alimentation      |
| 24/GPIO8  | CS      | Cable select      |
| 13/GPIO27 | Reset   | Reset             |
| 15/GPIO22 | DC      | Data control      |
| 19/GPIO10 | MOSI    | MOSI              |
| 23/GPIO11 | SCK     | Clock             |
| 16/GPIO23 | LED     | Éclairage         |


Pour ne pas utiliser la fonction de mise ne veille en cas d'inactivité, `LED` peut être connectée à `VCC` (3.3V).


Pour compiler le programme (nécessite `git` et `cmake`):

```Console
git clone https://github.com/juj/fbcp-ili9341
cd fbcp-ili9341
mkdir build

#Supprime l'option de mise en veille de l'écran
sed -i '/^#define BACKLIGHT_CONTROL_FROM_KEYBOARD/c\//#define BACKLIGHT_CONTROL_FROM_KEYBOARD' config.h

#Pour un Raspberry Pi 3 (-DARMV8A=ON) avec un écran générique (-DILI9341=ON)
cmake -DILI9341=ON -DGPIO_TFT_DATA_CONTROL=22 -DGPIO_TFT_RESET_PIN=27 -DGPIO_TFT_BACKLIGHT=23 \
      -DSPI_BUS_CLOCK_DIVISOR=6 -DARMV8A=ON -DBACKLIGHT_CONTROL=ON -DSTATISTICS=0

#Exécution, nécessite les droits root
sudo ./fbcp-ili9341
```

L'option `-DBACKLIGHT_CONTROL=ON` ne peut être retirée sans quoi l'écran reste inactif. Pour retirer la mise en veille après un délais, il faut commenter la ligne `#define BACKLIGHT_CONTROL_FROM_KEYBOARD` dans le fichier `config.h` ou bien connecter `LED` à `VCC` (3.3V).

Le binaire produit utilise les librairies suivantes:
```text
linux-vdso.so.1 (0x7eff9000)
/usr/lib/arm-linux-gnueabihf/libarmmem-${PLATFORM}.so => /usr/lib/arm-linux-gnueabihf/libarmmem-v7l.so (0x76ee0000)
libpthread.so.0 => /lib/arm-linux-gnueabihf/libpthread.so.0 (0x76eb6000)
libbcm_host.so => /opt/vc/lib/libbcm_host.so (0x76e8f000)
libatomic.so.1 => /lib/arm-linux-gnueabihf/libatomic.so.1 (0x76e76000)
libstdc++.so.6 => /lib/arm-linux-gnueabihf/libstdc++.so.6 (0x76d2f000)
libm.so.6 => /lib/arm-linux-gnueabihf/libm.so.6 (0x76cad000)
libgcc_s.so.1 => /lib/arm-linux-gnueabihf/libgcc_s.so.1 (0x76c80000)
libc.so.6 => /lib/arm-linux-gnueabihf/libc.so.6 (0x76b32000)
/lib/ld-linux-armhf.so.3 (0x76ef5000)
libvchiq_arm.so => /opt/vc/lib/libvchiq_arm.so (0x76b1c000)
libvcos.so => /opt/vc/lib/libvcos.so (0x76b03000)
libdl.so.2 => /lib/arm-linux-gnueabihf/libdl.so.2 (0x76af0000)
librt.so.1 => /lib/arm-linux-gnueabihf/librt.so.1 (0x76ad9000)
````



## Sources

- [https://github.com/juj/fbcp-ili9341](https://github.com/juj/fbcp-ili9341)
