---
title: "Interface graphique avec Buildroot, Qt5 et Raspberry Pi 3"
date: "2021-07-22T11:04:34-04:00"
updated: "2021-07-23T17:53:00-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [Buildroot, Qt5, QML, Raspberry, Linux, EGL, OpenGLES, eglfs, eglfs_brcm, eglfs_kms]
abstract: |
  Développement d'une interface graphique Qt5/QML sur Raspberry Pi 3 avec Buildroot.
---

L'article a été rédigé en utilisant un Raspberry Pi 3 avec Buildroot 2021.05-514-g74adec4f3a qui contient Qt5 5.15.2 et un noyau 5.10.
Le Raspberry est connecté à un télévieur via HDMI.
L'objectif est d'obtenir un système minimaliste Linux sans serveur X permettant d'exécuter une application graphique tout en bénéficiant de l'accélération matérielle.

- [Utiliser eglfs_brcm comme backend](#eglfs_brcm)
- [Utiliser eglfs_kms comme backend au lieu de eglfs_brcm](#eglfs_kms)


## <a name="eglfs_brcm"></a>Utiliser eglfs_brcm comme backend

Le backend `eglfs_brcm` repose sur les pilotes graphiques propriétaires Broadcom afin de fournir un support pour OpenGLES/EGL avec les fichiers `/usr/lib/libbrcmEGL.so` et `/usr/lib/libbrcmGLESv2.so`. Ceux-ci sont fournis par le package `Rpi-userland` et les "Firmware Driver" dans le noyau.



### Configuration Buildroot

```Bash
make raspberrypi3_defconfig
make menuconfig
```

```text
System configuration → System hostname (BR2_TARGET_GENERIC_HOSTNAME="buildrootqt5")
System configuration → Root password (BR2_TARGET_GENERIC_ROOT_PASSWD="root")
System configuration → remount root filesystem read-write during boot (BR2_TARGET_GENERIC_REMOUNT_ROOTFS_RW=n)
System configuration → Root filesystem overlay directories (BR2_ROOTFS_OVERLAY=output/rootfs_overlay)

Toolchain → Enable WCHAR support (BR2_TOOLCHAIN_BUILDROOT_WCHAR=y)
Target packages → Hardware handling → rpi-userland (BR2_PACKAGE_RPI_USERLAND=y)

Target packages → Graphic libraries and applications (graphic/text) → Qt5 (BR2_PACKAGE_QT5=y)
Target packages → Graphic libraries and applications (graphic/text) → Qt5 → Custom configuration options (BR2_PACKAGE_QT5BASE_CUSTOM_CONF_OPTS [=-skip qtconnectivity -skip qtnetwork -skip qtgamepad -no-feature-vnc -no-feature-accessibility -nomake tests])
Target packages → Graphic libraries and applications (graphic/text) → Qt5 → eglfs support (BR2_PACKAGE_QT5BASE_EGLFS=y)
Target packages → Graphic libraries and applications (graphic/text) → Qt5 → Default graphical platform (BR2_PACKAGE_QT5BASE_DEFAULT_QPA="eglfs")
```

Peuvent être désactivés:
```text
Target packages → Graphic libraries and applications (graphic/text) → mesa3d (BR2_PACKAGE_MESA3D=n)
Target packages → Libraries → Graphics → libdrm (BR2_PACKAGE_LIBDRM=n)
```

Les librairies C `uClibc-ng` et `glibc` fonctionnent avec ces modules Qt5 (`musl` n'a pas été testée) cependant certains packages comme `qt5webengine` nécessitent `glibc`.
D'autres packages comme `qt5quickcontrols2`, `qt5graphicaleffects` et `qt5wayland` peuvent être ajoutés selon les besoins applicatifs (ce qui n'est pas le cas pour notre application de test).


Sauvegarde de la configuration Buildroot:
```Bash
make savedefconfig BR2_DEFCONFIG=./buildrootqt5.config
```


### Configuration du noyau Linux

Pour la configuration du noyau, aucun pilote graphique particulier (DRM, VC4) n'est nécessaire, il faut veiller à la présence des "Firmware Driver" (présents par défaut):
```Bash
make linux-menuconfig
```

```text
Firmware Drivers → Raspberry Pi Firmware Driver (RASPBERRYPI_FIRMWARE=y)
Device Drivers > Graphics support > Direct Rendering Manager (XFree86 4.1.0 and higher DRI support) (DRM=n)
```

Sauvegarde de la configuration du noyau:
```Bash
cp output/build/linux-custom/.config linux.config
```

### Overlay

Pour inclure nos fichiers nous allons utiliser un overlay, tous les fichiers contenu dans `output/rootfs_overlay` (considéré par Buildroot comme référence à la racine) seront présents dans l'image finale.

`output/rootfs_overlay/usr/share/fonts/dejavu-sans-webfont.ttf`: Qt5 ne fournit plus de police de caractères, il faut au minimum une police TTF sur le système. 
Buildroot peut également inclure des polices: *Target packages → Fonts, cursors, icons, sounds and themes → DejaVu fonts (BR2_PACKAGE_DEJAVU)*. 

`output/rootfs_overlay/root/test.sh`: script de lancement de l'application QML `box.qml`.
```Bash
#!/bin/sh
export QT_QPA_PLATFORM=eglfs
export QT_QPA_EGLFS_INTEGRATION=eglfs_brcm
export QT_QPA_EGLFS_ALWAYS_SET_MODE=1
export QT_XKB_CONFIG_ROOT=/tmp

#Backends Qt5 disponibles, à titre indicatif
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/qt/plugins/platforms

#Dossier des polices TTF
export QT_QPA_FONTDIR=/usr/share/fonts

#Active le clavier dans le terminal en arrière plan (permet notamment le CTRL+C)
export QT_QPA_ENABLE_TERMINAL_KEYBOARD=1

#Cache le curseur de la souris
export QT_QPA_EGLFS_HIDECURSOR=1

qmlscene box.qml -platform eglfs
```

> Il n'est pas necéssaire d'utiliser `export LD_LIBRARY_PATH=/opt/vc/lib/:$LD_LIBRARY_PATH` car le package Rpi-userland place les librairies dans `/usr/lib` au lieu de `/opt/vc/lib`.


`output/rootfs_overlay/root/box.qml`: l'application QML de test qui sera exécutée avec `qmlscene`. Il s'agit d'une boîte rouge déplaçable avec les flềches du clavier et les cliques d'une souris.
```QML
import QtQuick 2.0

Item {
    width: 800; height: 600
    focus: true
    Keys.onPressed: {
        if (event.key == Qt.Key_Enter) {
            rect.x = 600
            rect.y = 400
        }
        if (event.key == Qt.Key_Space) {
            rect.x = 50
            rect.y = 50
        }
        if (event.key == Qt.Key_Left) {
            rect.x = rect.x - 50
        }
        if (event.key == Qt.Key_Right) {
            rect.x = rect.x + 50
        }
        if (event.key == Qt.Key_Down) {
            rect.y = rect.y + 50
        }
        if (event.key == Qt.Key_Up) {
            rect.y = rect.y - 50
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Rectangle {
        id: rect
        width: 100; height: 100
        color: "red"

        Behavior on x { PropertyAnimation { duration: 500 } }
        Behavior on y { PropertyAnimation { duration: 500 } }

        Text {
            text: "Hello\nworld!"
            font.pointSize: 24; font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: { rect.x = mouse.x; rect.y = mouse.y; }
    }
}
```

> Si la résolution est supérieur à 800x600 pixels, l'application utilisera l'ensemble de l'espace disponible sans tenir compte des dimmensions `width: 800; height: 600`.



### Compilation

Lancer la compilation et la création de l'image:
```Bash
make
```

Pour vérifier les options de compilation du package `qt5base`, notamment les backends disponibles:
```Bash
cat ./output/build/qt5base-5.15.2/config.summary
```

```text
QPA backends:
  DirectFB ............................... no
  EGLFS .................................. yes
  EGLFS details:
    EGLFS OpenWFD ........................ no
    EGLFS i.Mx6 .......................... no
    EGLFS i.Mx6 Wayland .................. no
    EGLFS RCAR ........................... no
    EGLFS EGLDevice ...................... no
    EGLFS GBM ............................ no
    EGLFS VSP2 ........................... no
    EGLFS Mali ........................... no
    EGLFS Raspberry Pi ................... yes
    EGLFS X11 ............................ no
  LinuxFB ................................ no
  VNC .................................... no
```

Copie de l'image générée vers la carte SD:
```Bash
sudo dd if=output/images/sdcard.img of=/dev/mmcblk0 status=progress
```

Après démarrer le système sur le Raspberry, exécuter `test.sh`:
```Bash
sh test.sh
```







## <a name="eglfs_kms"></a>Utiliser eglfs_kms comme backend au lieu de eglfs_brcm

Au lieu d'utiliser le pilote propriétaire Broadcom, nous allons utiliser le backend OpenGLES libre fourni avec Mesa3d ainsi que le pilote VC4.



### Configuration Buildroot

```Bash
make raspberrypi3_defconfig
make menuconfig
```

```text
System configuration → System hostname (BR2_TARGET_GENERIC_HOSTNAME="buildrootqt5")
System configuration → Root password (BR2_TARGET_GENERIC_ROOT_PASSWD="root")
System configuration → remount root filesystem read-write during boot (BR2_TARGET_GENERIC_REMOUNT_ROOTFS_RW=n)
System configuration → Root filesystem overlay directories (BR2_ROOTFS_OVERLAY=output/rootfs_overlay)
System configuration → Custom scripts to run before creating filesystem images (BR2_ROOTFS_POST_BUILD_SCRIPT=board/raspberrypi3/post-build.sh output/post-build-config.sh)

System configuration → /dev management (Dynamic using devtmpfs + eudev) (BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_EUDEV=y)
Toolchain → Enable WCHAR support (BR2_TOOLCHAIN_BUILDROOT_WCHAR=y)

Target packages → Libraries → Graphics → libdrm (BR2_PACKAGE_LIBDRM=y)
Target packages → Libraries → Graphics → libdrm → vc4 (BR2_PACKAGE_LIBDRM_VC4=y)
Target packages → Graphic libraries and applications (graphic/text) → mesa3d (BR2_PACKAGE_MESA3D=y)
Target packages → Graphic libraries and applications (graphic/text) → mesa3d → Gallium vc4 driver (BR2_PACKAGE_MESA3D_GALLIUM_DRIVER_VC4=y)
Target packages → Graphic libraries and applications (graphic/text) → mesa3d → OpenGL ES (BR2_PACKAGE_MESA3D_OPENGL_ES=y)

Target packages → Graphic libraries and applications (graphic/text) → Qt5 (BR2_PACKAGE_QT5=y)
Target packages → Graphic libraries and applications (graphic/text) → Qt5 → Custom configuration options (BR2_PACKAGE_QT5BASE_CUSTOM_CONF_OPTS [=-skip qtconnectivity -skip qtnetwork -skip qtgamepad -no-feature-vnc -no-feature-accessibility -nomake tests])
Target packages → Graphic libraries and applications (graphic/text) → Qt5 → eglfs support (BR2_PACKAGE_QT5BASE_EGLFS=y)
Target packages → Graphic libraries and applications (graphic/text) → Qt5 → Default graphical platform (BR2_PACKAGE_QT5BASE_DEFAULT_QPA="eglfs")
```

Les packages *mesa3d → OpenGL ES (BR2_PACKAGE_MESA3D_OPENGL_ES=y)* et *rpi-userland (BR2_PACKAGE_RPI_USERLAND=y)* ne peuvent cohabiter pour fournir un support OpenGLES.

Nous utiliserons un script post-build `output/post-build-config.sh` en plus de celui par défaut `board/raspberrypi3/post-build.sh`. Ils doivent être séparés par un espace.

L'utilisation de udev (eudev) est util pour la détection automatique des périphériques et charger les modules requis ce qui permettra de rendre disponible le GPU dans `/dev/dri/card0`. Il est possible de se passer de udev en chargeant les modules requis manuellement (cas exposé plus tard).

Pas besoin d'inclure mesa3d → Gallium v3d driver.


Sauvegarde de la configuration Buildroot:
```Bash
make savedefconfig BR2_DEFCONFIG=./buildrootqt5_vc4.config
```


### Configuration du noyau Linux

Pour la configuration du noyau, il faut inclure le pilote VC4:
```Bash
make linux-menuconfig
```

```text
Device Drivers → Graphics support → Direct Rendering Manager (XFree86 4.1.0 and higher DRI support) (CONFIG_DRM=y)
Device Drivers → Graphics support → Broadcom VC4 Graphics (CONFIG_DRM_VC4=m)
```
> Pas besoin d'inclure *Device Drivers → Graphics support → Broadcom V3D 3.x and newer (CONFIG_DRM_V3D)*

Sauvegarde de la configuration du noyau:
```Bash
cp output/build/linux-custom/.config linux_vc4.config
```


### Overlay

Le contenu de l'overlay `output/rootfs_overlay` reste le même sauf pour le script `output/rootfs_overlay/root/test.sh` qui intègre une valeur différente pour `QT_QPA_EGLFS_INTEGRATION` et une nouvelle variable `QT_QPA_EGLFS_NO_LIBINPUT`:

```Bash
#!/bin/sh
export QT_QPA_PLATFORM=eglfs
export QT_QPA_EGLFS_INTEGRATION=eglfs_kms
export QT_QPA_EGLFS_ALWAYS_SET_MODE=1
export QT_XKB_CONFIG_ROOT=/tmp

#Backends Qt5 disponibles, à titre indicatif
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/qt/plugins/platforms

#Dossier des polices TTF
export QT_QPA_FONTDIR=/usr/share/fonts

#Active le clavier dans le terminal en arrière plan (permet notamment le CTRL+C)
export QT_QPA_ENABLE_TERMINAL_KEYBOARD=1

#Désactive Libinput, corrige le problème de clavier non fonctionnel
export QT_QPA_EGLFS_NO_LIBINPUT=1

#Cache le curseur de la souris
export QT_QPA_EGLFS_HIDECURSOR=1

qmlscene box.qml -platform eglfs
```

> Avec l'ajout de udev, Qt5 utilise son composant evdev qui nécessite la désactivation de Libinput avec `QT_QPA_EGLFS_NO_LIBINPUT=1`.


### Script post-build

Le chargement du pilote VC4 au démarrage nécessite l'ajout des directives `gpu_mem=128` et `dtoverlay=vc4-kms-v3d` dans le fichier `config.txt` de la partition de boot. 
Pour cela nous utiliserons un script post-build `post-build-config.sh` dans le dossier `output/` (déjà configuré dans Buildroot).

post-build-config.sh:
```Bash
#!/bin/sh
set -u
set -e

if ! grep -qE '^gpu_mem=128' "${BINARIES_DIR}/rpi-firmware/config.txt"  && ! grep -qE '^dtoverlay=vc4-kms-v3d' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
    echo "Adding 'gpu_mem=128' and 'dtoverlay=vc4-kms-v3d' to config.txt (load VC4)."
    echo "gpu_mem=128" >> "${BINARIES_DIR}/rpi-firmware/config.txt"
    echo "dtoverlay=vc4-kms-v3d" >> "${BINARIES_DIR}/rpi-firmware/config.txt"
fi
```

Ne pas oublier de donner les droits d'exécution avec `chmod +x output/post-build-config.sh`.


### Compilation

Lancer la compilation et la création de l'image:
```Bash
make
```

Pour vérifier les options de compilation du package `qt5base`, notamment les backends disponibles:
```Bash
cat ./output/build/qt5base-5.15.2/config.summary
```

```text
QPA backends:
  DirectFB ............................... no
  EGLFS .................................. yes
  EGLFS details:
    EGLFS OpenWFD ........................ no
    EGLFS i.Mx6 .......................... no
    EGLFS i.Mx6 Wayland .................. no
    EGLFS RCAR ........................... no
    EGLFS EGLDevice ...................... yes
    EGLFS GBM ............................ yes
    EGLFS VSP2 ........................... no
    EGLFS Mali ........................... no
    EGLFS Raspberry Pi ................... no
    EGLFS X11 ............................ no
  LinuxFB ................................ no
  VNC .................................... no
```


Copie de l'image générée vers la carte SD:
```Bash
sudo dd if=output/images/sdcard.img of=/dev/mmcblk0 status=progress
```

Après démarrer le système sur le Raspberry, exécuter `test.sh` pour lancer l'application QML:
```Bash
sh test.sh
```



### Se passer de udev (eudev)

Il est possible de ne pas inclure udev (dans Buildroot: *System configuration → /dev management*).
Les modules chargés automatiquement par udev (liste récupérée avec `lsmod`):
```text
Module                  Size  Used by    Tainted: G  
snd_soc_hdmi_codec     20480  1 
brcmfmac              327680  0 
brcmutil               24576  1 brcmfmac
sha256_generic         16384  0 
libsha256              20480  1 sha256_generic
vc4                   249856  2 
snd_soc_core          229376  2 snd_soc_hdmi_codec,vc4
snd_compress           20480  1 snd_soc_core
cfg80211              782336  1 brcmfmac
snd_pcm_dmaengine      16384  1 snd_soc_core
snd_pcm               114688  4 snd_soc_hdmi_codec,snd_soc_core,snd_compress,snd_pcm_dmaengine
snd_timer              36864  1 snd_pcm
snd                    77824  5 snd_soc_hdmi_codec,snd_soc_core,snd_compress,snd_pcm,snd_timer
raspberrypi_hwmon      16384  0 
i2c_bcm2835            16384  0 
vc_sm_cma              32768  0 
uio_pdrv_genirq        16384  0 
uio                    20480  1 uio_pdrv_genirq
fixed                  16384  0 
```

Pour se passer de udev et obtenir `/dev/dri/card0`, certains modules doivent être chargés (via un script ou manuellement) avec `modprobe`:
```Bash
#!/bin/sh
modprobe snd_soc_hdmi_codec
modprobe i2c_bcm2835
modprobe vc4
modprobe vc_sm_cma
```

Résultat dans `dmesg`:
```text
[   40.318528] fb0: switching to vc4drmfb from simple
[   40.325374] Console: switching to colour dummy device 80x30
[   40.662845] vc4-drm soc:gpu: bound 3f400000.hvs (ops vc4_hvs_ops [vc4])
[   40.677294] vc4-drm soc:gpu: bound 3f902000.hdmi (ops vc4_hdmi_ops [vc4])
[   40.684485] vc4-drm soc:gpu: bound 3f806000.vec (ops vc4_vec_ops [vc4])
[   40.691473] vc4-drm soc:gpu: bound 3f004000.txp (ops vc4_txp_ops [vc4])
[   40.698433] vc4-drm soc:gpu: bound 3f206000.pixelvalve (ops vc4_crtc_ops [vc4])
[   40.706101] vc4-drm soc:gpu: bound 3f207000.pixelvalve (ops vc4_crtc_ops [vc4])
[   40.713734] vc4-drm soc:gpu: bound 3f807000.pixelvalve (ops vc4_crtc_ops [vc4])
[   40.721306] vc4-drm soc:gpu: bound 3fc00000.v3d (ops vc4_v3d_ops [vc4])
[   40.731228] [drm] Initialized vc4 0.0.0 20140616 for soc:gpu on minor 0
[   40.881762] Console: switching to colour frame buffer device 240x67
[   40.921477] vc4-drm soc:gpu: [drm] fb0: vc4drmfb frame buffer device
[   41.002400] vc_sm_cma: module is from the staging directory, the quality is unknown, you have been warned.
[   41.014768] bcm2835_vc_sm_cma_probe: Videocore shared memory driver
[   41.021175] [vc_sm_connected_init]: start
[   41.026489] [vc_sm_connected_init]: installed successfully
```



## Liens complémentaires

- [https://buildroot.org/downloads/manual/manual.html](https://buildroot.org/downloads/manual/manual.html)
- [https://doc.qt.io/qt-5/inputs-linux-device.html](https://doc.qt.io/qt-5/inputs-linux-device.html)
- [https://doc.qt.io/archives/qt-5.6/embedded-linux.html](https://doc.qt.io/archives/qt-5.6/embedded-linux.html)
- [https://doc.qt.io/qt-5/qtquickcontrols-index.html#versions](https://doc.qt.io/qt-5/qtquickcontrols-index.html#versions)
- [https://doc.qt.io/qt-5/configure-options.html](https://doc.qt.io/qt-5/configure-options.html)
