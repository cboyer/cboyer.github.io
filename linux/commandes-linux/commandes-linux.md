---
title: "Commandes Linux en vrac"
date: "2017-04-12T13:23:14-04:00"
updated: "2025-12-24T12:16:14+01:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [Linux, commandes, Bash]
abstract: "Quelques commandes utiles sous Linux."
---


Statistiques CPU lors d'exécution d'un programme
```
perf stat -d ./test
```

Rapport d'appels (perf.data) lors de l'exécution d'un programme
```
perf record --call-graph dwarf ./test
perf report -g
```

Tests de débit réseau
```
iperf3 -R -c ping.online.net -p 5206 -P5
wget http://test-debit.free.fr/10485760.rnd -O /dev/null
```

Détacher un programme dans un terminal virtuel 
```
screen -d -m -S Telechargement wget -i liste.txt
CTRL+A+D
```

Lister les terminaux virtuels
```
screen -ls
```

Se connecter à un terminal virtuel
```
screen -r Telechargement
```

Télécharger la bande son d'une vidéo Youtube au format MP3
```
yt-dlp -x --audio-format mp3 --embed-thumbnail --audio-quality 0 "LIEN YOUTUBE"
```

Modifier les métadonnées d'un fichier PDF (titre auteur, etc.)
```
exiftool -Title="Nouveau titre" -Author="Auteur" -Subject="Blabla" fichier.pdf
```

Combiner des fichiers PDF
```
pdftk document1 document2 document3 cat output final.pdf
```

Découper une séquence en lots: 5 éléments par ligne
```
seq 20  | xargs -n 5
```

Découper une séquence en intervalles: 5 intervalles, un par ligne
```
seq 20  | xargs -n 5 | awk '{print $1 "," $NF}'
```

Afficher les chaînes de caractère d'un fichier binaire
```
strings file.bin
```

Récupérer des fichiers depuis une image disque (contenus dans un autre fichier)
```
binwalk file.bin -e --dd=".*" --raw="ID3"
foremost -dv -i file.img
scalpel file.img -o output
bulk_extractor file.img -o out_folder
```

Top amélioré
```
htop
```

Tentatives de connexions SSH
```
grep "Invalid user" /var/log/auth.log | awk 'BEGIN { FS=" " } { print $8}' | sort | uniq --count | sort --reverse --numeric-sort
```

Programme le plus consommateur de RAM puis CPU
```
dstat -g -l -m -s --top-mem
dstat -c -y -l --proc-count --top-cpu
```

Sortie CSV pour dstat
```
dstat -output /tmp/sampleoutput.csv -cdn
```

Coloration de texte en console
```
echo "Mon texte" | lolcat
```

Restauration TSM
```
dsmc restore -pick -inactive "/data/mon_fichier.gz" /home/dossier_restauration/
```

Lister les différences entre deux arborescences (local ou distant)
```
rsync -av --dry-run /source serveur:/dest
```

Ajouter des librairies .so
```
ldconfig -p | grep "libicuuc.so.32"
echo "/usr/local/BerkeleyDB/lib" >> /etc/ld.so.conf
ldconfig
```

Afficher les caractéristiques wifi en temps réel
```
wavemon
```

Surveiller la qualité de liaison wifi:
```
watch -n 1 cat /proc/net/wireless
```

Afficher la date du dernier accés/modification
```
stat -c "last access: %x last modification:%y" mon_fichier
```

Ajouter un utilisateur existant à un groupe supplémentaire existant
```
usermod -a -G groupe utilisateur
```

Serveur web pour servir le fichier du dossier courant avec Python
```
python3 -m http.server 9000
```

Serveur web d'urgence avec Netcat
```
while true; do nc -l -p 8080 < index.html; done
while true; do echo "< pre>$(ps aux)< /pre>" | nc -l -p 8080; done
```

Arborescence des processus
```
pstree -p | grep httpd
```

Lancer une trace
```
strace -f -o trace.txt /etc/rc.d/init.d/httpd start
```

Benchmark HTTP
```
httperf --hog --server=10.1.1.1 --wsess=2000,10,2 --rate 300 --timeout 5
ab -kc 500 -n 10000 http://10.1.1.1/
siege -b -t60S  http://example.com
```

Calcule le quantiéme d'une date donnée (Mois/Jour/Année)
```
date --date '03/23/2012' +%j
```

Calculer le quantiéme du jour dans l'année (aujourd'hui)
```
date "+%j"
```

Affecter un dossier /home/toto à l'utilisateur toto (doit exister dans /etc/passwd)
```
usermod -d /home/toto toto
```

Afficher l'id du groupe toto
```
id -g toto
```

Afficher l'id de l'utilisateur toto
```
id -u toto
```

