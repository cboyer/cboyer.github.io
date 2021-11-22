---
title: "Installation de Kodi sous FreeBSD 13"
date: "2021-11-12T18:20:14-05:00"
updated: "2021-11-20T21:59:14-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [FreeBSD, Kodi]
abstract: "Installation de Kodi sous FreeBSD 13"
---


Certains paramètres présentés sont spécifiques à la configuration matérielle d'un système avec Intel Braswell.


## Installation de Kodi depuis les paquets


### Installation des paquets avec pkg

```Console
pkg install kodi kodi-addon-pvr.iptvsimple libbluray libcec dav1d lcms2 libass libcrossguid curl ffmpeg libfmt fstrcmp lzo2 spdlog sqlite3 taglib waylandpp libGLU xorg-server xinit xorg-drivers drm-kmod xf86-video-intel libva-intel-driver libvdpau-va-gl xterm py38-sqlite3
```

Charger le module KMS au boot via `/etc/rc.conf`
```Console
sysrc kld_list+=i915kms
```


### Configuration de Xorg

Générer automatiquement une configuration élémentaire
```Console
Xorg -configure
mv xorg.conf.new /etc/X11/xorg.conf
```

Configuration avancée de Xorg, dans `/usr/local/etc/X11/xorg.conf.d/monitor.conf`
```Text
Section "Monitor"
    Identifier   "Monitor0"
    VendorName   "Monitor Vendor"
    ModelName    "Monitor Model"
    Modeline "1920x1080_60.00"  172.80  1920 2040 2248 2576  1080 1081 1084 1118  -HSync +Vsync
    Modeline "3840x2160_30.00"  339.57  3840 4080 4496 5152  2160 2161 2164 2197  -HSync +Vsync
    #Option "PreferredMode" "3840x2160@30.0"
    Option "PreferredMode" "1920x1080@60.0"
EndSection
```

Pour activer l'accélération matérielle, dans `/usr/local/etc/X11/xorg.conf.d/card.conf`
```Text
Section "Device"
    Identifier "Card0"
    Driver "modesetting"
    Option "DPMS"
    Option "DRI" "3"
    Option "AccelMethod" "glamor"
EndSection
```

Création du compte utilisateur kodi

```Console
pw user add -n kodi -c 'Kodi Media Player' -d /home/kodi -G video -m -s /bin/csh
```

> Si l'utilisateur kodi peut être crée à l'installation de FreeBSD puis modifié avec `pw group mod wheel -m kodi` par exemple.
> Pour changer de shell `chsh -s /usr/local/bin/bash kodi`.

Tester l'exécution de Kodi:
```Console
su -m kodi -c 'setenv HOME /home/kodi && /usr/local/bin/xinit /usr/local/bin/kodi-standalone -- -nocursor :0 -nolisten tcp'
```

### Autologin et lancement automatique de Kodi

Dans `/etc/gettytab` 
```Text
# autologin kodi
A|Al|Autologin console:\
  :ht:np:sp#115200:al=kodi
```

Dans `/etc/ttys`
```Text
#ttyv1  "/usr/libexec/getty Pc"         xterm   onifexists secure
ttyv1   "/usr/libexec/getty Al"         xterm   onifexists secure
```

Ajouter dans `/home/kodi/.cshrc`
```Bash
setenv LIBVA_DRIVER_NAME i965
setenv LIBVA_DRIVERS_PATH /usr/local/lib/dri
set XPID = `/usr/bin/pgrep xinit`

if ( { [ -n "$XPID" ] } ) then
    echo "X is already running"
else
    /usr/local/bin/xinit /usr/local/bin/kodi-standalone -- -nocursor :0 -nolisten tcp
    logout
endif
```

### Configuration du chargeur d'amorçage

Ajouter dans `/boot/loader.conf`.
```Text
autoboot_delay="-1"
hw.vga.textmode=0
kern.vt.fb.default_mode="800x600"
```


### Support des partitions EXT4

```Console
pkg install fusefs-lkl
kldload fusefs
sysrc kld_list+=fusefs
```

Pour tester
```Console
mount -t fuse -o rw,mountprog=/usr/local/bin/lklfuse,type=ext4,allow_other /dev/ada1s1 /data
```

Ajouter dans `/etc/fstab` pour que la partition soit montée au démarrage
```Text
/dev/ada1s1             /data           fuse    rw,mountprog=/usr/local/bin/lklfuse,type=ext4,allow_other,late 0 0
```

