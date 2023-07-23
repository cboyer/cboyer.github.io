---
title: "Installation de Kodi sous FreeBSD 13"
date: "2021-11-12T18:20:14-05:00"
updated: "2023-06-30T12:52:14-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [FreeBSD, Kodi]
abstract: "Installation de Kodi sous FreeBSD 13."
---


Certains paramètres présentés sont spécifiques à la configuration matérielle d'un système avec Intel Braswell: les pilotes et configurations peuvent différer sur d'autres systèmes.


## Installation de Kodi depuis les paquets


### Installation des paquets avec pkg

Configurer le dépôts PKG à latest au lieu de quarterly avec le fichier `/usr/local/etc/pkg/repos/FreeBSD.conf`:
```
FreeBSD: {
url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest",
mirror_type: "srv",
signature_type: "fingerprints",
fingerprints: "/usr/share/keys/pkg",
enabled: yes
}
```

Mise à jour du système et vérifier la présence de vulnérabilité:
```Console
freebsd-update fetch install && pkg update && pkg upgrade && pkg audit
```

```Console
pkg install kodi kodi-addon-pvr.iptvsimple kodi-addon-inputstream.adaptive \
    xorg-server xinit xorg-drivers drm-kmod xf86-video-intel libva-intel-driver \
    py39-sqlite3 libvdpau-va-gl
```

Les paquets `kodi-addon-inputstream.adaptive` et `py39-sqlite3` sont nécessaires à l'extension YouTube permettant de visionner les bandes-annonces.

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
    Option "DPMS" "false"
    Option "DRI" "3"
    Option "AccelMethod" "glamor"
EndSection
```

### Création du compte utilisateur kodi

```Console
pw user add -n kodi -c 'Kodi Media Player' -d /home/kodi -G video -m -s /usr/sbin/nologin
```

> L'utilisateur kodi peut être créé à l'installation de FreeBSD puis modifié avec `pw group mod wheel -m kodi` par la suite.
> Pour changer de shell et rendre le compte utilisable: `chsh -s /usr/local/bin/bash kodi`.

Tester l'exécution de Kodi:
```Console
su -m kodi -c 'HOME=/home/kodi /usr/local/bin/xinit /usr/local/bin/kodi --standalone -- -nocursor :0 -nolisten tcp'
```

### Démarrage automatique de Kodi via rc.d (recommandé)

Créer le fichier `/usr/local/etc/X11/Xwrapper.config` avec la directive suivante pour autoriser le lancement de X sur les terminaux virtuels
```
allowed_users=anybody
```

Créer le script `/usr/local/etc/rc.d/kodi` avec les droits d'exécution
```Bash
#!/bin/sh

# PROVIDE: kodi
# REQUIRE: FILESYSTEMS DAEMON NETWORKING LOGIN
# KEYWORD: nojail shutdown

. /etc/rc.subr

name=kodi
rcvar=kodi_enable

kodi_user=root
kodi_chdir="/home/kodi"
kodi_env="PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin HOME=/home/kodi LIBVA_DRIVER_NAME=i965 LIBVA_DRIVERS_PATH=/usr/local/lib/dri"
pidfile="/var/run/${name}.pid"
stop_precmd="${name}_stop_precmd"

command="/usr/sbin/daemon"
command_args="-u kodi -P ${pidfile} -r -f /usr/local/bin/xinit /usr/local/bin/kodi --standalone -- :0 -nocursor -quiet -nolisten tcp"

load_rc_config $name
: ${kodi_enable:=no}
: ${kodi_msg="Not started."}

kodi_stop_precmd()
{
    kodi_pid="$(/usr/bin/pgrep kodi.bin)"
    /bin/kill -TERM ${kodi_pid} 2>/dev/null
    /bin/pwait ${kodi_pid}
}

