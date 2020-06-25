---
title: "Implémentation du protocole Dreamscreen en C"
date: "2018-05-29T19:36:04-04:00"
updated: "2019-01-10T18:25:32-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [dreamscreen, linux, kodi]
abstract: |
  Implémentation en C du protocole utilisé pour commander un équipement Dreamscreen.
---

Le [Dreamscreen](https://www.dreamscreentv.com) est un équipement multimédia du type "ambilight". Cet équipement utilise une application Android/IPhone pour être configuré et contrôlé par Wifi mais pas de télécommande. L'application en question est uniquement disponible sur Google Play (pour Android), ce qui est ennuyant lorsqu'on utilise un téléphone "dé-google-isé" avec [LineageOS](https://www.lineageos.org).

Pour palier à ce manque, j'ai donc écrit un simple programme en C pour Linux (disponible sur [Github](https://github.com/cboyer/dreamscreen-daemon)) afin contrôler un dreamscreen depuis un [système de télécommande](../../electronique/recepteur-infrarouge-usb-atmega32u4/index.html) maison, que j'utilise avec Kodi. Ce programme est compatible avec n'importe quel autre périphérique de type clavier.
Techniquement il s'agit d'une implémentation en C du protocole dreamscreen qui envoie des message via UDP en fonction d'évènements clavier.
Ce programme peut facilement être intégré dans des systèmes comme [LibreELEC](https://libreelec.tv) ou encore [OpenELEC](https://openelec.tv).


## Structure du message

Dreamscreen utilise le port 8888 en UDP sur son interface WiFi pour envoyer et recevoir des messages binaires.

Structure du message:
```Javascript
[début, longueur du paquet, adresse de groupe, flag, commande principale, commande secondaire, payload (1 à 3 octets), CRC8]
[0xFC , 0x??              , 0x??             , 0x11, 0x03               , 0x??               , [0x??, 0x??, 0x??]    , 0x??]
```

**Début:** Permet la synchronisation lors de la réception d’un paquet. Contient toujours `0xFC`

**Longueur du paquet:** Nombre d’octet contenu entre l’Adresse de groupe et le CRC inclus. Normalement `0x06` (payload d’un seul octet) sauf pour la définition d’une couleur ambiante `0x08` (payload de 3 octets).

**Adresse de groupe:** Adresse identifiant le groupe auquel l’équipement est associé. `0x00` pour aucun groupe, `0x01` pour le groupe 1, `0x02` pour le groupe 2 etc.
Dans le cas où l’adresse de groupe est incorrect, le message sera ignoré.

**Flag:** Défini le contexte pour d’interprétation du message. Utiliser `0x11` pour commander le dreamscreen.

**Commande principale:** Défini la commande, utiliser `0x03` pour commander le Dreamscreen.

**Commande secondaire:** Identifie l’élément à paramétrer (cf. tableau plus bas).

**Payload:** Valeur à affecter au paramètre (cf. tableau plus bas).

**CRC8:** CRC sur 8 bits pour valider l’intégrité du message. S’il est incorrect, le message sera ignoré.


## Commandes et paramètres

Description|Commande|Paramètre|Payload|Longueur du payload (en octets)
:-----|:----:|:----:|:-----|:----:
Mode|0x03|0x01|0x00: Éteindre; 0x01: Vidéo; 0x02: Musique; 0x03: Ambiance|1
Luminosité|0x03|0x02|0x00 à 0x64 (pourcentage de 0 à 100)|1
Couleur d’ambiance lumineuse|0x03|0x05|Couleur RGB (sur 3 octets)|3
Type d’ambiance lumineuse|0x03|0x08|0x00: Couleur RGB; 0x01: Préréglage|1
Préréglage d’ambiance lumineuse |0x03|0x0D|0x00: Couleur aléatoire; 0x01: Fireside; 0x02: Twinkle; 0x03: Océan; 0x04: Arc-en-ciel; 0x05: 4 Juillet; 0x06: Vacances; 0x07: Pop; 0x08: Forêt enchantée|1
Entrée HDMI|0x03|0x20|0x00: Entrée 1; 0x01: Entrée 2; 0x02: Entrée 3|1


## Documentation

 - [Documentation du protocole dreamscreen](https://planet.neeo.com/media/80x1kj/download/dreamscreen-v2-wifi-udp-protocol.pdf)
 - [https://github.com/cboyer/dreamscreen-daemon](https://github.com/cboyer/dreamscreen-daemon)
