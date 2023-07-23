---
title: "Récepteur infrarouge USB avec un ATmega32u4"
date: "2018-04-20T18:45:18-04:00"
updated: "2023-06-30T19:55:00-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Électronique"
keywords: [arduino, atmega32u4, infrarouge, usb, kodi]
abstract: "Utilisation des fonctions HID du microcontrôleur ATmega32u4 et un capteur infrarouge pour contrôler des systèmes/applications avec une télécommande."
---

Beaucoup utilisent Kodi comme système multimédia avec leur TV. Que ce soit sur un Raspberry Pi, un mini PC ou bien un laptop, le besoin d'interagir à distance depuis son divan nous amène à considérer l'achat d'une télécommande USB. Bien que la norme HDMI intègre la fonction CEC pour commander des équipements avec la même télécommande, cette fonction n'est pas toujours présente sur les TV et équipement multimédia.

Voyons comment créer son propre récepteur USB pour télécommande infrarouge avec un microcontrôleur ATmega32u4,  un vieux décodeur Vidéotron dont nous allons récupérer le capteur et la télécommande.


## Principe de fonctionnement

ATmega32u4 possède des fonctionnalités HID: il peut nativement se faire passer pour un périphérique USB comme une souris ou encore un clavier. Nous allons l'utiliser pour simuler les touches d'un clavier en fonction des codes infrarouge reçus de la télécommande.
L'avantage d'utiliser un microcontrôleur et l'USB au lieu du capteur infrarouge directement sur des entrée GPIO est la portabilité: aucun pilote, configuration ou logiciel (comme Lircd) n'est requis. Vous pouvez même interagir avec le système d'exploitation et n'importe quelle application pouvant être contrôlée par le clavier.
Dans le cadre d'une utilisation avec Kodi, nous utiliserons les touches configurées par défaut sur Kodi afin de le contrôler.

Sachant que la télécommande et le capteur infrarouge proviennent du même équipement, nous sommes assurés que ces deux éléments fonctionnent sur la même fréquence.

## Le montage

Nous utiliserons un "CJMCU Beetle" pour ses dimensions particulièrement adaptées à notre utilisation:

![Montage](cjmcu.jpg)

Pour programmer l'ATmega32u4 nous utiliserons l'IDE Arduino configuré pour une carte Arduino Leonardo et les librairies IRremote (version 3.5):

```c
#include <IRremote.h>
#include <Keyboard.h>

#define RECV_PIN 9

unsigned long buf;
unsigned int i = 0;


void setup()
{
  //Uncomment to enable serial printing of IR codes
  //Serial.begin(9600); 
  buf = 0xFFFFFFFF;
  Keyboard.begin();
  IrReceiver.begin(RECV_PIN, NULL);
}

void loop() {
  if (IrReceiver.decode()) {
    //Uncomment to enable serial printing of IR codes
    //Serial.println(IrReceiver.decodedIRData.decodedRawData, HEX);

    switch(IrReceiver.decodedIRData.decodedRawData) {

      case 0x33219E:
        Keyboard.write(KEY_RETURN);
        break;
  
      case 0x3D205E:
        Keyboard.write(KEY_UP_ARROW);
        break;

      case 0x3B209E:
        Keyboard.write(KEY_RIGHT_ARROW);
        break;

      case 0x34217E:
        Keyboard.write(KEY_DOWN_ARROW);
        break; 

      case 0x3C207E:
        Keyboard.write(KEY_LEFT_ARROW);
        break; 

      case 0x13259E:
        Keyboard.write(KEY_ESC);
        break; 

      case 0x1025FE:
        Keyboard.write('o');
        break;

      case 0xF261E:
        Keyboard.write('z');
        break;

      case 0x926DE:
        Keyboard.write(KEY_PAGE_UP);
        break;

      case 0x826FE:
        Keyboard.write(KEY_PAGE_DOWN);
        break;

      case 0x6FF90E:
        Keyboard.write(KEY_KP_PLUS);
        break;

      case 0x6BF94E:
        Keyboard.write(KEY_KP_MINUS);
        break;

      case 0xFFF00E:
        Keyboard.write(KEY_F8);
        break;

      case 0x16253E:
        Keyboard.write('r');
        break;

      case 0x17251E:
        Keyboard.write('f');
        break;

      case 0x3A20BE:
        Keyboard.write(' ');
        break;

      case 0xC267E:
        Keyboard.write('p');
        break;

      case 0xB269E:
        Keyboard.write('x');
        break;

      case 0x37211E:
        Keyboard.write('i');
        break;

      case 0x3920DE:
        Keyboard.write('c');
        break;

      case 0x5275E:
        Keyboard.write(KEY_F11);
        break;

      case 0xE263E:
        Keyboard.write(KEY_DELETE);
        break;

      case 0xAA6BE:
          Keyboard.press(KEY_LEFT_CTRL);
          Keyboard.press(KEY_LEFT_ALT);
          Keyboard.press('p');
          delay(100);
          Keyboard.releaseAll();
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

Dans le cas où votre télécommande n'utiliserai pas les mêmes codes infrarouge, décommentez les lignes indiquées pour qu'ils soient affichés dans la console de l'IDE. Remplacez les codes correspondant à la touche clavier voulue.

## Liens complémentaires

 - [https://github.com/z3t0/Arduino-IRremote](https://github.com/z3t0/Arduino-IRremote)
 - [https://github.com/NicoHood/HID](https://github.com/NicoHood/HID)