run_rc_command "$1"
```

> L'exécution de la chaîne Xinit > Xorg > Kodi est supervisée par `daemon` qui redémarrera l'ensemble en cas d'arrêt. C'est le PID de `daemon` qui est contrôlé par rc.d et non directement celui de Kodi. 
> La fonction `kodi_stop_precmd` permet d'attendre la fermeture de Kodi et d'éviter la corruption de la base de données SQLite possiblement causée par un arrêt direct de Xinit, Xorg ou daemon.
> Le redémarrage de Kodi ne sera effectué qu'après 1 seconde d'attente par `daemon`, ce qui laisse largement le temps à rc.d d'envoyer le signal TERM à daemon qui n'aura pas le temps de redémarré Kodi.

Activation via rc.d:
```Console
sysrc kodi_enable=YES
```

Le service kodi peut alors être géré avec la commande `service`:
```Console
service kodi start
```


### Démarrage automatique de Kodi via crontab

Créer le fichier `/usr/local/etc/X11/Xwrapper.config` avec la directive suivante pour autoriser le lancement de X sur les terminaux virtuels
```
allowed_users=anybody
```

Ajouter dans la crontab de l'utilisateur kodi la ligne suivante avec `crontab -e`
```Text
@reboot HOME=/home/kodi LIBVA_DRIVER_NAME=i965 LIBVA_DRIVERS_PATH=/usr/local/lib/dri /usr/local/bin/xinit /usr/local/bin/kodi --standalone -- -nocursor :0 -nolisten tcp > /dev/null 2>&1
```

> Il est possible d'utiliser un script pour relancer Kodi avec une boucle afin de le redémarrer en cas d'arrêt brusque.


### Démarrage automatique de Kodi via autologin

Ajouter dans `/etc/gettytab` 
```Text
# autologin kodi
A|Al|Autologin console:\
  :ht:np:sp#115200:al=kodi
```

Remplacer la ligne `ttyv1` dans `/etc/ttys`
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




## Compilation et installation de Kodi avec les ports/sources uniquement

### Récupèration des ports et installation des outils

Définition de certaines options par défaut lors de la compilation des ports dans `/etc/make.conf`
```Text
DEFAULT_VERSIONS= python=3.9 python3=3.9
OPTIONS_UNSET= X11 GUI CUPS DOCS EXAMPLES DOXYGEN PERL LUA
WITHOUT= X11 GUI CUPS DOCS EXAMPLES DOXYGEN PERL LUA

#Pour un port particulier
#devel_gettext-tools_UNSET+=EXAMPLES
```

Installation de l'arbre des ports et portmaster
```Console
portsnap fetch extract
cd /usr/ports
cd /usr/ports/ports-mgmt/portmaster
make install clean
rehash
portmaster -L
```

L'outil `portmaster` permet l'installation de ports à la place de `make install clean BATCH=YES`.
Quelques paramètres utiles pour l'utilisation de `portmaster`:

- `-P` permet d'utiliser les paquets précompilés pour les dépendances
- `-G` accepter la configuration par défaut (pas d'interaction)
- `-B` ne conserve pas de backup de l'ancien package après mise à jour (pas d'interaction)
- `-d` nettoie les distfiles

Les commandes complémentaires pour la gestion des ports:
```Console
#Chercher un port par son nom (depuis /usr/ports)
make quicksearch name=htop

#Configurer le port courant et ses dépendances
make config-recursive

#Pour supprimer la configuration du port et ses dépendances
make rmconfig-recursive