> Pour les volumes NTFS il faut installer le paquet `fusefs-ntfs`.


### Installation de Samba4

pkg install samba413

La configuration dans `/usr/local/etc/smb4.conf`
```Text
[global]
    workgroup = WORKGROUP
    realm = WORKGROUP
    netbios name = kodi

[data]
    path = /data
    public = no
    writable = yes
    printable = no
    guest ok = no
    valid users = smbuser
```

```Console
sysrc samba_server_enable="YES"
service samba_server start
```





## Compilation et installation de Kodi avec les ports uniquement

Installation de l'arbre de sports et portmaster
```Console
portsnap fetch extract
cd /usr/ports/ports-mgmt/portmaster
make install clean
rehash
portmaster -L
```

Pour installer les ports, nous utiliserons `portmaster` qui permet notamment d'utiliser les paquets précompilés pour les dépendances avec `-P`.
La méthode traditionnelle pour installer des ports sans `portmaster` se résume à:
```Console
cd /usr/ports
make quicksearch name=htop
cd /usr/ports/sysutils/htop
make config-recursive
make
```

Installer les source du noyau pour la version/architecture courante (nécessaire pour compiler certains pilotes par la suite)
```Console
cd /tmp
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/13.0-RELEASE/src.txz
tar -C / -zxvf src.txz
rm /tmp/src.txz
```

Installer le pilote DRM
```Console
portmaster -Gd graphics/drm-kmod
sysrc kld_list+=i915kms
kldload i915kms
```

Installer le pilote i965 (non contenu dans mesa-dri) et VAAPI pour le décodage matérielle
```Console
cd graphics/mesa-devel
make config
portmaster -Gd graphics/mesa-devel
portmaster -Gd multimedia/libva-intel-driver
```

Configuration et compilation de Kodi (options GBM/OpenGLES)
```Console
cd /usr/ports/multimedia/kodi
make config
portmaster -Gd --update-if-newer multimedia/kodi
mkdir /usr/local/lib/kodi/addons
```



### Compilation de IPVR Simple Client

La version de Kodi issue des ports appartient à la branche Matrix (version 19), IPVR Simple Client doit être issu de la même branche pour assurer sa compatibilité.
```Console
pkg install cmake git
cd /tmp
git clone --branch 19.3-Matrix https://github.com/xbmc/xbmc.git
git clone --depth 1 --branch 19.0.2-Matrix https://github.com/kodi-pvr/pvr.iptvsimple
cd pvr.iptvsimple && mkdir build && cd build
cmake -DADDONS_TO_BUILD=pvr.iptvsimple -DADDON_SRC_PREFIX=../.. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=../../xbmc/addons -DPACKAGE_ZIP=1 ../../xbmc/cmake/addons
```

Ajouter `-fPIC` dans les directives de `CMakeCache.txt`
```Text
CMAKE_CXX_FLAGS:STRING=-fPIC
CMAKE_C_FLAGS:STRING=-fPIC
```

Lancer la compilation
```Console
make
```

Copier les fichiers
```Console
mkdir /usr/local/lib/kodi/addons/pvr.iptvsimple/
mkdir /usr/local/share/kodi/addons/pvr.iptvsimple/

cp ../../xbmc/addons/pvr.iptvsimple/pvr.iptvsimple.so* /usr/local/lib/kodi/addons/pvr.iptvsimple/
cp ../../xbmc/addons/pvr.iptvsimple/addon.xml /usr/local/share/kodi/addons/pvr.iptvsimple/
cp ../../xbmc/addons/pvr.iptvsimple/changelog.txt /usr/local/share/kodi/addons/pvr.iptvsimple/
cp ../../xbmc/addons/pvr.iptvsimple/icon.png /usr/local/share/kodi/addons/pvr.iptvsimple/
cp -r ../../xbmc/addons/pvr.iptvsimple/resources/ /usr/local/share/kodi/addons/pvr.iptvsimple/resources
```


### Installer inputstream.ffmpegdirect