Monitoring nmon (resultats dans le fichier `hostname_date_time.nmon`)
```
#capture toutes les 30 secondes 120 fois; excel généré avec nmon_analyzer
nmon -fT -s 30 -c 120
dstat -nN eth0
```

Gestion des fichier RPM, installation
```
rpm -ivh paquet.rpm
```

Désinstallation
```
rpm -e nom_paquet
```

Vérifier si installé
```
rpm -ql nom_paquet
```

TreeSize Linux
```
du -h --max-depth=2
```

Affiche l'arborescence (dossiers seulements)
```
tree -d /data
```

Lister les connexions réseau avec résolution des PID/Programme
```
netstat -pantu
```

Lister les connexions réseau avec lsof
```
lsof -ni
lsof -ni tcp:22
lsof -ni 'udp@192.168.66.66:123'
```

Trouver les liens symboliques
```
find /home/ -type l
```

Trouver fichiers en double
```
find Pictures/  -type f -exec md5sum '{}' ';' | sort | uniq --all-repeated=separate -w 15 > dupes.txt
fdupes -rSm Pictures/
```

Recherche les occurences de "meta" dans tous les fichiers php de /var/www/drupal
```
find /var/www/drupal/ -name "*.php" -exec grep -H meta {} \;
find /var/www/drupal/ -type f -print0 | xargs -0 grep -Ei "*meta*"
```

Cherche les fichiers plus lourd que 500Mo et moins d'1 Go
```
find / -type f -size +500M -size -1G
```

Opération sur des critères de fichiers
```
find /home/exploit/ * -type f -exec du -h {} \;
find /data/entrepot/USER/ -name *.sas7bdat -not -user admpap -type f -mtime +100 -exec gzip -f {} \;
```

Recherche récursive d'un motif et retourne le fichier
```
grep -rl 'chose' ./
```

Recherche récursive d'un motif et le remplacer
```
grep -rl 'chose' ./ | xargs sed -i 's/chose/truc/g'
```

Rechercher les fichiers plus gros q'une certaine limite
```
find / -type f -size +100000k -printf "%p %s\n"
```

Perl shell interactif (débug)
```
perl -d -e 1
```

Créer plusieurs dossiers simultanément
```
mkdir -p MyRepo/{i386,noarch,i686,SRPMS}
```

Compresser un fichier en fichier .gz
```
gzip fichier
```

Compresser fichier en fichier .gz avec écrasement et conserve la copie originale
```
gzip  -cf  fichier
```

Décompresser fichier.gz
```
gzip -d fichier.gz
```

Lien symbolique
```
ln -s fichier_a_lier lien_symbolique
```

Rassembler plusieurs fichiers en une seule archive sans compression
```
tar cvf  fichier.tar fichiers
```

Liste le contenu d'un fichier tar
```
tar tvf  fichier.tar
```

Extraire le contenu d'un fichier tar
```
tar oxvf  fichier.tar
```

Extraire le contenu d'un fichier tgz
```
tar zxvf fichier.tgz
```

Augmenter la priortié d'un processus
```
renice 10 6969
```

Sauvegarder en PDF le man d'une commande
```
man -t apt | ps2pdf - apt.pdf
```

Dupliquer l'installation de package RPM d'une machine à une autre
```
ssh root@remote.host "rpm -qa" | xargs yum -y install
```

Ajout une entête sur un fichier PDF
```
echo "This text gets stamped on the top of the pdf pages." | enscript -B -f Courier-Bold16 -o- | ps2pdf - | pdftk input.pdf stamp - output output.pdf
```

Affiche le nombre de connexion à une base MySQL
```
mysql -u root -p -BNe "select host,count(host) from processlist group by host;" information_schema
```

Créer une archive locale d'un dossier sur une machine distante
```
ssh user@host "tar -zcf - /path/to/dir" > dir.tar.gz
```

Affiche un résumé des logs SSH
```
ssh -t remotebox "tail -f /var/log/remote.log"
```

Affiche un diagramme des utilisateur/groupes
```
awk 'BEGIN{FS=":"; print "digraph{"}{split($4, a, ","); for (i in a) printf "\"%s\" [shape=box]\n\"%s\" -> \"%s\"\n", $1, a[i], $1}END{print "}"}' /etc/group|display
```

Affiche un graphique des dépendances des modules du noyau
```
lsmod | perl -e 'print "digraph \"lsmod\" {";<>;while(<>){@_=split/\s+/; print "\"$_[0]\" -> \"$_\"\n" for split/,/,$_[3]}print "}"' | dot -Tpng | display -
```

Génére un mot de passe fort
```
read -s pass; echo $pass | md5sum | base64 | cut -c -16
```

Limite l'utilisation du CPU pour un processus
```
cpulimit -p pid -l 50
```
