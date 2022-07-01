---
title: "Afficher des données avec DataTables"
date: "2020-10-09T18:13:11-04:00"
updated: "2020-10-09T18:13:11-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [DataTables, javascript, php]
abstract: "Afficher des données avec DataTables."
---

## Arborescence des fichiers

├─ css
|  └── jquery.dataTables.min.css
├─ images
|  ├── sort_asc.png
|  ├── sort_both.png
|  └── sort_desc.png'
├─ js
|  ├── jquery-3.5.1.js
|  └── jquery.dataTables.min.js
├─ index.html
└─ stats.php

## Récupérer les données avec PHP depuis une base de données

```PHP
<?php
    header('Content-type:application/json;charset=utf-8');
    $servername = "localhost";
    $username = "login";
    $password = "password";
    $dbname = "database";

    $conn = new mysqli($servername, $username, $password, $dbname);

    if ($conn->connect_error) {
        die("Connection failed: " . $conn->connect_error);
    }

    $sql = "
        SELECT send_date AS 'Date de traitement', 
        COUNT(
            CASE
                WHEN email_valid = 0 THEN 'invalid'
                ELSE NULL
            END
        ) AS 'Courriel incorrect',
        COUNT(
            CASE 
                WHEN email IS NULL THEN 'none'
                ELSE NULL 
            END
        ) AS 'Sans courriel',
        COUNT(
            CASE 
                WHEN email_valid = 1 THEN 'sent'
                ELSE NULL 
            END
        ) AS 'Envoyé',

        FROM t_email
        GROUP BY send_date;
    ";

    $sth = mysqli_query($conn, $sql);
    $rows = array();

    while($row = $sth->fetch_assoc()) {
        $rows[] = $row;
    }

    $sth->free_result();
    $conn->close();

    //Retourne les données au format JSON
    print json_encode($rows);
?>
```


## Affichage des données avec DataTables

```HTML
<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <title>Test DataTables</title>
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta name="description" content="Test DataTables">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="css/jquery.dataTables.min.css">
  <script type="text/javascript" charset="utf8" src="js/jquery-3.5.1.js"></script>  
  <script type="text/javascript" charset="utf8" src="js/jquery.dataTables.min.js"></script>
</head>

<body>
  <script>
  $(document).ready(function() {
    $('#table').DataTable( {
    
        //Requête pour récupérer les données depuis PHP
		"ajax" : { "url": "stats.php",
                    "dataSrc": "",
					"dataType": "json"
        },
        
        //Traduction des éléments de l'interface en Français
		"language": {
            "lengthMenu": "Afficher _MENU_ lignes par page",
            "zeroRecords": "Aucune donnée",
            "info": "Page _PAGE_ sur _PAGES_",
			"search": "Rechercher:",
            "infoEmpty": "Aucune donnée disponible",
            "infoFiltered": "(filtrées sur _MAX_)",
			"loadingRecords": "Chargement...",
			"processing":     "Traitement...",
			"paginate": {
				"first":      "Premier",
				"last":       "Dernier",
				"next":       "Suivant",
				"previous":   "Précédent"
			}
        },
        
        //Mapping des données retournées par PHP
        "columns": [
            { "data": "Date de traitement", "title": "Dates de traitement" },
            { "data": "Courriel incorrect", "title": "Adresses courriel incorrectes" },
            { "data": "Sans courriel", "title": "Sans adresse courriel" },
            { "data": "Envoyé", "title": "Messages envoyés" }
        ],
        
        //Centre le contenu des colonnes
		"columnDefs": [
			{"className": "dt-center", "targets": "_all"}
		]
    } );
  } );
  </script>
</body>
<h1>Statistiques</h1>
<br />
<br />
<table id="table" class="display" width="100%"></table>
</html>
```
