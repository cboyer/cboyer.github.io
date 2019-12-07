---
title: "R: les incontournables"
date: "2019-05-25T10:09:13-04:00"
updated: "2019-12-07T18:40:21-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [R, RStudio, ODBC, SQL, MSSQL, Oracle, code snippets, développement]
abstract: |
  Opérations incontournables avec le langage R.
---


Cet article recense les opérations incontournables avec R:

- [Options d'exécution](#optionsexec)
- [Base de données](#db)
- [Opérations sur les fichiers](#files)
- [Statistiques](#stats)
- [Opérations sur les données](#data)


## <a name="optionsexec"></a>Options d'exécution

Augmenter la taille des messages d'erreur au maximum (permet d'afficher les erreurs à la fin de longues requêtes SQL):
```R
options(warning.length = 8170)
```

Ne pas utiliser la notation scientifique pour les entiers de grande taille (s'applique également lors de l'écriture de fichiers CSV):
```R
options(scipen = 999)
```

Ne pas utiliser la factorisation pour les chaîne de caractères:
```R
options(stringsAsFactors = FALSE)
```

Ajuster la mémoire allouée à Java pour les appels externes (par exemple les requêtes SQL avec JDBC, doit être placé avant `require` et `librairy`):
```R
options(java.parameters = "-Xmx1024m")

#Pour également utiliser le Garbage Collector
options(java.parameters = c("-XX:+UseConcMarkSweepGC", "-Xmx1024m"))
```


## <a name="db"></a>Base de données

Utilisation de ODBC avec des sources configurées (DSN) dans Windows (utile pour la gestion de l'authentification):
```R
require(DBI)
con <- dbConnect(odbc::odbc(), "MonDataSourceWindows")
sql <- "SELECT UserID FROM User"
userids <- dbGetQuery(con, sql)
dbDisconnect(con)
```

MSSQL via ODBC sans sources configurées (DSN):
```R
require(DBI)
con <- dbConnect(odbc::odbc(),
                 Driver = "SQL Server",
                 Server = "1.2.3.4",
                 Port = "1433",
                 Database = "mydb",
                 UID = "Interface",
                 PWD = "Integration")
```

Oracle via ODBC sans sources configurées (DSN):
```R
require(DBI)
con <- dbConnect(odbc::odbc(),
                 Driver = "Oracle dans OraClient12Home1",
                 DBQ = "//1.2.3.4:1521/mydatabase",
                 UID = "login",
                 PWD = "password")
```

Oracle via JDBC:
```R
require(RJDBC)
drv <- JDBC(driverClass="oracle.jdbc.OracleDriver", classPath="C:/Users/monLogin/Documents/Developpement/JDBC/ojdbc8.jar")
conn <- dbConnect(drv, "jdbc:oracle:thin:@//10.10.10.10:1521/database", "login", "password")
sql <- "SELECT UserID FROM User"
userids <- dbGetQuery(conn, sql)
dbDisconnect(conn)
```

MSSQL via JDBC:
```R
require(RJDBC)
drv <- JDBC("com.microsoft.sqlserver.jdbc.SQLServerDriver", "C:/Users/monLogin/Documents/Developpement/JDBC/sqljdbc42.jar")
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
  data.frame(table=x, column=as.vector(dbListFields(conn, x)))
}, conn = con)
schema <- do.call(rbind, describe)
```

## <a name="files"></a>Opérations sur les fichiers

Charger un fichier CSV:
```R
mon_dataframe <- read.csv("C:/Users/monLogin/Desktop/fichier.csv", header = TRUE, sep = ";", encoding = "UTF-8", stringsAsFactors = FALSE)
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


## <a name="stats"></a>Statistiques

Factoriser des valeurs:
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

Extraire les lignes en fonction de la valeur d'une colonne:
```R
users_active <- subset(users, isactive == 1)
users_active <- users[users$isactive == 1,]
users_without_email <- subset(users, is.na(email))
users_with_email <- subset(users, !is.na(email))

#Avec plusieurs critères ( | signifie OR, & signifie AND):
users[ which(users$Active == "1" & !is.na(users$email) & users$OS %in% c("Linux", "Solaris") ), ]
```


Remplacer toutes les valeurs d'un colonne répondant à un critère:
```R
users$email[users$email == "unknown"] <- ""
```

Reformater une date:
```R
ventes$annee_expedition <- format(as.Date(ventes$date_expedition, format="%Y-%m-%d"),"%Y")
```

Lister les lignes dont une valeur est dupliquée:
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

Récupère les lignes de dataframe1 dont LOGIN et LAST_DATE sont dans dataframe2
```R
intersection <- dataframe1[with(dataframe1, paste(LOGIN, LAST_DATE, sep=".")) %in% with(dataframe2, paste(LOGIN, LAST_DATE, sep=".")), ]
```

Supprimer les lignes dont la valeur d'une colonne spécifique se répète:
```R
users <- duplicats[!( duplicated(duplicats$UserID) | duplicated(duplicats$UserID, fromLast = TRUE) ),]
```

Supprimer les lignes dupliquées (toutes les colonnes sont identiques d'une ligne à l'autre):
```R
users <- duplicats[!( duplicated(duplicats) | duplicated(duplicats, fromLast = TRUE) ) ,]
```

Copier la valeur d'une colonne dans une autre en fonction d'une condition:
```R
stations$Network <- ifelse(stations$Network == "", stations$BSSID, stations$Network)
```

Traiter une colonne (chaîne de caractères) pour remplacer certains caractères par un espace:
```R
users <- within(users,  Descriptions <- gsub("[,;\"\r\n]", " ", Descriptions) )

#Autre possibilité:
users$Descriptions <- sapply(users$Descriptions, function(x) { gsub("[,;\"\r\n]", " ", x) })
```

Traiter un dataframe (plusieurs colonnes) en itérant sur chaque ligne (retourne un dataframe à 3 colonnes depuis un dataframe `x` à 2 colonnes):
```R
result <- apply(mydataframe, 1, function(x, y) {

  #x[1] = première colonne de mydataframe, x[2] la seconde
  data.frame(table=x[1], column=x[2], res=1)

}, y = additionnal_arg)

#Transforme result en dataframe
result <- do.call(rbind, result)
```

Regroupe les `login` et récupère max(last_login_date) (équivaut à Group By en SQL)
```R
aggregate(last_login_date ~ login, data=users, FUN=max)
```

Regroupe toutes les autres colonnes et récupère max(last_login_date)
```R
aggregate(last_login_date ~ ., data=users, FUN=max)
```

Compléter un dataframe en récupérant la colonne d'un autre dataframe selon une correspondance (comme une jointure SQL):
```R
stations$Manufacturer <- manufacturers$OrganizationName[match(stations$ManufacturerID, manufacturers$ManufacturerID)]
```

Fusionner les lignes de deux dataframes par correspondance de colonnes spécifiques:
```R
all_users <- merge(users_windows, user_linux, by="login")

#Avec deux colonnes dont les noms diffèrent:
all_users <- merge(users_windows, user_linux, by.x="samAccount", by.y="login")

#Avec plusieurs colonnes dont les noms diffèrent (en completant avec NA si pas de correspondances comme un left join en SQL):
all_users <- merge(users_windows, user_linux, by.x=c("samAccount","email"), by.y=c("login","mail"), all.x = TRUE)
```

Associer deux dataframes verticalement (l'un à la suite de l'autre, doivent avoir les mêmes colonnes):
```R
users_windows <- rbind(users_windowsNT, users_windowsXP)
```


### Sources

- [DB: SQLServer](https://db.rstudio.com/databases/microsoft-sql-server/)
- [DB: Oracle](https://db.rstudio.com/databases/oracle/)
- [Subset](https://www.statmethods.net/management/subset.html)