#Pour tout nettoyer (depuis /usr/ports)
find -s . -type d -name 'work' -exec make rmconfig '{}' \; -exec make clean '{}' \;
```

Installation de `git` et `cmake`
```Console
portmaster devel/git@tiny devel/cmake
```

### Installation des ports 
Installer les sources du noyau pour la version/architecture courante (nécessaire pour compiler certains pilotes par la suite)
```Console
cd /tmp
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/13.0-RELEASE/src.txz
tar -C / -zxvf src.txz
rm /tmp/src.txz
```

Installer le pilote DRM
```Console
portmaster -Bd graphics/drm-kmod
sysrc kld_list+=i915kms
kldload i915kms
```

Installer le pilote i965 (non contenu dans mesa-dri) et VAAPI pour le décodage matériel
```Console
cd graphics/mesa-devel
make config
portmaster -Bd graphics/mesa-devel
portmaster -Bd multimedia/libva-intel-driver
```

Configuration et compilation de Kodi (options GBM/OpenGLES pour se passer du serveur X)
```Console
cd /usr/ports/multimedia/kodi
make config
portmaster -Bd --update-if-newer multimedia/kodi
mkdir /usr/local/lib/kodi/addons
```


### Compilation des addons Kodi depuis les sources

#### IPVR Simple Client

La version de Kodi issue des ports appartient à la branche Matrix (version 19), IPVR Simple Client doit être issu de la même branche pour assurer sa compatibilité.
```Console
cd /tmp
git clone --branch 19.3-Matrix https://github.com/xbmc/xbmc.git
git clone --depth 1 --branch 19.0.2-Matrix https://github.com/kodi-pvr/pvr.iptvsimple
cd pvr.iptvsimple && mkdir build && cd build
cmake -DADDONS_TO_BUILD=pvr.iptvsimple -DADDON_SRC_PREFIX=../.. -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_INSTALL_PREFIX=../../xbmc/addons -DPACKAGE_ZIP=1 ../../xbmc/cmake/addons
```

Ajouter `-fPIC` dans les directives de `CMakeCache.txt`
```Text
CMAKE_CXX_FLAGS:STRING=-fPIC
CMAKE_C_FLAGS:STRING=-fPIC
```

Lancer la compilation et copier les fichiers
```Console
make
mkdir /usr/local/lib/kodi/addons/pvr.iptvsimple/
mkdir /usr/local/share/kodi/addons/pvr.iptvsimple/

cp ../../xbmc/addons/pvr.iptvsimple/pvr.iptvsimple.so* /usr/local/lib/kodi/addons/pvr.iptvsimple/
cp ../../xbmc/addons/pvr.iptvsimple/addon.xml /usr/local/share/kodi/addons/pvr.iptvsimple/
cp ../../xbmc/addons/pvr.iptvsimple/changelog.txt /usr/local/share/kodi/addons/pvr.iptvsimple/
cp ../../xbmc/addons/pvr.iptvsimple/icon.png /usr/local/share/kodi/addons/pvr.iptvsimple/
cp -r ../../xbmc/addons/pvr.iptvsimple/resources/ /usr/local/share/kodi/addons/pvr.iptvsimple/resources
```


#### inputstream.ffmpegdirect

```Console
cd /tmp
git clone --depth 1 --branch Matrix https://github.com/xbmc/inputstream.ffmpegdirect.git
cd inputstream.ffmpegdirect && mkdir build && cd build
cmake -DADDONS_TO_BUILD=inputstream.ffmpegdirect -DADDON_SRC_PREFIX=../.. -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_INSTALL_PREFIX=../../xbmc/build/addons -DPACKAGE_ZIP=1 ../../xbmc/cmake/addons
gmake

mkdir /usr/local/lib/kodi/addons/inputstream.ffmpegdirect
mkdir /usr/local/share/kodi/addons/inputstream.ffmpegdirect

