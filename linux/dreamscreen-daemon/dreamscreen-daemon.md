---
title: "Commander à distance un Dreamscreen: dreamscreen-daemon"
date: "2018-05-29T19:36:04-04:00"
updated: "2018-11-01T18:08:32-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [dreamscreen, linux, kodi]
abstract: |
  Implémentation en C du protocole utilisé pour commander un équipement Dreamscreen.
---

Ayant changé mon système ambilight maison pour un [Dreamscreen](https://www.dreamscreentv.com), j'ai été quelque peu déçu par l'absence de télécommande. En effet cet appareil utilise une application Android/IPhone pour être configuré et contrôlé par Wifi. Cependant il possède quand même deux boutons pour changer le mode d'effet et l'entrée HDMI.
De plus l'application pour Android est uniquement disponible sur Google Play, ce qui est ennuyant lorsqu'on utilise un téléphone "dé-google-isé" avec [LineageOS](https://www.lineageos.org).

J'ai donc écrit un simple démon Linux pour contrôler le Dreamscreen depuis [mon système de télécommande](../../electronique/recepteur-infrarouge-usb-atmega32u4/index.html), que j'utilise avec Kodi. Ce programme est compatible avec n'importe quel autre périphérique de type clavier.

Techniquement il s'agit d'une implémentation en C du protocole Dreamscreen utilisant UDP et d'une lecture des évènements clavier. Le protocole Dreamscreen est décrit dans cette [documentation](https://planet.neeo.com/media/80x1kj/download/dreamscreen-v2-wifi-udp-protocol.pdf).

Le code source et toute la documentation est disponible sur [Github](https://github.com/cboyer/dreamscreen-daemon).
Ce programme peut facilement être intégré dans des systèmes comme [LibreELEC](https://libreelec.tv) ou encore [OpenELEC](https://openelec.tv).
