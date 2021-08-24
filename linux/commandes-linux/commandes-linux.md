---
title: "Quelques commandes utiles sous Linux"
date: "2017-04-12T13:23:14-04:00"
updated: "2021-02-16T13:23:14-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [Linux, commandes, Bash]
abstract: "Quelques commandes utiles sous Linux"
---


Tester son débit
```console
iperf3 -R -c ping.online.net -p 5206 -P5
wget http://test-debit.free.fr/10485760.rnd -O /dev/null
```

Détacher un programme dans un terminal virtuel 
```console
screen -d -m -S Telechargement wget -i liste.txt
CTRL+A+D
```

Lister les terminaux virtuels
```console
screen -ls
```

Se connecter à un terminal virtuel
```console
screen -r Telechargement
```

Afficher les chaînes de caractère d'un fichier binaire
```console
strings file.bin
```

Récupérer des fichiers depuis une image disque (contenus dans un autre fichier)
```console
binwalk file.bin -e --dd=".*" --raw="ID3"
foremost -dv -i file.img
scalpel file.img -o output
bulk_extractor file.img -o out_folder
```

Trouver fichiers en double
```console
find Pictures/  -type f -exec md5sum '{}' ';' | sort | uniq --all-repeated=separate -w 15 > dupes.txt
fdupes -rSm Pictures/
```

Top amélioré
```console
htop
```

Tentatives de connexions SSH
```console
grep "Invalid user" /var/log/auth.log | awk 'BEGIN { FS=" " } { print $8}' | sort | uniq --count | sort --reverse --numeric-sort
```

Programme le plus consommateur de RAM puis CPU
```console
dstat -g -l -m -s --top-mem
dstat -c -y -l --proc-count --top-cpu
```

Sortie CSV pour dstat
```console
dstat éoutput /tmp/sampleoutput.csv -cdn
```

Coloration de texte en console
```console
echo "Mon texte" | lolcat
```

Restauration TSM
```console
dsmc restore -pick -inactive "/data/mon_fichier.gz" /home/dossier_restauration/
```

Lister les différences entre deux arborescences (local ou distant)
```console
rsync -av --dry-run /source serveur:/dest
```

Ajouter des librairies .so
```console
ldconfig -p | grep "libicuuc.so.32"
echo "/usr/local/BerkeleyDB/lib" >> /etc/ld.so.conf
ldconfig
```

Afficher les caractéristiques wifi en temps réel
```console
wavemon
```

Surveiller la qualité de liaison wifi:
```console
watch -n 1 cat /proc/net/wireless
```

Afficher la date du dernier accés/modification
```console
stat -c "last access: %x last modification:%y" mon_fichier
```

Ajouter un utilisateur existant à un groupe supplémentaire existant
```console
usermod -a -G groupe utilisateur
```

Serveur web d'urgence avec Netcat
```console
while true; do nc -l -p 8080 < index.html; done
while true; do echo "< pre>$(ps aux)< /pre>" | nc -l -p 8080; done
```

Arborescence des processus
```console
pstree -p | grep httpd
```

Lancer une trace
```console
strace -f -o trace.txt /etc/rc.d/init.d/httpd start
```

Benchmark HTTP
```console
httperf --hog --server=10.1.1.1 --wsess=2000,10,2 --rate 300 --timeout 5
ab -kc 500 -n 10000 http://10.1.1.1/
siege -b -t60S  http://example.com
```

Calcule le quantiéme d'une date donnée (Mois/Jour/Année)
```console
date --date '03/23/2012' +%j
```

Calculer le quantiéme du jour dans l'année (aujourd'hui)
```console
date "+%j"
```

Affecter un dossier /home/toto é l'utilisateur toto (doit exister dans /etc/passwd)
```console
usermod -d /home/toto toto
```

Afficher l'id du groupe toto
```console
id -g toto
```

Afficher l'id de l'utilisateur toto
```console
id -u toto
```

Monitoring nmon (resultat dans fichier <hostname>_date_time.nmon)
```console
#capture toutes les 30 secondes 120 fois; excel généré avec nmon_analyzer
nmon -fT -s 30 -c 120
dstat -nN eth0
```

Gestion des fichier RPM, installation
```console
rpm -ivh paquet.rpm
```

Désinstallation
```console
rpm -e nom_paquet
```

