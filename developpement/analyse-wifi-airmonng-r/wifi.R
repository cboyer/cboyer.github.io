#Collecte de données avec Airmon-ng:
#airmon-ng start wlp3s0
#airodump-ng --band abg -w airmonng_data.csv --output-format csv wlp3s0mon

#Lecture du fichier
airodump <- readLines('airmonng_data.csv')

#Supprime les espaces entre le séparateur
airodump <- gsub('\\s*,\\s*', ',', airodump)

#Séparation des données des Points d'accès et des clients
i <- cumsum(airodump == '')
airodump <- by(airodump, i, paste, collapse='\n')
aps <- read.csv(text=airodump[1], stringsAsFactors=FALSE)
aps

#Lit les stations
stations <- airodump[2]

#Sépare les données par lignes
stations <- strsplit(stations, '\n', fixed=FALSE)$`2`

#Supprime les lignes vides
stations <- stations[stations != ""] 

#Récupère jusqu'à la 6eme colonne (au delà il s'agit de la colonne "Probed ESSIDs" qui utilise le même séparateur pour contenir plusieurs valeurs, ce qui crée un nombre de colonne variable d'une ligne à l'autre)
stations <- lapply(strsplit(stations, ","), `[`, 1:6)

#Supprime le nom de chaque colonne contenu dans la première ligne (header) car il contient des espaces et des #
stations[1] <- NULL

#Passe la liste de vecteur en dataframe
stations<- as.data.frame(do.call(rbind, stations), stringsAsFactors=FALSE)

#Ajoute le header
colnames(stations) <- c('MacAddress', 'FirstTimeSeen', 'LastTimeSeen', 'Power', 'Packets', 'BSSID')

#Filtre les stations non associées à un AP
stations <- subset(stations, !(BSSID %in% c('(not associated)') ))

#merge(stations, aps, by="BSSID", all.x=TRUE)
stations$Network <- aps$ESSID[match(stations$BSSID, aps$BSSID)]

#Si l'AP ne diffuse pas le nom de réseau, on prend son adresse MAC
stations$Network <- ifelse(stations$Network == "", stations$BSSID, stations$Network)
#On aurait pu utiliser:
#hidden <- stations$Network == ""
#stations$Network[hidden] <- stations$BSSID[hidden]

#Chargement de la liste des contructeurs https://standards.ieee.org/content/ieee-standards/en/products-services/regauth/index.html
manufacturers <- read.csv('oui.csv', header=TRUE, sep=",", stringsAsFactors=FALSE)
stations$ManufacturerID <- substr( gsub(':', '', stations$MacAddress), 0, 6)
stations$Manufacturer <- manufacturers$Organization.Name[match(stations$ManufacturerID, manufacturers$Assignment)]
stations[order(stations$Network),]

#Nombre de station connectées par AP
connected <- as.data.frame( table(stations$Network) )
connected[order(-connected$Freq),]

#Affichage sous forme de diagramme de Sankey
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