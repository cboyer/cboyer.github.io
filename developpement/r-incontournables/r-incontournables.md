---
title: "R: les incontournables"
date: "2019-05-25T10:09:13-04:00"
updated: "2019-05-25T10:09:13-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [R, code snippets, RStudio, développement]
abstract: |
  Opérations incontournables avec le langage R.
---


Cet article recense les opérations incontournables avec R:


## Options d'exécution

Augmenter la taille des messages d'erreur au maximum (permet les erreurs à la fin de longues requêtes SQL):
```R
options(warning.length = 8170)
```

Ne pas utiliser la notation scientifique pour les entiers de grande taille (s'applique lors de l'écriture de fichiers CSV):
```R
options(scipen=999)
```

Ajuster la mémoire allouée à Java pour les appels externes (par exemple les requêtes SQL avec JDBC):
```R
options(java.parameters = "-Xmx1024m")
options(java.parameters = c("-XX:+UseConcMarkSweepGC", "-Xmx1024m"))
```


## Base de données SQL

Utilisation de ODBC avec des sources configurées dans Windows (utile pour la gestion de l'authentification)
```R
require(odbc)
con <- dbConnect(odbc::odbc(), "MonDataSourceWindows")
sql <- "SELECT UserID FROM User"
queryResults <- dbSendQuery(con, sql)
userids <- dbFetch(queryResults)
dbClearResult(queryResults)
dbDisconnect(con)
```

Utilisation du pilote JDBC pour Oracle
```R
require(RJDBC)
drv <- JDBC(driverClass="oracle.jdbc.OracleDriver", classPath="C:/Users/monLogin/Documents/Developpement/JDBC/ojdbc8.jar")
conn <- dbConnect(drv, "jdbc:oracle:thin:@//10.10.10.10:1521/database", "login", "password")
sql <- "SELECT UserID FROM User"
userids <- dbGetQuery(conn, sql)
dbDisconnect(conn)
```

Utilisation du pilote JDBC pour MSSQL
```R
require(RJDBC)
drv <- JDBC("com.microsoft.sqlserver.jdbc.SQLServerDriver", "C:/Users/monLogin/Documents/Developpement/JDBC/sqljdbc42.jar")
conn <- dbConnect(drv, "jdbc:sqlserver://mssqlserver.corp.ca;databaseName=MyDatabase", "login", "password")
sql <- "SELECT UserID FROM User"
userids <- dbGetQuery(conn, sql)
dbDisconnect(conn)
```

## Opérations sur les fichiers

Charger un fichier CSV:
```R
mon_dataframe <- read.csv("C:/Users/monLogin/Desktop/fichier.csv", header = TRUE, sep = ";")
```

Écrire le contenu d'un dataframe dans un fichier CSV:
```R
write.table(mon_dataframe, file = "C:/Users/monLogin/Desktop/fichier.csv", row.names = FALSE, quote = FALSE, sep = ',')
```

Écrire une variable dans un fichier texte:
```R
text <- "String example"
fileConn<-file("C:/Users/monLogin/Desktop/fichier.txt")
writeLines(text, fileConn)
close(fileConn)
```


## Opérations sur les données

Extraire les lignes en fonction de la valeur d'une colonne:
```R
users_active <- subset(users, isactive == 1)
users_without_email <- subset(users, is.na(email))
users_with_email <- subset(users, !is.na(email))
```

Lister les duplicats:
```R
duplicats <- users[duplicated(users$UserID) | duplicated(users$UserID, fromLast=TRUE),]

#Autre possibilité (moins performante)
decompte <- data.frame(table(users$UserID))
duplicats <- users[users$UserID %in% decompte$Var1[decompte$Freq > 1], ]
```

Déterminer les données manquantes d'un dataframe à un autre en fonction d'une colonne:
```R
utilisateurs_manquants <- users[!(users$UserID %in% all_users$UserID), ]
```

Supprimer les duplicats (lignes) dont la valeur d'une colonne spécifique se répète:
```R
users <- duplicats[!duplicated(duplicats$UserID),]
```

Supprimer les duplicats (lignes similaires):
```R
users <- duplicats[!duplicated(duplicats),]
```

Copier la valeur d'une colonne dans une autre en fonction d'une condition:
```R
stations$Network <- ifelse(stations$Network == "", stations$BSSID, stations$Network)
```

Traiter une colonne (chaîne de caractères) pour remplacer certains caractères par un espace:
```R
users$Descriptions <- sapply(users$Descriptions, function(x) { gsub("[,;\"\r\n]", " ", x) })
```

Fusionner les lignes de deux dataframes par correspondance de colonnes spécifiques:
```R
all_users <- merge(users_windows, user_linux, by="login")

#Avec deux colonnes dont les nom diffèrent:
all_users <- merge(users_windows, user_linux, by.x="samAccount", by.y="login")
```

Associer deux dataframes verticalement (l'un à la suite de l'autre, doivent avoir les mêmes colonnes):
```R
users_windows <- rbind(users_windowsNT, users_windowsXP)
```