```Console
cd /tmp
git clone --depth 1 --branch Matrix https://github.com/xbmc/inputstream.ffmpegdirect.git
cd inputstream.ffmpegdirect && mkdir build && cd build
cmake -DADDONS_TO_BUILD=inputstream.ffmpegdirect -DADDON_SRC_PREFIX=../.. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=../../xbmc/build/addons -DPACKAGE_ZIP=1 ../../xbmc/cmake/addons
gmake

mkdir /usr/local/lib/kodi/addons/inputstream.ffmpegdirect
mkdir /usr/local/share/kodi/addons/inputstream.ffmpegdirect

cp ../../xbmc/build/addons/inputstream.ffmpegdirect/inputstream.ffmpegdirect.so* /usr/local/lib/kodi/addons/inputstream.ffmpegdirect
cp ../../xbmc/build/addons/inputstream.ffmpegdirect/addon.xml /usr/local/share/kodi/addons/inputstream.ffmpegdirect
cp ../../xbmc/build/addons/inputstream.ffmpegdirect/changelog.txt /usr/local/share/kodi/addons/inputstream.ffmpegdirect
cp ../../xbmc/build/addons/inputstream.ffmpegdirect/icon.png /usr/local/share/kodi/addons/inputstream.ffmpegdirect
cp -r ../../xbmc/build/addons/inputstream.ffmpegdirect/resources/ /usr/local/share/kodi/addons/inputstream.ffmpegdirect/resources
```

### Installer inputstream.adaptive

```Console
cd /tmp
git clone --depth 1 --branch Matrix https://github.com/xbmc/inputstream.adaptive
cd inputstream.adaptive && mkdir build && cd build
cmake -DADDONS_TO_BUILD=inputstream.adaptive -DADDON_SRC_PREFIX=../.. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=../../xbmc/build/addons -DPACKAGE_ZIP=1 ../../xbmc/cmake/addons
gmake

mkdir /usr/local/lib/kodi/addons/inputstream.adaptive
mkdir /usr/local/share/kodi/addons/inputstream.adaptive

cp ../../xbmc/build/addons/inputstream.adaptive/inputstream.adaptive.so* /usr/local/lib/kodi/addons/inputstream.adaptive
cp ../../xbmc/build/addons/inputstream.adaptive/libssd_wv.so /usr/local/lib/kodi/addons/inputstream.adaptive
cp ../../xbmc/build/addons/inputstream.adaptive/addon.xml /usr/local/share/kodi/addons/inputstream.adaptive
cp -r ../../xbmc/build/addons/inputstream.adaptive/resources/ /usr/local/share/kodi/addons/inputstream.adaptive/resources
```

### Installer inputstream.rtmp

```Console
cd /tmp
git clone --depth 1 --branch Matrix https://github.com/xbmc/inputstream.rtmp
cd inputstream.rtmp && mkdir build && cd build
cmake -DADDONS_TO_BUILD=inputstream.rtmp -DADDON_SRC_PREFIX=../.. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=../../xbmc/kodi-build/addons -DPACKAGE_ZIP=1 ../../xbmc/cmake/addons
```

Ajouter `set(OPENSSL_TARGET BSD-x86_64)` dans `../depends/common/openssl/CMakeLists.txt` avant la suite de fonctions `list`.
Ajouter `-fPIC` dans les directives de `CMakeCache.txt`
```Text
CMAKE_CXX_FLAGS:STRING=-fPIC
CMAKE_C_FLAGS:STRING=-fPIC
```

Lancer la compilation
```Console
make

mkdir /usr/local/lib/kodi/addons/inputstream.rtmp
mkdir /usr/local/share/kodi/addons/inputstream.rtmp

cp ../../xbmc/kodi-build/addons/inputstream.rtmp/inputstream.rtmp.so* /usr/local/lib/kodi/addons/inputstream.rtmp
cp ../../xbmc/kodi-build/addons/inputstream.rtmp/addon.xml /usr/local/share/kodi/addons/inputstream.rtmp
cp ../../xbmc/kodi-build/addons/inputstream.rtmp/icon.png /usr/local/share/kodi/addons/inputstream.rtmp
cp -r ../../xbmc/kodi-build/addons/inputstream.rtmp/resources/ /usr/local/share/kodi/addons/inputstream.rtmp/resources
```



### Lectures complémentaires
- [https://docs.freebsd.org/en/books/handbook/ports/](https://docs.freebsd.org/en/books/handbook/ports/)
- [https://amissing.link/freebsd-entertainment-center.html](https://amissing.link/freebsd-entertainment-center.html)
- [https://forums.freebsd.org/threads/trouble-calling-startx-in-start-up-script.22304/#post-125992](https://forums.freebsd.org/threads/trouble-calling-startx-in-start-up-script.22304/#post-125992)
- [https://forums.freebsd.org/threads/mounting-a-logical-ext4-partition-in-freebsd.72286/](https://forums.freebsd.org/threads/mounting-a-logical-ext4-partition-in-freebsd.72286/)