cp ../../xbmc/build/addons/inputstream.ffmpegdirect/inputstream.ffmpegdirect.so* /usr/local/lib/kodi/addons/inputstream.ffmpegdirect
cp ../../xbmc/build/addons/inputstream.ffmpegdirect/addon.xml /usr/local/share/kodi/addons/inputstream.ffmpegdirect
cp ../../xbmc/build/addons/inputstream.ffmpegdirect/changelog.txt /usr/local/share/kodi/addons/inputstream.ffmpegdirect
cp ../../xbmc/build/addons/inputstream.ffmpegdirect/icon.png /usr/local/share/kodi/addons/inputstream.ffmpegdirect
cp -r ../../xbmc/build/addons/inputstream.ffmpegdirect/resources/ /usr/local/share/kodi/addons/inputstream.ffmpegdirect/resources
```

#### inputstream.adaptive

```Console
cd /tmp
git clone --depth 1 --branch Matrix https://github.com/xbmc/inputstream.adaptive
cd inputstream.adaptive && mkdir build && cd build
cmake -DADDONS_TO_BUILD=inputstream.adaptive -DADDON_SRC_PREFIX=../.. -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_INSTALL_PREFIX=../../xbmc/build/addons -DPACKAGE_ZIP=1 ../../xbmc/cmake/addons
gmake

mkdir /usr/local/lib/kodi/addons/inputstream.adaptive
mkdir /usr/local/share/kodi/addons/inputstream.adaptive

cp ../../xbmc/build/addons/inputstream.adaptive/inputstream.adaptive.so* /usr/local/lib/kodi/addons/inputstream.adaptive
cp ../../xbmc/build/addons/inputstream.adaptive/libssd_wv.so /usr/local/lib/kodi/addons/inputstream.adaptive
cp ../../xbmc/build/addons/inputstream.adaptive/addon.xml /usr/local/share/kodi/addons/inputstream.adaptive
cp -r ../../xbmc/build/addons/inputstream.adaptive/resources/ /usr/local/share/kodi/addons/inputstream.adaptive/resources
```

#### inputstream.rtmp

```Console
cd /tmp
git clone --depth 1 --branch Matrix https://github.com/xbmc/inputstream.rtmp
cd inputstream.rtmp && mkdir build && cd build
cmake -DADDONS_TO_BUILD=inputstream.rtmp -DADDON_SRC_PREFIX=../.. -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_INSTALL_PREFIX=../../xbmc/kodi-build/addons -DPACKAGE_ZIP=1 ../../xbmc/cmake/addons
```

Ajouter `set(OPENSSL_TARGET BSD-x86_64)` dans `../depends/common/openssl/CMakeLists.txt` avant la suite de fonctions `list`.
Ajouter `-fPIC` dans les directives de `CMakeCache.txt`
```Text
CMAKE_CXX_FLAGS:STRING=-fPIC
CMAKE_C_FLAGS:STRING=-fPIC
```

Lancer la compilation et copier les fichiers
```Console
make
mkdir /usr/local/lib/kodi/addons/inputstream.rtmp
mkdir /usr/local/share/kodi/addons/inputstream.rtmp

cp ../../xbmc/kodi-build/addons/inputstream.rtmp/inputstream.rtmp.so* /usr/local/lib/kodi/addons/inputstream.rtmp
cp ../../xbmc/kodi-build/addons/inputstream.rtmp/addon.xml /usr/local/share/kodi/addons/inputstream.rtmp
cp ../../xbmc/kodi-build/addons/inputstream.rtmp/icon.png /usr/local/share/kodi/addons/inputstream.rtmp
cp -r ../../xbmc/kodi-build/addons/inputstream.rtmp/resources/ /usr/local/share/kodi/addons/inputstream.rtmp/resources
```



## Lectures complémentaires
- [https://docs.freebsd.org/en/books/handbook/ports/](https://docs.freebsd.org/en/books/handbook/ports/)
- [https://amissing.link/freebsd-entertainment-center.html](https://amissing.link/freebsd-entertainment-center.html)
- [https://forums.freebsd.org/threads/trouble-calling-startx-in-start-up-script.22304/#post-125992](https://forums.freebsd.org/threads/trouble-calling-startx-in-start-up-script.22304/#post-125992)
- [https://forums.freebsd.org/threads/mounting-a-logical-ext4-partition-in-freebsd.72286/](https://forums.freebsd.org/threads/mounting-a-logical-ext4-partition-in-freebsd.72286/)
