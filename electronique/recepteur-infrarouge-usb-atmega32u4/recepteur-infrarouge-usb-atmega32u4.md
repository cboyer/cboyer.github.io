---
title: "Récepteur infrarouge USB avec un ATmega32u4"
date: "2018-04-20T18:45:18-04:00"
updated: "2021-06-14T16:00:00-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Électronique"
keywords: [arduino, atmega32u4, infrarouge, usb, kodi]
abstract: "Utilisation des fonctions HID du microcontrôleur ATmega32u4 et un capteur infrarouge pour contrôler des systèmes/applications avec une télécommande."
---

Beaucoup utilisent Kodi comme système multimédia avec leur TV. Que ce soit sur un Raspberry Pi, un mini PC ou bien un laptop, le besoin d'interagir à distance depuis son divan nous amène à considérer l'achat d'une télécommande USB. Bien que la norme HDMI intègre la fonction CEC pour commander des équipements avec la même télécommande, cette fonction n'est pas toujours présente sur les TV et équipement multimédia.

Voyons comment créer son propre récepteur USB pour télécommande infrarouge avec un microcontrôleur ATmega32u4,  un vieux décodeur Vidéotron dont nous allons récupérer le capteur et la télécommande.

Les mises à jour de ce projet sont disponibles sur Github: [https://github.com/cboyer/remote-arduino](https://github.com/cboyer/remote-arduino).

## Principe de fonctionnement

ATmega32u4 possède des fonctionnalités HID: il peut nativement se faire passer pour un périphérique USB comme une souris ou encore un clavier. Nous allons l'utiliser pour simuler les touches d'un clavier en fonction des codes infrarouge reçus de la télécommande.
L'avantage d'utiliser un microcontrôleur et l'USB au lieu du capteur infrarouge directement sur des entrée GPIO est la portabilité: aucun pilote, configuration ou logiciel (comme Lircd) n'est requis. Vous pouvez même interagir avec le système d'exploitation et n'importe quelle application pouvant être contrôlée par le clavier.
Dans le cadre d'une utilisation avec Kodi, nous utiliserons les touches configurées par défaut sur Kodi afin de le contrôler.

Sachant que la télécommande et le capteur infrarouge proviennent du même équipement, nous sommes assurés que ces deux éléments fonctionnent sur la même fréquence.

## Le montage

Nous utiliserons un "CJMCU Beetle" pour ses dimensions particulièrement adaptées à notre utilisation:

![Montage](cjmcu.jpg)

Pour programmer l'ATmega32u4 nous utiliserons l'IDE Arduino configuré pour une carte Arduino Leonardo et les librairies IRremote, HID-Project:

```c
#include <IRremote.h>
#include <HID-Project.h>

#define RECV_PIN 9

IRrecv irrecv(RECV_PIN);
decode_results results;
unsigned long buf;
unsigned int i = 0;

void setup()
{
  //Décommenter pour afficher les codes IR dans la console
  //Serial.begin(9600);
  irrecv.enableIRIn();
}

void loop() {
  if (irrecv.decode(&results)) {
    //Décommenter pour afficher les codes IR dans la console
    //Serial.println(results.value, HEX);

    //Maintient d'un bouton enfoncé
    if (results.value == 0xFFFFFFFF){
      i++;
      if(i >= 6){
        results.value = buf;
        delay(20);
      }
    }
    else{
      buf = results.value;
      i = 0;
    }

    switch(results.value) {

      case 0x366133:
        Keyboard.write(KEY_RETURN);
        break;

      case 0x36812F:
        Keyboard.write(KEY_UP_ARROW);
        break;

      case 0x364137:
        Keyboard.write(KEY_RIGHT_ARROW);
        break;

      case 0x37A10B:
        Keyboard.write(KEY_DOWN_ARROW);
        break;

      case 0x37810F:
        Keyboard.write(KEY_LEFT_ARROW);
        break;

      case 0x366932:
        Keyboard.write(KEY_ESC);
        break;

      case 0x36D924:
        Keyboard.write(KEY_PAGE_UP);
        break;

      case 0x37D904:
        Keyboard.write(KEY_PAGE_DOWN);
        break;

      case 0x36093E:
        Keyboard.write(MEDIA_VOL_UP);
        break;

      case 0x37091E:
        Keyboard.write(MEDIA_VOLUME_DOWN);
        break;

      case 0x36892E:
        Keyboard.write(MEDIA_VOLUME_MUTE);
        break;

      case 0x37291A:
        Keyboard.write(MEDIA_REWIND);
        break;

      case 0x36293A:
        Keyboard.write(MEDIA_FAST_FORWARD);
        break;

      case 0x374117:
        Keyboard.write(MEDIA_PAUSE);
        break;

      case 0x37990C:
        Keyboard.write(MEDIA_PLAY_PAUSE);
        break;

      case 0x365934:
        Keyboard.write(MEDIA_STOP);
        break;

      case 0x377111:
        Keyboard.write(MEDIA_NEXT);
        break;

      case 0x36F121:
        Keyboard.write(MEDIA_PREVIOUS);
        break;

      case 0x36213B:
        Keyboard.write('i');
        break;

      case 0x36C127:
        Keyboard.write('c');
        break;
    }
    irrecv.resume();
  }
  delay(10);
}
```

Dans le cas où votre télécommande n'utiliserai pas les mêmes codes infrarouge, décommentez les lignes indiquées pour qu'ils soient affichés dans la console de l'IDE. Remplacez les codes correspondant à la touche clavier voulue (exemple: `MEDIA_STOP`).

## Limites

Les touches `MEDIA_*` fonctionnent uniquement sur un système Linux, Windows et FreeBSD ne les reconnaissent pas. Ceci n'est donc pas un problème pour les utilisateurs de [LibreELEC](https://libreelec.tv/)/[OpenELEC](https://www.openelec.tv/).

## IRremote: passage à la version 3.x

Avec les versions récentes d'IRremote, certaines modifications de la librairie implique une actualisation du programme:

```C
#include <IRremote.h>
#include <HID-Project.h>

#define RECV_PIN 9

unsigned long buf;
unsigned int i = 0;


void setup()
{
  //Uncomment to enable serial printing of IR codes
  //Serial.begin(9600); 
  buf = 0xFFFFFFFF;
  IrReceiver.begin(RECV_PIN, DISABLE_LED_FEEDBACK);
}

void loop() {
  if (IrReceiver.decode()){
    //Uncomment to enable serial printing of IR codes
    //Serial.println(IrReceiver.decodedIRData.decodedRawData, HEX);

    switch(IrReceiver.decodedIRData.decodedRawData) {

      case 0x33219B:
        Keyboard.write(KEY_RETURN);
        break;
  
      case 0x3D205B:
        Keyboard.write(KEY_UP_ARROW);
        break;
        
      case 0x3B209B:
        Keyboard.write(KEY_RIGHT_ARROW);
        break;
        
      case 0x34217B:
        Keyboard.write(KEY_DOWN_ARROW);
        break; 

      case 0x3C207B:
        Keyboard.write(KEY_LEFT_ARROW);
        break; 

      case 0x13259B:
        Keyboard.write(KEY_ESC);
        break; 

      case 0x5275B:
        Keyboard.write('z');
        break; 

      case 0x926DB:
        Keyboard.write(KEY_PAGE_UP);
        break;

      case 0x826FB:
        Keyboard.write(KEY_PAGE_DOWN);
        break;

      case 0x6FF900:
        //Keyboard.write(MEDIA_VOL_UP);
        Keyboard.write('+');
        break;

      case 0x6BF940:
        //Keyboard.write(MEDIA_VOLUME_DOWN);
        Keyboard.write('-');
        break;

      case 0xFFF000:
        //Keyboard.write(MEDIA_VOLUME_MUTE);
        Keyboard.write(KEY_F8);
        break;

      case 0x16253B:
        //Keyboard.write(MEDIA_REWIND);
        Keyboard.write('r');
        break;

      case 0x17251B:
        //Keyboard.write(MEDIA_FAST_FORWARD);
        Keyboard.write('f');
        break;

      case 0x3A20BB:
        //Keyboard.write(MEDIA_PAUSE);
        Keyboard.write(KEY_SPACE);
        break;

      case 0xC267B:
        //Keyboard.write(MEDIA_PLAY_PAUSE);
        Keyboard.write(KEY_SPACE);
        break;

      case 0xB269B:
        //Keyboard.write(MEDIA_STOP);
        Keyboard.write('x');
        break;

      case 0x37211B:
        Keyboard.write('i');
        break;

      case 0x3920DB:
        Keyboard.write('c');
        break;

      case 0x1025FB:
        Keyboard.write('o');
        break;
    }

    if (i < 4)
      delay(200);

    if (IrReceiver.decodedIRData.decodedRawData == buf)
      i++;
    else {
      buf = IrReceiver.decodedIRData.decodedRawData;
      i = 0;
    }
    
    IrReceiver.resume();
  }
}
```


## Liens complémentaires

 - [https://github.com/z3t0/Arduino-IRremote](https://github.com/z3t0/Arduino-IRremote)
 - [https://github.com/NicoHood/HID](https://github.com/NicoHood/HID)
