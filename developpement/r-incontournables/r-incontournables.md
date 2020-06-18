---
title: "R: les incontournables"
date: "2019-05-25T10:09:13-04:00"
updated: "2020-06-02T20:30:29-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [R, RStudio, ODBC, SQL, MSSQL, Oracle, code snippets, développement]
abstract: |
  Opérations incontournables avec le langage R.
---

- [Options d'exécution](#optionsexec)
- [Base de données](#db)
- [Opérations sur les fichiers](#files)
- [Statistiques](#stats)
- [Opérations sur les données](#data)
- [Pipelines Dplyr](#dplyr)
- [Graphiques](#graphiques)


## <a name="optionsexec"></a>Options d'exécution

Augmenter la taille des messages d'erreur au maximum (permet d'afficher les erreurs à la fin de longues requêtes SQL)
```R
options(warning.length = 8170)
```

Ne pas utiliser la notation scientifique pour les entiers de grande taille (s'applique également lors de l'écriture de fichiers CSV)
```R
options(scipen = 999)
```

Ne pas utiliser la factorisation pour les chaîne de caractères (par défaut depuis R 4.0)
```R
options(stringsAsFactors = FALSE)
```

Ajuster la mémoire allouée à Java pour les appels externes (par exemple les requêtes SQL avec JDBC, doit être placé avant `require` et `librairy`)
```R
options(java.parameters = "-Xmx1024m")

#Pour également utiliser le Garbage Collector
options(java.parameters = c("-XX:+UseConcMarkSweepGC", "-Xmx1024m"))
```


## <a name="db"></a>Base de données

Utilisation de ODBC avec des sources configurées (DSN) dans Windows (utile pour la gestion de l'authentification)
```R
require(DBI)
con <- dbConnect(odbc::odbc(), "MonDataSourceWindows")
sql <- "SELECT UserID FROM User"
userids <- dbGetQuery(con, sql)
dbDisconnect(con)
```

MSSQL via ODBC sans sources configurées (DSN)
```R
require(DBI)
con <- dbConnect(odbc::odbc(),
                 Driver = "SQL Server",
                 Server = "1.2.3.4",
                 Database = "mydb",
                 User = "login",
                 Password = "password")
```

Oracle via ODBC sans sources configurées (DSN)
```R
require(DBI)
con <- dbConnect(odbc::odbc(),
                 Driver = "Oracle dans OraClient12Home1",
                 DBQ = "//1.2.3.4:1521/mydatabase",
                 UID = "login",
                 PWD = "password")
```

Oracle via JDBC
```R
require(RJDBC)
drv <- JDBC(driverClass = "oracle.jdbc.OracleDriver", classPath = "C:/JDBC/ojdbc8.jar")
conn <- dbConnect(drv, "jdbc:oracle:thin:@//10.10.10.10:1521/database", "login", "password")
sql <- "SELECT UserID FROM User"
userids <- dbGetQuery(conn, sql)
dbDisconnect(conn)
```

MSSQL via JDBC
```R
require(RJDBC)
drv <- JDBC("com.microsoft.sqlserver.jdbc.SQLServerDriver", "C:/JDBC/sqljdbc42.jar")
conn <- dbConnect(drv, "jdbc:sqlserver://mssqlserver.corp.ca;databaseName=MyDatabase", "login", "password")
sql <- "SELECT UserID FROM User"
userids <- dbGetQuery(conn, sql)
dbDisconnect(conn)
```

Lister les tables et colonnes d'une base de données
```R
require(DBI)
con <- dbConnect(odbc::odbc(),
                 Driver = "SQL Server",
                 Server = "1.2.3.4",
                 Database = "mydb",
                 User = "domaine\\login",
                 Password = "password")

tables <- dbListTables(con)
describe <- lapply(tables, function(x, conn) {
  data.frame(table = x, column = as.vector(dbListFields(conn, x)))
}, conn = con)
schema <- do.call(rbind, describe)
```

Requête avec une liste formée depuis une colonne
```R
client_id <- toString(sprintf("'%s'", liste$client_id))
sql <- paste('SELECT client_id FROM myTable WHERE client_id IN (', client_id, ')', sep = "")
```

## <a name="files"></a>Opérations sur les fichiers

Charger un fichier CSV
```R
mon_dataframe <- read.csv("C:/fichier.csv", header = TRUE, sep = ";", encoding = "UTF-8", stringsAsFactors = FALSE)
```

Écrire le contenu d'un dataframe dans un fichier CSV
```R
write.table(mon_dataframe, file = "C:/fichier.csv", row.names = FALSE, quote = FALSE, sep = ',', na = '')
```

Écrire une variable dans un fichier texte
```R
text <- "String example"
fd <- file("C:/fichier.txt")
writeLines(text, fd)
close(fd)
```

Charger un fichier Excel (XSLX/XLS)
```R
require(xlsx)
liste <- read.xlsx("./mon_fichier.xlsx", sheetName = 1, encoding = "UTF-8")

#Cleanup colonnes avec style mais vides
drops <- as.vector(paste("NA..", seq(1:20000), sep = '' ))
drops <- c('NA.', drops)
liste <- liste[ , !(names(liste) %in% drops)]
```


## <a name="stats"></a>Statistiques

Factoriser des valeurs
```R
ventes$annee <- as.factor(ventes$annee)
```

Statistiques descriptives générales (pour les valeurs de type char, il est nécessaire d'utiliser des facteurs)
```R
summary(ventes)
```

Fréquence des valeurs d'une colonne en fonction d'une autre (produits vendus en fonction des années)
```R
tapply(ventes$produit, ventes$annee, summary)
```

## <a name="data"></a>Opérations sur les données

Extraire les lignes en fonction de la valeur d'une colonne
```R
users_active <- subset(users, isactive == 1)
users_active <- users[users$isactive == 1,]
users_without_email <- subset(users, is.na(email))
users_with_email <- subset(users, !is.na(email))

#Avec plusieurs critères ( | signifie OR, & signifie AND)
users[ which(users$Active == "1" & !is.na(users$email) & users$OS %in% c("Linux", "Solaris") ), ]
```

Trier sur plusieurs colonnes (colonne 1 à 3)
```R
k <- k[order(k[,1], k[,2], k[,3] ), ]
```

Remplacer toutes les valeurs d'un colonne répondant à un critère
```R
users$email[users$email == "unknown"] <- ""

#Pour une ligne (toutes les colonnes)
erreur[erreur == "NA"] <- NA
```

Changer l'encodage d'une colonne de type `character`
```R
Encoding(users$firstname) <- "ISO-8859-1"
```

Reformater une date
```R
ventes$annee_expedition <- format( as.Date(ventes$date_expedition, format = "%Y-%m-%d"),"%Y")
```

Lister les lignes dont une valeur est dupliquée
```R
duplicats <- users[duplicated(users$UserID) | duplicated(users$UserID, fromLast = TRUE),]

#Alternative (moins performante)
decompte <- data.frame(table(users$UserID))
duplicats <- users[users$UserID %in% decompte$Var1[decompte$Freq > 1], ]
```

Déterminer les données manquantes d'un dataframe à un autre en fonction d'une colonne
```R
utilisateurs_manquants <- users[!(users$UserID %in% all_users$UserID), ]
```

Récupère les lignes de dataframe1 dont LOGIN et LAST_DATE sont dans dataframe2
```R
intersection <- dataframe1[with(dataframe1, paste(LOGIN, LAST_DATE, sep = ".")) %in% with(dataframe2, paste(LOGIN, LAST_DATE, sep = ".")), ]

#Alternative
intersection <- dataframe1[match( paste(dataframe1$LOGIN, dataframe1$LAST_DATE), paste(dataframe2$LOGIN, dataframe2$LAST_DATE) ), ]
```

Compléter un dataframe en récupérant la colonne d'un autre dataframe selon une correspondance (comme une jointure SQL)
```R
stations$Manufacturer <- manufacturers$OrganizationName[match(stations$ManufacturerID, manufacturers$ManufacturerID)]

#Sur plusieurs colonnes
stations$Manufacturer <- manufacturers$OrganizationName[match( paste(stations$ManufacturerID, stations$ManufacturerName), paste(manufacturers$ManufacturerID, manufacturers$ManufacturerName) )]
```

Supprimer les lignes dont la valeur d'une colonne spécifique se répète (conserve un seul des éléments dédoublés)
```R
users <- duplicats[! duplicated(duplicats$UserID),]
```

Supprimer les lignes dont la valeur d'une colonne spécifique se répète (ne conserve aucun des éléments dédoublés)
```R
users <- duplicats[!( duplicated(duplicats$UserID) | duplicated(duplicats$UserID, fromLast = TRUE) ),]
```

Supprimer les lignes dupliquées (toutes les colonnes sont identiques d'une ligne à l'autre, ne conserve aucun des éléments dédoublés)
```R
users <- duplicats[!( duplicated(duplicats) | duplicated(duplicats, fromLast = TRUE) ) ,]
```

Copier la valeur d'une colonne dans une autre en fonction d'une condition
```R
stations$Network <- ifelse(stations$Network == "", stations$BSSID, stations$Network)
```

Traiter une colonne (chaîne de caractères) pour remplacer certains caractères par un espace
```R
users <- within(users,  Descriptions <- gsub("[,;\"\r\n]", " ", Descriptions) )

#Alternative
users$Descriptions <- sapply(users$Descriptions, function(x) { gsub("[,;\"\r\n]", " ", x) })

#Pour les espaces de début/fin
users <- within(users,  Descriptions <- trimws(Descriptions) )
```

Traiter un dataframe (plusieurs colonnes) en itérant sur chaque ligne (retourne un dataframe à 3 colonnes depuis un dataframe `x` à 2 colonnes)
```R
result <- apply(mydataframe, 1, function(x, y) {

  #x[1] = première colonne de mydataframe, x[2] la seconde
  data.frame(table = x[1], column = x[2], res = 1)

}, y = additionnal_arg)

#Transforme result en dataframe
result <- do.call(rbind, result)
```

Récupérer `max(last_login_date)` en fonction de `login` (Group By en SQL), les *NA* sont ignorés par `aggregate()`
```R
aggregate(last_login_date ~ login, data = users, FUN = max)

#En fonction de toutes les autres colonnes (permet de les conserver en sortie)
aggregate(last_login_date ~ ., data = users, FUN = max)

#En fonction d'une liste de colonnes
aggregate(last_login_date ~ login + type, data = users, FUN = max)

#Alternative avec dplyr:
users <- users %>% group_by(login, type) %>%
                   summarize(max_login_date = max(last_login_date))
```

Regrouper les dates par login sur une même ligne (concatène les valeurs séparées par une virgule)
```R
aggregate(login_date ~ login, data = users, FUN = toString)
aggregate(login_date ~ login, data = users, FUN = paste, collapse = ",")

#Alternative pour obtenir un vecteur
aggregate(login_date ~ login, data = users, FUN = c)
```

Séparer les dates concaténées précédemment (crée une liste dans cette ligne/colonne)
```R
users$dateList <- strsplit(users$login_date, ", ") #Pour rechercher directement dans dateList: unlist(users$dateList)

#Dupliquer les lignes pour chaque date (TidyR)
unnest(users, cols = dateList)
```

Séparer les dates concaténées précédemment en colonnes distinctes (avec plusieurs séparateurs)
```R
library(tidyr)
separate(users, Email, c("Email", "Email2", "Email3"), "[;-,]")

#Alternative avec stringr
library(stringr)
str_split_fixed(users$Email, "[;-,]", 3)
```

Pivot des valeurs d'une colonne `Champs` en nouvelles colonnes avec pour valeurs la colonne `Valeur` (implicite) pour chaque ligne identifiée par `idvar`
```R
reshape(inventaire, direction = "wide", idvar = c("ItemID", "Item", "Type", "Categorie"), timevar = "Champs")

#Alternative TidyR, beaucoup plus performante:
pivot_wider(inventaire, id_cols = c("ItemID","Item", "Type"), names_from = Champs, values_from = Valeur)
```

Fusionner les lignes de deux dataframes par correspondance de colonnes spécifiques
```R
all_users <- merge(users_windows, user_linux, by = "login")

#Avec deux colonnes dont les noms diffèrent
all_users <- merge(users_windows, user_linux, by.x = "samAccount", by.y = "login")

#Avec plusieurs colonnes dont les noms diffèrent (en completant avec NA si pas de correspondances, Left Join en SQL)
all_users <- merge(users_windows, user_linux, by.x = c("samAccount","email"), by.y = c("login","mail"), all.x = TRUE)
```

Associer deux dataframes verticalement (l'un à la suite de l'autre, doivent avoir les mêmes colonnes)
```R
users_windows <- rbind(users_windowsNT, users_windowsXP)
```

## <a name="dplyr"></a>Pipelines Dplyr

Calcul des taux de saisie de chaque champ
```R
saisies <- formulaires %>%
           select(Valeur, Type, TypeChamps, Champs) %>%
           mutate(IsEmpty = ifelse(is.na(Valeur), TRUE, FALSE) ) %>%
           group_by(IsEmpty, Type, TypeChamps, Champs) %>%
           summarize(Vide = length(Type[IsEmpty == TRUE]), Saisi = length(Type[IsEmpty == FALSE])) %>%
           group_by(Type, TypeChamps, Champs) %>%
           summarize(Vide = sum(Vide), Saisi = sum(Saisi), Saisi_p = round( (Saisi / (Vide + Saisi))*100, digits = 2) )
```

## <a name="graphiques"></a>Graphiques

Histogramme horizontal avec palette de couleurs adaptée (données issues de `table()`)
```R
library(ggplot2)
library(RColorBrewer)
nbcolors <- length(unique(FreqAnomaly$Var1))
customPalette <- colorRampPalette(brewer.pal(9, "Blues"))(nbcolors)
customPalette[customPalette == "#F7FBFF"] <- "#498fd1" #Pour remplacer une couleur

ggplot(FreqAnomaly,
       aes(x = reorder(Var1, Freq), y = Freq, fill = Var1, label = Freq)) + 
       geom_bar(stat = "identity", position = "dodge") +
       geom_text(size = 3, position = position_dodge(width = 0.0), vjust = +0.25, hjust = -0.25) +
       theme_minimal() +
       labs(title = "Titre", x = "", y = "", color = "") +
       #scale_fill_brewer(palette="Blues") + 
       scale_fill_manual(values = customPalette) +
       theme(legend.position = "none", plot.title = element_text(hjust = 0.5)) + 
       coord_flip()
```

Histogramme vertical avec palette de couleurs adaptée et labels inclinés (données issues de `table()`)
```R
ggplot(FreqAnomalyComb,
       aes(x = reorder(Var1, -Freq), y = Freq, fill = Var1, label = Freq)) + 
       geom_bar(stat = "identity", position = "dodge") +
       geom_text(size = 3, position = position_dodge(width = 0.9), vjust = -0.25) +
       theme_minimal() +
       labs(title = "Titre", x = "", y = "", color = "") +
       #scale_fill_brewer(palette="Blues") + 
       scale_fill_manual(values = customPalette) + 
       theme(legend.position = "none", plot.title = element_text(hjust = 0.5), axis.text.x = element_text(angle = 45, hjust = 1))
```



### Liens complémentaires

- [DB: SQLServer](https://db.rstudio.com/databases/microsoft-sql-server/)
- [DB: Oracle](https://db.rstudio.com/databases/oracle/)
- [Subset](https://www.statmethods.net/management/subset.html)
- [Statistiques en sciences humaines et sociales avec R, Jean-Herman Guay](http://dimension.usherbrooke.ca/dimension/v2ssrcadre.html)
- [Harvard R Graphics](https://tutorials.iq.harvard.edu/R/Rgraphics/Rgraphics.html)
