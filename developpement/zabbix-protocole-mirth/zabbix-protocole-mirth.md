---
title: "Implémentation du protocole Zabbix dans Mirth Connect"
date: "2018-12-08T18:23:15-04:00"
updated: "2020-06-13T10:36:47-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [zabbix, mirth, mirth connect, monitoring]
abstract: |
  Implémenter l'agent Zabbix dans Mirth via un canal de type TCP Listener.
---

L'objectif est d'implémenter un agent [Zabbix](https://www.zabbix.com/) dans [Mirth Connect](https://www.nextgen.com/products-and-services/NextGen-Connect-Integration-Engine-Downloads) comme n'importe quel autre échange de données afin de monitorer l'activité de ce dernier (erreurs, statuts, volumes de transactions, etc.).
L'intégralité du code source de ce projet est disponible sur Github (licence GPLv3): [https://github.com/cboyer/mirth-zabbix](https://github.com/cboyer/mirth-zabbix).

Le monitoring avec Zabbix repose sur un serveur chargé de collecter les données auprès des équipements notamment via un agent (Zabbix peut également utiliser d'autres standards comme SNMP). Cette stratégie de "polling" implique dans un premier temps une connexion à l'agent pour l'interroger concernant la valeur d'une métrique (clé) que ce dernier lui retournera.


## Le protocole Zabbix

Zabbix utilise un protocole relativement simple: il repose sur des échanges de données au format JSON sur TCP. Étant une technologie libre et open source nous disposons du code source de l'agent Zabbix ainsi qu'une excellente documentation pour en comprendre le fonctionnement (cf. sources en bas de page).

Zabbix structure ses messages de la façon suivante:


Requête du serveur vers l'agent:
```Javascript
Zabbix version 3:
[clé                 , fin de message]
[chaîne de caractères, 0x0A          ]

Zabbix version 4:
[protocole, flag, longueur des données             , réservé                 , clé (données)       ]
["ZBXD"   , 0x01, entier sur 4 octets little endian, [0x00, 0x00, 0x00, 0x00], chaîne de caractères]
```

Réponse de l'agent vers le serveur (version 3 et 4):
```Javascript
[protocole, flag, longueur des données             , réservé                 , réponse (données)   ]
["ZBXD"   , 0x01, entier sur 4 octets little endian, [0x00, 0x00, 0x00, 0x00], chaîne de caractères]
```

L'entête est une chaîne de caractères fixe: `"ZBXD"`. Elle est composée de la chaîne `ZBXD` et de l'octet `0x01`.
La longueur des données est un entier non signé sur 4 octets en little-endian qui représente la longueur de la chaîne contenant les données. Zabbix est limité à une quantité maximale de 134217728 octets.
Les données envoyées sont en texte clair (Zabbix peut crypter ses échanges, cas que nous ne traiterons pas ici).

## Mirth Connect

Pour imiter le fonctionnement de l'agent Zabbix avec un canal Mirth un connecteur source de type TCP Listener est nécessaire afin d'accepter les connexions en provenance du serveur Zabbix. Ce connecteur doit utiliser la même connexion TCP pour être interroger (recevoir la clé) et envoyer la donnée correspondante à la métrique demandée. Il doit également fonctionner en mode binaire car nous avons besoin de travailler avec des octets sans qu'ils soient altérés par les standards d'encodage (UTF-8, etc.) liés aux chaînes de caractères. 
La configuration d'un TCP listener se fait avec l'interface Mirth, sans code:

![Configuration du connecteur source](mirth_source.png)

Pour être compatible avec les version 3 et 4 de Zabbix, il faut être en mesure de les dicerner:

```javascript
msg = new java.lang.String(FileUtil.decode(msg));

//Zabbix 4.X
if (msg.substring(0, 5) == "ZBXD\x01" && msg.length() > 13) {

	//Longueur de la clé: octets 5 à 9
	var length_bytes = msg.substring(5, 9).getBytes();

	//Décode les 4 octets little endian en entier
	var bytebuf = Packages.java.nio.ByteBuffer.wrap(length_bytes);
	bytebuf.order(java.nio.ByteOrder.LITTLE_ENDIAN);
	var length = bytebuf.getInt(0);

	//Clé demandée par le serveur: octets 13 à (13 + length)
	msg = msg.substring(13, 13 + length);
}

//Zabbix 3.X (requête sans entête avec 0x0A final)
else if (msg.charAt(msg.length() - 1) == 0x0A) {

    //Supprime simplement le 0x0A
	msg = msg.slice(0, -1);
}

//Si ce n'est pas un message Zabbix
else msg = 'UnknownProtocol';
```


Une fois le connecteur source mis en place, nous allons faire appel à un [transformer](https://github.com/cboyer/mirth-zabbix/blob/master/src/destination_transformer.js) afin de récupérer les données demandées par le serveur et les transmettre au connecteur de destination. C'est ici que sont centralisées les fonctionnalités de l'agent Zabbix, plus précisément les clés supportées. Concrètement il s'agit un simple `switch` pour exécuter du code en fonction de la métrique demandée par le serveur:

```javascript
switch (item_requested) {

	case 'agent.ping':
		msg = 1;
		break;

	case 'agent.version':
		msg = 'Mirthix 1.1.0';
		break;

	case 'agent.hostname':
	case 'system.uname':
		msg = com.mirth.connect.server.controllers.ConfigurationController.getInstance().getServerName();
		break;

	default:
		msg = "ZBX_NOTSUPPORTED\x00Key not implemented in Mirthix: " + item_requested;
}
```

Pour le [connecteur de destination](https://github.com/cboyer/mirth-zabbix/blob/master/src/destination.js) (chargé d'envoyer les données au serveur Zabbix), nous devrons implémenter le protocole Zabbix avec le header, la longueur des données sur 8 octets en little-endian et les données.
Voici le code du connecteur de destination:

```javascript
//Chaque composante du message
var protocol = "ZBXD";
var flag = "\x01";
var reserved = "\x00\x00\x00\x00";
var data = connectorMessage.getEncodedData();
var datalen = data.length();

//Transformation en tableau d'octets
var protocol_bytes = new java.lang.String(protocol).getBytes('UTF-8');
var flag_bytes = new java.lang.String(flag).getBytes('UTF-8');
var reserved_bytes = new java.lang.String(reserved).getBytes('UTF-8');
var data_bytes = new java.lang.String(data).getBytes('UTF-8');

//Encode la longueur des données sur 4 octets en little endian
var datalen_bytes = Packages.java.nio.ByteBuffer.allocate(4);
datalen_bytes.order(java.nio.ByteOrder.LITTLE_ENDIAN);
datalen_bytes.putInt(data_bytes.length);

//Construction du message final
var zabbix_message_bytes = Packages.java.nio.ByteBuffer.allocate(protocol_bytes.length + flag_bytes.length + datalen_bytes.array().length + reserved_bytes.length + data_bytes.length);
zabbix_message_bytes.put(protocol_bytes);
zabbix_message_bytes.put(flag_bytes);
zabbix_message_bytes.put(datalen_bytes.array());
zabbix_message_bytes.put(reserved_bytes);
zabbix_message_bytes.put(data_bytes);

return Packages.org.apache.commons.codec.binary.Base64.encodeBase64String(zabbix_message_bytes.array());
```

Notons qu'il est nécessaire d'encoder le message en base 64 pour fonctionner en mode binaire dans Mirth.
Coté Zabbix toute la configuration s'effectue via un [template](https://github.com/cboyer/mirth-zabbix/blob/master/Zabbix/Zabbix_template.xml) pour la définition des items/clés à monitorer.


## Sources

 - [https://www.zabbix.com/documentation/3.4/manual/appendix/items/activepassive](https://www.zabbix.com/documentation/3.4/manual/appendix/items/activepassive)
 - [https://www.zabbix.com/documentation/3.4/manual/appendix/protocols/header_datalen](https://www.zabbix.com/documentation/3.4/manual/appendix/protocols/header_datalen)
