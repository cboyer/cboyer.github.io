---
title: "Correspondance approximative (fuzzy matching) avec R"
date: "2022-02-03T17:38:04-05:00"
updated: "2022-02-03T17:38:04-05:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [R, fuzzy matching, recherche approximative, levenshtein, stringdistmatrix, adist]
abstract: "Déterminer des correspondances approximatives entre plusieurs chaînes de caractères avec R."
---

On considère deux ensembles de données `x` et `y` pour lesquels nous cherchons à établir des correspondances selon une de leur colonne tout en tolérant une certaine approximation.
```R
x <- data.frame(id = 10:13, name = c("jouet", "arbre", "fruit", "baton"))
y <- data.frame(id = 1:3, name = c("jouer", "arbuste", "bateau"))
```

## Calcul des distances de Levenshtein
Pour déterminer une éventuelle correspondance nous allons être amené à comparer les colonnes `name` entre elles. La liste de ces comparaisons peut être obtenue avec `expand.grid(x$name , y$name)`:
```Text
    Var1    Var2
1  jouet   jouer
2  arbre   jouer
3  fruit   jouer
4  baton   jouer
5  jouet arbuste
6  arbre arbuste
7  fruit arbuste
8  baton arbuste
9  jouet  bateau
10 arbre  bateau
11 fruit  bateau
12 baton  bateau
```

Chaque comparaison sera effectuée en calculant la distance de Levenshtein qui caractérise le nombre d'opération (insertion, suppression, substitution) pour que les deux chaînes soient égales. La distance de Levenshtein constitue alors un indicateur de similitude entre deux chaîne de caractère: plus elle est faible plus les chaînes sont similaires, 0 impliquant une égalité stricte.
Pour calculer cette distance nous utiliserons la fonction `stringdistmatrix` de la librairie `stringdist`. 
`utils::adist` peut être une alternative mais elle offre moins d'options (méthodes et pondération) et est beaucoup moins performante car elle n'est pas multithreadée.
`stringdistmatrix()` est sensible à la casse, pour améliorer les chances d'obtenir des correspondances il peut être nécessaire de traiter les données des deux colonnes `x$name` et `y$name`, par exemple:

 - passage en minuscule avec `tolower(x$name)`
 - retrait des accents avec `iconv(x$name, to="ASCII//TRANSLIT")`
 - retrait des espaces en début/fin de chaîne avec `trimws(x$name)`
 - retrait des signes de ponctuation avec `gsub("[[:punct:]]+", "", x$name)`
 - remplacement des espaces multiples avec `gsub("\\s+", " ", x$name)`

```R
library(stringdist)
distances <- stringdistmatrix(x$name, y$name, method = 'lv')
```

```Text
         y ----------->
x        [,1] [,2] [,3]
|  [1,]    1    5    5
|  [2,]    5    3    5
|  [3,]    4    4    6
V  [4,]    5    6    3
```

La matrice retournée `distances` contient la distance entre les valeurs `x$name` et `y$name`. 
Les coordonnées de cette matrice sont les indices (positions) des valeur contenue respectivement dans les vecteurs `x$name` et `y$name` et également les numéros de ligne dans chacun des dataframes `x` et `y`.


## Matrice et coordonnées
Ainsi les coordonnées (2,3) contiennent la valeur 5 car `"arbre"` nécessite 5 opérations pour devenir `"bateau"`. Pour récupérer cette valeur:
```R
distances[cbind(2, 3)]
# [1] 5
```

R permet de récupérer des valeurs contenues dans une matrice en lui passant des coordonnées sous forme de matrice à deux colonnes dont une ligne forme une paire (x,y).
`cbind` permet de construire une matrice contenant les coordonnées avec deux valeurs ou deux vecteurs de même longueurs:

```R
cbind(c(1,2), c(3,4))

# Retourne les coordonnées (1,3) et (2,4) sous forme de matrice:
#      [,1] [,2]
# [1,]    1    3
# [2,]    2    4
```

## Filtrer les distances
Maintenant que nous possèdons toutes les distances, fixons notre seuil à 4 en récupérant les coordonnées des valeurs (distances de Levenshtein) de la matrice `distances` qui sont inférieures ou égales à 4:
```R
coord_correspondances <- which(distances <= 4, arr.ind = TRUE)

#        x   y
#      row col
# [1,]   1   1
# [2,]   3   1
# [3,]   2   2
# [4,]   3   2
# [5,]   4   3
```

C'est cette nouvelle matrice qui contient les coordonnées où `distances` contient une distance inférieure ou égale à 4. Pour l'exploiter et assembler les données dans un dataframe `results`:
```R
results <- x[coord_correspondances[, 1], ]
results$id_y <- y[coord_correspondances[, 2], ]$id
results$name_y <- y[coord_correspondances[, 2], ]$name
results$distance <- distances[coord_correspondances]

#     id  name id_y  name_y distance
# 1   10 jouet    1   jouer        1
# 3   12 fruit    1   jouer        4
# 2   11 arbre    2 arbuste        3
# 3.1 12 fruit    2 arbuste        4
# 4   13 baton    3  bateau        3
```

On utilise ici les colonnes de `coord_correspondances` pour récupérer des lignes respectivement depuis `x` et `y`. 
La colonne `distance` (distance de Levenshtein) indique également l'exactitude de la correspondance: plus elle est petite plus la correspondance est certaine (0 indiquant une égalité stricte).
Notons que R signale la duplication d'une ligne (3 et 3.1) car il y a plusieurs correspondances pour l'id 12.
