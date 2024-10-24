---
title: "Chargement de fichiers Parquet vers PostgreSQL avec Python"
date: "2022-07-11T19:34:12-04:00"
updated: "2022-07-11T19:34:12-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Développement"
keywords: [PostgreSQL, Parquet, Python, Postgres, Psycopg, SQLAlchemy, copy]
abstract: "Chargement de fichiers Parquet vers PostgreSQL avec Python."
---

Le format libre Parquet présente certaines caractéristiques intéressantes pour le stockage de données optimisé (notamment avec la compression ZSTD et le chiffrement).
Beaucoup de langages et de solutions comme Spark prennent en charge ces fichiers mais pas toutes. Pour rendre les données qu'ils contiennent disponibles à d'autres plateforme, il peut être necéssaire de charger ces données dans un SGBD standard qui sera intérrogé via SQL.

Nous utiliserons ici Python et PostgreSQL avec les librairies Psycopg (Psycopg2 via SQLAlchemy) et pyArrow.
La technique consiste à utiliser le fonction `COPY` de PostgreSQL qui utilise le format CSV.

## Avec Psycopg2 via SQLAlchemy

SQLAlchemy ne support que Psycopg dans sa version 2 pour le moment.
La table de destination "importparquet" doit être créée au préalable avec les mêmes colonnes que le fichier Parquet.

```Python
import sqlalchemy, pyarrow.parquet, pyarrow.csv, io

# Connection à PostgreSQL
engine = sqlalchemy.create_engine("postgresql://login:mot2passe@serveur:5432/Base")
connection = engine.raw_connection()

# Lecture du fichier Parquet et conversion en CSV dans un tampon
buf = io.BytesIO()
table = pyarrow.parquet.read_table('fichier01.parquet')
pyarrow.csv.write_csv(table, buf, pyarrow.csv.WriteOptions(include_header=False, delimiter=','))
buf.seek(0)

# Lancement de COPY
cursor = connection.cursor()
cursor.copy_expert("""COPY "importparquet" ({cols}) FROM stdin WITH (FORMAT CSV)""".format(cols=','.join(table.column_names)), buf)
connection.commit()

# Fermeture des tampons et de la connexion
buf.close()
cursor.close()
connection.close()
engine.dispose()
```

## Avec Psycopg3
```Python
import psycopg, pyarrow.parquet, pyarrow.csv, io

connection = psycopg.connect(host='serveur', port='5432', dbname='base', user='postgres', password='postgres')

buf = io.BytesIO()
table = pyarrow.parquet.read_table('fichier01.parquet')
pyarrow.csv.write_csv(table, buf, pyarrow.csv.WriteOptions(include_header=False, delimiter=','))
buf.seek(0)

with connection.cursor().copy("""COPY "importparquet" ({cols}) FROM STDIN WITH (FORMAT CSV)""".format(cols=','.join(table.column_names))) as copy:
    copy.write(buf.getvalue())

connection.commit()
connection.close()
buf.close()
```

## Modifier les données depuis le tampon

Le caractère nul `\0` qui peut être stocké dans un fichier Parquet ne peut l'être dans PostgreSQL. Une ligne vide contenant uniquement le caractère `\n` provoquera une erreur lors de la copie.
Pour filtrer ces caractères, il suffit de copier le contenu de `buf` vers un nouveau tampon `buf_clean` qui sera utilisé avec `COPY`.
Cette technique n'est pas nécessairement optimale car elle duplique les données en mémoire.
```Python
buf_clean = io.BytesIO()
buf_clean.seek(0)
for line in buf:
    if b'\0' in line:
        buf_clean.write(line.replace(b'\0', b''))
    elif line != b'\n':
        buf_clean.write(line)

buf.close()
buf_clean.seek(0)
```
