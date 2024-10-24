---
title: "Automobile, bus CAN et norme OBD2"
date: "2018-11-01T18:08:32-04:00"
updated: "2019-12-14T15:29:32-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Électronique"
keywords: [automobile, can, bus, obd2, macchina, savvycan]
abstract: "Dialoguer avec l'ordinateur de bord d'un véhicule automobile via OBD2."
---

Pour établir la communication avec l'ordinateur embarqué d'une automobile (appelé ECU pour Electronic Control Unit), rien de bien compliqué car la technologie mis en oeuvre ici (CAN pour Controller Area Network) date en partie des années 1980 et n'intègre pas les concepts issus des enjeux d'aujourd'hui (authentification, cryptage etc.). N'oublions pas que ces systèmes embarqués sont très limités en terme de capacité de traitement tout en étant soumis à des contraintes de temps dans lesquelles ils doivent être en mesure d'opérer.

La couche physique (niveau 1 OSI), fonctionne selon une topologie de type bus: tous les noeuds connectés au bus reçoivent chaque message émis (broadcast) ce qui nécessite d'introduire la notion d'identification afin d'être en mesure d'identifier un noeud comme destinataire ou émetteur d'un message.
L'identification des noeuds s'effectue par la couche liaison de donnée (niveau 2 OSI) qui est normalisée ISO avec deux variantes: l'une fonctionnant avec 11 bits et l'autre (dite "extended") sur 29 bits. On ne peut pas parler d'adressage formel car un noeud peut écouter sur un identifiant et répondre avec un autre (c'est le cas de l'ECU).

La norme OBD2 (On-Board Diagnostics 2) intervient au niveau 7 OSI: elle standardise en partie l'identification et la codification des données qui transitent sur le bus. Légalement encadré, une partie du protocole est normalisé et documenté incluant bon nombre de [métriques](https://en.wikipedia.org/wiki/OBD-II_PIDs#Service_01) et les [codes de diagnostique](https://github.com/mytrile/obd-trouble-codes).
En revanche il demeure une partie inconnue qui est propre aux constructeurs qu'il va falloir découvrir avec un peu de rétro-ingénierie.


## Outillage

Pour assurer l'interconnexion, nous utiliserons la carte [Macchina M2](https://www.macchina.cc/m2-introduction). Notons qu'il existe d'autres cartes comme la [CANable](http://canable.io/) ou encore la [Carloop](https://www.carloop.io/). La Macchina M2 embarque tout le nécessaire pour assurer la connectivité avec CAN et d'autres standards (présence de transceivers pour LIN, K-Line etc.), elle est modulaire et possède un éco-système logiciel open source complet (documentation, librairies, firmware et  utilitaire) ce qui nous permet de travailler facilement avec OBD2.

