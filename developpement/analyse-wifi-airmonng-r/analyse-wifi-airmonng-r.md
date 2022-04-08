---
title: "Analyse du trafic WiFi avec Airodump-ng et R"
date: "2019-03-04T14:22:12-04:00"
updated: "2019-03-04T14:22:12-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [R, analyse, réseau, airmon-ng]
abstract: "Analyse du trafic WiFi avec Airodump-ng et R."
---


Cet article présente un exemple d'utilisation de R avec les données issues d'[Airodump-ng](https://www.aircrack-ng.org/doku.php?id=airodump-ng).
Pour cela, nous procéderons en plusieurs étapes:

 - Collecte des données
 - Traitement des données en vue de les rendre exploitables
 - Analyse et présentation des données

Le script complet est disponible en bas de page, dans les sources.

## Collecte des données

Airodump-ng nous permet d'obtenir des statistiques sur le trafic réseau WiFi: il agrège les données par point d'accès et client WiFi de façon cumulative.
Ces données sont au format CSV.
Pour commencer la collecte des données (nécessite les droits root):

```console
airmon-ng start wlp3s0
airodump-ng --band abg -w output.csv --output-format csv wlp3s0mon
```

Ici `wlp3s0` correspond au nom de l'interface WiFi utilisée pour l'écoute (mode monitor) et sera accessible via une nouvelle interface `wlp3s0mon`.
Nous utiliserons l'extrait de données suivant à titre d'exemple: [airmonng_data.csv](./airmonng_data.csv)


## Traitement des données

Le fichier CSV produit comporte un problème de structure: il inclut deux ensembles de données distincts présentant les données relatives aux points d'accès et celle des clients. Chacun de ces ensembles possède un nombre de colonnes différents ce qui va poser problème à R pour parser ce fichier.

Autre problème, la colonne "Probe" des données des clients contient des valeurs multiples qui sont séparées par le même caractère (la virgule) servant à distinguer les différentes colonnes. Ceci créé un fichier à nombre de colonnes variables ce qui pose problème avec l'utilisation de la fonction `read.csv` de R nous obligeant alors à parser nous même le fichier.


```R
#Lecture du fichier
airodump <- readLines('airmonng_data.csv')

#Supprime les espaces entre le séparateur
airodump <- gsub('\\s*,\\s*', ',', airodump)

#Séparation des données des Points d'accès et des clients
i <- cumsum(airodump == '')
airodump <- by(airodump, i, paste, collapse='\n')
aps <- read.csv(text=airodump[1], stringsAsFactors=FALSE)
stations <- airodump[2]
```
L'utilisation de `stringsAsFactors=FALSE` nous permet d'avoir des colonnes contenant simplement les données sans utiliser de facteurs/levels.
Concernant les données clients (`stations`) nous devons appliquer un traitement supplémentaire pour avoir une structure CSV conforme et parser les données afin obtenir un dataframe exploitable:

```R
#Sépare les données par lignes
stations <- strsplit(stations, '\n', fixed=FALSE)$`2`

#Supprime les lignes vides
stations <- stations[stations != ""]

#Récupère jusqu'à la 6eme colonne (au delà il s'agit de la colonne "Probed ESSIDs" qui utilise le même séparateur pour contenir
#plusieurs valeurs, ce qui crée un nombre de colonne variable d'une ligne à l'autre)
stations <- lapply(strsplit(stations, ","), `[`, 1:6)

#Supprime le nom de chaque colonne contenu dans la première ligne (header) car il contient des espaces et des #
stations[1] <- NULL

#Passe la liste de vecteur en dataframe
stations<- as.data.frame(do.call(rbind, stations), stringsAsFactors=FALSE)

#Ajoute le header
colnames(stations) <- c('MacAddress', 'FirstTimeSeen', 'LastTimeSeen', 'Power', 'Packets', 'BSSID')
```

Pour exclure les client n'étant connecté à aucun point d'accès:
```R
stations <- subset(stations, !(BSSID %in% c('(not associated)') ))
```

Nous allons travailler à partir du dataframe `stations` qui contient les données des clients. Pour commencer, nous allons "résoudre" l'adresse MAC du point d'accès en nom de réseau auquel sont connectés les clients à partir de la colonne BSSID (comme un jointure en SQL):
```R
stations$Network <- aps$ESSID[match(stations$BSSID, aps$BSSID)]
```
Notons que la totalité des colonnes du dataframe `aps` aurait pu être ajoutée avec la fonction `merge()`.

Certains points d'accès ne diffusent pas le nom de leur réseau (d'où les `NA` dans la colonne `stations$Network`), utilisons leur adresse MAC pour combler ce manque:
```R
stations$Network <- ifelse(stations$Network == "", stations$BSSID, stations$Network)
```

Notons que la fonction `ifelse()` ne fonctionne pas sur facteurs, c'est pourquoi nous utilisons `stringsAsFactors=FALSE`. Autrement il aurait fallu utiliser `as.character()` pour chaque paramètre de `ifelse()`. Au lieu d'utiliser `ifelse()` nous aurions pu utiliser un vecteur logique afin d'effectuer la même opération:
```R
hidden <- stations$Network == ""
stations$Network[hidden] <- stations$BSSID[hidden]
```

Complétons nos données en identifiant les constructeurs depuis les adresses MAC avec les listes disponibles sur le site de l' [IEEE](https://standards.ieee.org/content/ieee-standards/en/products-services/regauth/index.html). R permet de lire cette liste localement ou directement depuis le site de l'IEEE (moins rapide) en fournissant l'URL comme paramètre à `read.csv()`.

```R
#Chargement de la liste des constructeurs
manufacturers <- read.csv('oui.csv', header=TRUE, sep=",", stringsAsFactors=FALSE)

#Crée une colonne contenant l'identifiant du constructeur depuis l'adresse MAC
stations$ManufacturerID <- substr( gsub(':', '', stations$MacAddress), 0, 6)

#Obtient le nom du constructeur et le stock dans une nouvelle colonne Constructor
stations$Manufacturer <- manufacturers$Organization.Name[match(stations$ManufacturerID, manufacturers$Assignment)]

#Trie les lignes du dataframe par ordre alphabétique des noms de réseau
stations <- stations[order(stations$Network),]
```

## Analyse et présentation des données

Nous sommes maintenant en mesure d'analyser nos données.
Commençons par comptabiliser le nombre de client connecté à chaque point d'accès:
```R
connected <- as.data.frame( table(stations$Network) )
connected[order(-connected$Freq),]
```

Ce qui nous donne:

```text
Var1           Freq
TELUS1643-2.4G    3
CE4E26CF3663      1
TELUS0291         1
TELUS2455         1
TELUS5176-2.4G    1
TELUS9471         1
TELUS9714         1
```

Nous pouvons représenter la quantité de données échangées entre chaque clients/points d'accès avec un [diagramme de Sankey](https://fr.wikipedia.org/wiki/Diagramme_de_Sankey) à l'aide de la librairie `networkD3`:
```R
links <- data.frame(source=stations$MacAddress, target=stations$Network, value=as.integer(stations$Packets))
nodes <- data.frame(name=unique( c(as.character(links$source), as.character(links$target) ) ) )
links$IDsource <- match(links$source, nodes$name)-1
links$IDtarget <- match(links$target, nodes$name)-1
networkD3::sankeyNetwork(Links = links, Nodes = nodes,
                         Source = 'IDsource',
                         Target = 'IDtarget',
                         Value = 'value',
                         NodeID = 'name',
                         units = 'Packets',
                         sinksRight=FALSE,
                         fontSize = 15, nodeWidth = 20)
```

Le diagramme qui en résulte est interactif avec RStudio (le survol indique la quantité de paquets), en voici la capture d'écran:

![Diagramme Sankey](sankey.png)


D'autre types de diagrammes (graphe/réseau) sont utilisables afin de mieux présenter la topologie d'un réseau. Ce type d'analyse peut rapidement produire des diagrammes très complexes en fonction de la quantités de noeuds présents dans le réseau.


## Liens complémentaires

 - [Script R complet](./wifi.R)
 - [https://bost.ocks.org/mike/sankey/](https://bost.ocks.org/mike/sankey/)
 - [https://www.r-graph-gallery.com/321-introduction-to-interactive-sankey-diagram-2/](https://www.r-graph-gallery.com/321-introduction-to-interactive-sankey-diagram-2/)
 - [https://www.jessesadler.com/post/network-analysis-with-r/](https://www.jessesadler.com/post/network-analysis-with-r/)
 - [https://briatte.github.io/ggnet/](https://briatte.github.io/ggnet/)
