---
title: "Traitement de données avec le langage Julia"
date: "2021-06-05T22:33:11-04:00"
updated: "2021-06-05T22:33:11-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [Julia, datascience, données, R]
abstract: "Quelques opérations avec le langage Julia."
---

## Installer des packages
```Julia
import Pkg; Pkg.add("DataFrames"); Pkg.add("CSV"); Pkg.add("Pipe") 
```

## Charger un CSV
```Julia
using DataFrames, CSV, Pipe

CSV.read(
   "./data.csv",          #Chemin vers le fichier CSV
   DataFrame,             #Type de données à retourner
   delim=";",             #Séparateur de colonne
   quotechar='"',         #Délimiteur de chaîne de caractères
   decimal='.',           #Séparateur partieentière/décimale d'un nombre réel
   missingstring="NA",    #Chaîne à utiliser pour les valeurs manquantes
   datarow=2,             #Considère seulement les données à partir de la seconde ligne (ignore l'entête)
   header=["Contrat", "Datetime", "kWh", "CodeConsommation", "Température", "CodeTempérature"], 
   types=[String, String, Float32, String, Int32, String]
)

DataFrame(
   CSV.File(
      "./data.csv", delim=";", quotechar='"', decimal='.', missingstring="NA", datarow=2, 
      header=["Contrat", "Datetime", "kWh", "CodeConsommation", "Température", "CodeTempérature"], 
      types=[String, String, Float32, String, Int32, String], dateformat="yyyy-mm-dd HH:MM:SS"
   )
)

@pipe "./data.csv" |> CSV.File(_, delim=";", types=[String, String, Float32, String, Int32, String], datarow=2, header=["Contrat", "Datetime", "kWh", "CodeConsommation", "Température", "CodeTempérature"]) |> DataFrame(_)
```

Julia comprend un opérateur pipe `|>` mais son utilisation est très limitée comparée au langage Elixir: il ne gère que les fonctions à un seul paramètre et sans saut de lignes.
Le package `Pipe` permet d'étendre le pipe aux fonctions avec plusieurs paramètres en spécifiant la position avec `_` et la macro `@pipe`.

## Résumé des données

```Julia
describe(t)
```
```Text09em
6×7 DataFrame
 Row │ variable          mean      min                  median  max                  nmissing  eltype                  
     │ Symbol            Union…    Any                  Union…  Any                  Int64     Type                    
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Contrat                     0111111111                   0111111111                  0  String
   2 │ Datetime                    2019-07-01 00:00:00          2021-05-15 23:00:00         0  String
   3 │ kWh               0.757529  0.01                 0.17    6.36                       53  Union{Missing, Float32}
   4 │ CodeConsommation            N.D.                         R                           0  String
   5 │ Température       4.35865   -23                  4.0     35                         24  Union{Missing, Int32}
   6 │ CodeTempérature             R                            R                          24  Union{Missing, String}
```

La colonne `eltype` permet de voir s'il y a des missing sur une colonne.
`eltype(t.kWh)` permet de vérifier également les types et la présence de missing.

## Selection de colonnes
```Julia
select(t, :Datetime, :kWh)
t[:, [:Datetime, :kWh]]
```

L'opérateur `[]` est plus rapide et moins couteux en mémoire.


## Filtrer

```Julia
# Pour filtrer les "missing"
filter(x -> ismissing(x.kWh), k)
t[.!ismissing.(t.kWh), :kWh]

# Pour filtrer selon une valeur
filter(x -> x.kWh == 0.5, t)
t[t.kWh .== 0.5, :]
```

Ajouter la macro `@time` au début de l'instruction permet d'afficher le temps d'exécution ainsi que la consommation mémoire de l'opération.
L'utilisation de l'opérateur `[]` est beaucoup plus rapide et moins couteuse en mémoire.


Autre façon de filtrer les missing:
```Julia
# Sur le dataframe au complet
dropmissing!(t)

# Sur une colonne particulière
dropmissing!(t, :kWh)
k.kWh .= ifelse.(ismissing.(k.kWh), 0.0, k.kWh)
```

Le `!` effectue les modifications directement sur le dataframe sans en retourner un nouveau.
Le `.` permet de diffuser l'opération sur une colonne (vectorisation).
La fonction `skipmissing` fonctionne sur un vecteur.


## Transformer des données

```Julia
k.kWh .= ifelse.(k.kWh .< 1.0, missing, k.kWh)
k[k.kWh .< 1.0, :kWh] .= missing

import Dates
transform(t, :Datetime => ByRow(t -> Dates.parse_components(t, Dates.DateFormat("yyyy-mm-dd HH:MM:SS"))) => :ParsedDatetime)
```


## Liens complémentaires

- [https://syl1.gitbook.io/julia-language-a-concise-tutorial/useful-packages/dataframes](https://syl1.gitbook.io/julia-language-a-concise-tutorial/useful-packages/dataframes)
- [https://dataframes.juliadata.org/stable/man/working_with_dataframes/](https://dataframes.juliadata.org/stable/man/working_with_dataframes)
- [https://dataframes.juliadata.org/v0.17.0/lib/functions.html](https://dataframes.juliadata.org/v0.17.0/lib/functions.html)
- [https://dataframes.juliadata.org/stable/man/missing/](https://dataframes.juliadata.org/stable/man/missing/)
- [https://jcharistech.wordpress.com/julia-dataframes-cheat-sheets/](https://jcharistech.wordpress.com/julia-dataframes-cheat-sheets/)