En effet, le module de contrôle optionnel embarque un microcontrôleur Atmel SAM3X8E (que l'on retrouve sur l'Arduino Due) et nous permet d'utiliser l'[IDE Arduino](http://docs.macchina.cc/m2/getting-started/arduino.html). La seule différence avec l'Arduino Due est le brochage qui diffère mais comme celui-ci est [documenté](https://docs.macchina.cc/m2/technical-references/pin-mapping.html), il suffit de peu de modifications pour faire fonctionner des librairies Arduino ou des systèmes comme [Zephyr](https://docs.zephyrproject.org/latest/boards/arm/arduino_due/doc/board.html) et [RIOT](https://github.com/RIOT-OS/RIOT/wiki/RIOT-Platforms) (en revanche certains drivers peuvent manquer comme celui pour le mcp2515).

Bien que de nombreux exemples en C/C++ soient disponibles pour interroger l'ECU, nous utiliserons le firmware [M2RET](https://github.com/collin80/M2RET) et l'utilitaire [SavvyCAN](http://www.savvycan.com/). SavvyCAN permet de controler M2RET via la liaison série sur USB pour le paramétrage et l'envoie/réception de messages. SavvyCAN est un outil très complet proposant de nombreuses fonctionnalités d'analyse, de scan/sniff et encore de génération de message. Nous nous intéresserons ici à l'[interface de scripting](http://www.savvycan.com/docs/scriptingwindow.html) pour envoyer et recevoir des données de l'ECU.


## Format d'un message

L'ECU devrait écouter sur `0x7E0` et répondre avec l'identifiant `0x7E8`.
Exemple de message permettant d'interroger l'ECU concernant la température de l'huile du moteur:

| ID              | Longueur     | [Longueur   | Service | PID  | Donnée    | Donnée    | Donnée    | Donnée    | Donnée]  |
| :----------------------: | :----------------------: | :----------------------: | :--------------------: | :----------------------: | :-----: | :-----: | :-----: | :-----: | :-----: |
| Destinataire sur 11 bits | Longueur du message CAN en nombre d'octets (max. 8) | Longueur du message OBD2/UDS en nombre d'octets (max. 8) | 1 octet                | 1 octet                  | 1 octet | 1 octet | 1 octet | 1 octet | 1 octet |


L'équivalent sous forme de code:

```Javascript
[id   , longueur, [longueur, service, pid , bourrage, bourrage, bourrage, bourrage, bourrage]]
[0x7E0, 8       , [2       , 0x01   , 0x5C, 0x00    , 0x00    , 0x00    , 0x00    , 0x00    ]]
```


En réponse l'ECU devrait émettre le message suivant (avec la clé de contact):

```Javascript
[id   , longueur, [longueur, service, pid , donnée, bourrage, bourrage, bourrage, bourrage]]
[0x7E8, 8       , [2       , 0x41   , 0x5C, 0x32  , 0x00    , 0x00    , 0x00    , 0x00    ]]
```

Remarquons que le service est passé de `0x01` à `0x41` car l'ECU ajoute 40 à la valeur de service pour signifier un succès.


Notons que la représentation hexadécimale utilisée ici pour les octets composant le message peut être remplacée pour utiliser directement des entiers.
Nous utiliserons ici l'interface de scripting comme moyen d'interroger l'ECU bien que SavvyCAN possède déjà cette fonctionnalité via l'interface graphique en envoyant des messages dont le contenu est saisi sans code JavaScript.
Voici un exemple de script SavvyCAN (JavaScript) pour récupérer la température de l'huile moteur et le régime moteur toutes les secondes:

```javascript
var FROM_ECU = 0x7E8;
var TO_ECU = 0x7E0;

//Pour afficher le contenu du message en hexadecimal
function toHexString(byteArray) {
	return Array.from(byteArray, function(byte) {
		return ('0' + (byte & 0xFF).toString(16)).slice(-2);
	}).join(' : ')
}

//Configuration initiale
function setup(){
  //Fréquence d'exécution de la fonction tick() à 1 seconde
  host.setTickInterval(1000);

  //Accepte uniquement les réponses de l'ECU (0x7E8)
  can.setFilter(FROM_ECU, FROM_ECU, 0);
}

//Callback exécuté lors de la réception d'un message
function gotCANFrame (bus, id, len, data) {
  //Affiche tout le message
  host.log("gotCANFrame: " + toHexString(data));

  switch(data[2]) {
    //Température de l'huile moteur
    case 0x5C:
      var temperature = data[3] - 40;
      host.log("Huile moteur: " + temperature.toString() + " °C");

      //Demande le régime moteur RPM (0x0C) sur le bus 0
      can.sendFrame(0, TO_ECU, 8, [2, 0x01, 0x0C, 0x00, 0x00, 0x00, 0x00, 0x00]);
      break;

    //Régime moteur
    case 0x0C:
      var rpm = (256 * data[3] + data[4]) / 4;
      host.log("Régime moteur: " + rpm.toString() + " RPM");
      break;
  }
}

//Fonction exécutée périodiquement
function tick(){
  //Demande la température de l'huile moteur (0x5C) sur le bus 0
  can.sendFrame(0, TO_ECU, 8, [2, 0x01, 0x5C, 0x00, 0x00, 0x00, 0x00, 0x00]);
}

```

Notons que la fonction `can.sendFrame()` pour récupérer le régime moteur `0x0C` est exécutée à la réception de la température de l'huile moteur `0x5C` car l'exécuter dans `tick()` directement à la suite de l'autre `can.sendFrame()` ne nous permet pas d'obtenir une réponse de l'ECU, probablement car il faut un délais entre les deux.

Le réel intérêt d'utiliser l'interface de scripting est de pouvoir interagir avec l'ECU à la manière des outils du constructeur: par exemple la reprogrammation de l'ECU passe par une méthode d'authentification challenge-response suivie l'envoie d'octets.
D'autres exemples sont disponibles [ici](https://github.com/collin80/SavvyCAN/tree/master/examples).


## Données du bus CAN

Sur le bus beaucoup de messages sont envoyés à une fréquence élevée sans même que la clé de contact soit entrée:

Time Stamp|ID|Extended|Dir|Bus|LEN|D1|D2|D3|D4|D5|D6|D7|D8
:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:
124771|00000156|false|Rx|0|8|00|00|00|00|00|00|00|05
135715|00000152|false|Rx|0|8|81|C4|00|00|00|00|00|00
143779|00000156|false|Rx|0|8|00|00|00|00|00|00|00|05
153571|00000282|false|Rx|0|8|FE|03|00|FE|FE|00|32|00
155875|00000152|false|Rx|0|8|89|D4|00|00|00|00|00|00
156163|00000376|false|Rx|0|1|FA|00|00|00|00|00|00|00
164803|00000156|false|Rx|0|8|00|00|00|00|00|00|00|05
165091|000003D1|false|Rx|0|8|FF|1F|00|00|00|00|00|00
175747|00000152|false|Rx|0|8|89|E4|00|00|00|00|00|00
183811|00000156|false|Rx|0|8|00|00|00|00|00|00|00|05
195907|00000152|false|Rx|0|8|81|F4|00|00|00|00|00|00
204547|00000156|false|Rx|0|8|00|00|00|00|00|00|00|05
204835|00000282|false|Rx|0|8|FE|13|00|FE|FE|00|32|00
205699|00000376|false|Rx|0|1|FA|00|00|00|00|00|00|00


Comme aucun ID n'est répertorié dans la norme OBD2, il est difficile d'identifier les données reçues. Il doit probablement en être de même pour les autres constructeurs/modèles.
En utilisant la fonction Sniffer de SavvyCAN avec l'option "Notch" il est possible de mettre en surbrillance les octets dont la valeur change. Cette option va nous aider a identifier quels IDs/octets correspondent à quoi.

En entrant la clé et en la ressortant, on remarque que le premier octet de l'ID 154 change de `0x10` à `0x00`.
Pour le même ID (154), le 7ème octet décrit l'état de la porte conducteur avec la valeur `0xC1` pour l'état ouvert et `0xC0` pour fermé.
Selon le même principe, l'ID 141 - octet 6 aura la valeur `0x3F` lorsque le levier de vitesse est sur le neutre sinon `0x3E` peu importe la vitesse.

L'angle de direction (rotation du volant) est donné par les deux premiers octets des ID 002 et 0D0.

Un octet spécifique pour un ID donné peut prendre plusieurs valeurs différentes en fonction de certains facteurs.
Par exemple les phares et les essuies glace conditionne la valeur du 7ème octet de l'ID 152 qui peut prendre les valeurs suivantes:

|Hexadécimal| Binaire  |État observé des essuie-glaces/phares                             |
|:---------:| :------: |:-----------------------------------------------------------------|
|0x00       | 00000000 |Rien d'activé                                                     |
|0x04       | 00000100 |Position                                                          |
|0x0C       | 00001100 |Croisement                                                        |
|0x18       | 00011000 |Route/appel de phare                                              |
|0x1C       | 00011100 |{position ou croisement} + appel de phare                         |
|0x44       | 01000100 |Position + essuie-glaces déployés                                 |
|0x5C       | 01011100 |{position ou croisement} + appel de phare + essuie-glaces déployés|

La représentation hexadécimale ne nous montre pas comment sont codées les données, c'est la représentation binaire qui va nous montrer qu'un bit donné dans cet octet représente l'état d'un système spécifique (phares, etc.). Ici le 7ème bit (en partant de la droite) décrit l'état des essuie-glaces (1 pour déployés, 0 pour non déployés). On remarque un chevauchement des bits pour les phares de positions, de croisement et de route: ceci implique que lors d'un appel de phare (bits 4 et 5 à 1) on ne peut distinguer si ce sont les phares de position (bit 3 à 1) ou de croisement (bits 3 et 4) qui sont actifs car le bit 3 et 4 sera à 1 dans les deux cas.

On peut observer le même principe avec les freins (frein à main et pédale de frein) dans le 7ème octet de l'ID 154.

Vous l'aurez compris, l'état de chaque système de l'automobile est transmis en temps réel sur le bus.

## Liens complémentaires

 - [Documentation Macchina M2](https://docs.macchina.cc/)
 - [Identifiants OBD2 et formules de calcul](https://en.wikipedia.org/wiki/OBD-II_PIDs#Service_01)
 - [Documentation SavvyCAN](http://www.savvycan.com/docs/index.html)
