---
title: "Modification de firmware"
date: "2021-08-24T10:34:14-04:00"
updated: "2021-08-24T10:34:14-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [binwalk, minipro, firmware, edition]
abstract: "Modification de firmware"
---

Cet article est un résumé de celui publié par Oleg Kutkov (lien en bas de page).

Dump du firmware contenu dans une puce SPI NOR BG25Q40A avec `minipro` et un flasher TL866.
```console
minipro -p "BG25Q40A@SOIC8" -r file.bin
```

Extraire les fichiers selon un critère (ici des fichiers MP3 qui contient un marqueur ID3) depuis le firmware `file.bin`
```console
binwalk file.bin -e --dd=".*" --raw="ID3"

DECIMAL HEXADECIMAL DESCRIPTION
--------------------------------------------------------------------------------
217088 0x35000 Raw signature (ID3)
254464 0x3E200 Raw signature (ID3)
258560 0x3F200 Raw signature (ID3)
269824 0x41E00 Raw signature (ID3)
```

> Pour plus d'investigation, `strings` permet d'afficher toutes les chaînes de caractère d'un fichier binaire. D'autres commandes comme `foremost`, `scalpel` et `bulk_extractor` permettent également d'extraire les fichiers.

Lister les fichiers obtenus
```console
ls file.bin.extracted/
35000 3E200 3F200 41E00

file file.bin.extracted/35000 
file.bin.extracted/35000: Audio file with ID3 version 2.3.0, contains:MPEG ADTS, layer III, v2, 32 kbps, 16 kHz, Monaural
```

> Pour des fichiers WAV, `sndfile-info` du package `libsndfile-utils` permet d'obtenir quelques détails en plus.

Extraire directement le fichier `35000` contenu dans `file.img` (de l'offset 217088 jusqu'a la fin du fichier 524288, donc le décompte est de 524288 - 217088 = 307200)
```console
dd if=file.bin of=out.mp3 bs=1 skip=217088 count=307200
```

Remplacer le contenu de out.mp3 avec moins de données (300000 octets au lieu de 307200, donc 7200 octets de moins) et préserver les offsets originaux. Les données manquantes (7200 octets) seront comblées avec des 0.
```console
dd if=/dev/zero of=7200_bytes.bin bs=1 count=7200
cat custom.mp3 7200_bytes.bin > out_new.mp3
dd conv=notrunc if=out_new.mp3 of=file_new.bin bs=1 seek=217088
```

Flasher le firmware modifié
```console
minipro -p "BG25Q40A@SOIC8" -w file_new.bin
```


# Liens complémentaires
 - [https://olegkutkov.me/2021/02/27/hacking-a-firmware-of-bluetooth-speaker-fm-radio/](https://olegkutkov.me/2021/02/27/hacking-a-firmware-of-bluetooth-speaker-fm-radio/)
 - [https://gitlab.com/DavidGriffith/minipro/](https://gitlab.com/DavidGriffith/minipro/)
 - [https://github.com/ReFirmLabs/binwalk](https://github.com/ReFirmLabs/binwalk)
 
 