Vérifier si installé
```console
rpm -ql nom_paquet
```

Trouver les liens symboliques
```console
find /home/ -type l
```

Opération sur un critére de fichiers
```console
find /home/exploit/ * -type f -exec du -h {} \;
find /data/entrepot/USER/ -name *.sas7bdat -not -user admpap -type f -mtime +100 -exec gzip -f {} \;
```

TreeSize Linux
```console
du -h --max-depth=2
```

Affiche l'arborescence (dossiers seulements)
```console
tree -d /data
```

Lister les connexions réseau avec résolution des PID/Programme
```console
netstat -pantu
```

Lister les connexions réseau avec lsof
```console
lsof -ni
lsof -ni tcp:22
lsof -ni 'udp@192.168.66.66:123'
```

Recherche les occurences de "meta" dans tous les fichiers php de /var/www/drupal
```console
find /var/www/drupal/ -name "*.php" -exec grep -H meta {} \;
find /var/www/drupal/ -name "*.php" -print | xargs grep "meta"
```

Recherche récursive d'un motif et retourne le fichier
```console
grep -rl 'chose' ./
```

Recherche récursive d'un motif et le remplacer
```console
grep -rl 'chose' ./ | xargs sed -i 's/chose/truc/g'
```

Cherche les fichiers plus lourd que 500Mo et moins d'1 Go
```console
find / -type f -size +500M -size -1G
```

Rechercher les fichiers plus gros q'une certaine limite
```console
find / -type f -size +100000k -printf "%p %s\n"
```

Perl shell interactif (débug)
```console
perl -d -e 1
```

Créer plusieurs dossiers simultanément
```console
mkdir -p MyRepo/{i386,noarch,i686,SRPMS}
```

Compresser un fichier en fichier .gz
```console
gzip fichier
```

Compresser fichier en fichier .gz avec écrasement et conserve la copie originale
```console
gzip  -cf  fichier
```

Décompresser fichier.gz
```console
gzip -d fichier.gz
```

Lien symbolique
```console
ln -s fichier_a_lier lien_symbolique
```

Rassembler plusieurs fichiers en une seule archive sans compression
```console
tar cvf  fichier.tar fichiers
```

Liste le contenu d'un fichier tar
```console
tar tvf  fichier.tar
```

Extraire le contenu d'un fichier tar
```console
tar oxvf  fichier.tar
```

Extraire le contenu d'un fichier tgz
```console
tar zxvf fichier.tgz
```

Augmenter la priortié d'un processus
```console
renice 10 6969
```

Sauvegarder en PDF le man d'une commande
```console
man -t apt | ps2pdf - apt.pdf
```

Dupliquer l'installation de package RPM d'une machine à une autre
```console
ssh root@remote.host "rpm -qa" | xargs yum -y install
```

Ajout une entête sur un fichier PDF
```console
echo "This text gets stamped on the top of the pdf pages." | enscript -B -f Courier-Bold16 -o- | ps2pdf - | pdftk input.pdf stamp - output output.pdf
```

Affiche le nombre de connexion à une base MySQL
```console
mysql -u root -p -BNe "select host,count(host) from processlist group by host;" information_schema
```

Créer une archive locale d'un dossier sur une machine distante
```console
ssh user@host "tar -zcf - /path/to/dir" > dir.tar.gz
```

Affiche un résumé des logs SSH
```console
ssh -t remotebox "tail -f /var/log/remote.log"
```

Affiche un diagramme des utilisateur/groupes
```console
awk 'BEGIN{FS=":"; print "digraph{"}{split($4, a, ","); for (i in a) printf "\"%s\" [shape=box]\n\"%s\" -> \"%s\"\n", $1, a[i], $1}END{print "}"}' /etc/group|display
```

Affiche un graphique des dépendances des modules du noyau
```console
lsmod | perl -e 'print "digraph \"lsmod\" {";<>;while(<>){@_=split/\s+/; print "\"$_[0]\" -> \"$_\"\n" for split/,/,$_[3]}print "}"' | dot -Tpng | display -
```

Génére un mot de passe fort
```console
read -s pass; echo $pass | md5sum | base64 | cut -c -16
```

Limite l'utilisation du CPU pour un processus
```console
cpulimit -p pid -l 50
```
