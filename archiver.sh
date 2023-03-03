#!/bin/bash
###################################################################################################
#                                                                                                 #
#   Script fait pour l'archivage des messages de Mattermost afin de ne pas surcharger le disque   #
#             Il est inspiré de https://github.com/aljazceru/mattermost-retention                 #
#                                                                                                 #
#   Pour me contacter en cas de question : samuel.stef@pm.me                                      #
#                                          @Sam_Leetfus sur Telegram                              #
#                                                                                                 #   
#   Aucune license n'a été prévu pour ce morceau de code...                                       #
#                                                                                                 #
###################################################################################################
#
#
# TODO Commande pour archiver 1 mois : let i=0; let j=1; while [ $i -lt 30 ]; do bash archiver.sh $i $j; let i="$i+1"; let j="$j+1"; done
#
#
# Configuration des variables
# Pas besoin de préciser le mot de passe car on utilise psql avec docker
# Utilisation : bash archiver.sh [debut_retention] [fin_retention]
if [[ $1 == "" || $2 == "" ]]; then
    echo -e "\033[0;31m[-]\033[0m Utilisation : bash archiver.sh [debut_retention] [fin_retention]";
    exit 1;
fi
user="mmuser";                                                                # Nom d'utilisateur utilisé pour la base de données
db="mattermost";                                                              # Nom de la base de donnée du volume postgresql
hote="mattermost_postgres_1";                                                 # Nom du conteneur Docker
debut_de_retention="$1";                                                      # La rétention commence il y a $debut_de_retention jours  => | Toutes les données comprises entre ces deux jours
fin_de_retention="$2";                                                        # La rétention se termine il y a $fin_de_retention jours  => | seront sauvegardées dans les archives
jour_de_supression="90";                                                      # Les données comprises avant il y a $jour_de_supression seront supprimées
chemin_volume="/opt/Mattermost/volumes/app/mattermost/data";                  # Chemin où sont entreposées les données actuelles de Mattermost
tmp="/tmp/mattermost-paths.list.txt";                                         # Fichier temporaire contenant les adresses de tous les fichiers à supprimer
bdir="/opt/MattermostBackup";                                                 # Chemin où se trouve le script actuel et son algorithme de tri en python

cd "$bdir";


# Calcul des dates exactes en fonction des valeurs chosies plus haut
tsdeb=$(date  --date="$debut_de_retention day ago 0"  "+%s%3N");
tsfin=$(date  --date="$fin_de_retention day ago 0"  "+%s%3N");
tssup=$(date  --date="$jour_de_supression day ago 0"  "+%s%3N");
echo -e "\033[0;32m[+]\033[0m Les messages compris entre le $(date  --date="$debut_de_retention day ago 0" +"%d/%m/%Y à %H:%M") et le $(date  --date="$fin_de_retention day ago 0" +"%d/%m/%Y à %H:%M") seront archivés.";
echo -e "\033[0;32m[+]\033[0m Les messages postés avant le $(date  --date="$jour_de_supression day ago 0" +"%d/%m/%Y à %H:%M") seront supprimés définitivement !";


# Récupération des données des messages ainsi que des fichiers attachés
docker exec -it $hote psql -P pager=off -U $user $db -t -c "select path from fileinfo where createat > $tsfin and createat < $tsdeb;" > $bdir/files-list.txt;
docker exec -it $hote psql -P pager=off -U $user $db -t -c "copy (select id, name from teams) to stdout csv;" > $bdir/equipes.csv;
docker exec -it $hote psql -P pager=off -U $user $db -t -c "copy (select id, teamid, name from channels) to stdout csv;" > $bdir/canaux.csv;
docker exec -it $hote psql -P pager=off -U $user $db -t -c "copy (select id, createat, userid, channelid, message, fileids from posts where createat > $tsfin and createat < $tsdeb) to stdout csv;" > $bdir/messages.csv;
docker exec -it $hote psql -P pager=off -U $user $db -t -c "copy (select id, username, firstname, lastname from users) to stdout csv;" > $bdir/users.csv;


# Traitement des données obtenues
python3 $bdir/trier.py > $bdir/flux.txt;
rm $bdir/canaux.csv $bdir/equipes.csv $bdir/messages.csv $bdir/users.csv;
mkdir $bdir/PJ;
sed -i '$ d' $bdir/files-list.txt;
while read f; do
    f=$chemin_volume/$f;
    f=$(echo $f | tr -d '\r');
    cp "$f" $bdir/PJ/;
    echo -e "\033[0;34m[*]\033[0m ${f:162} copié !";
done < $bdir/files-list.txt;
rm $bdir/files-list.txt;


# Archivage du rassemblement opéré
let date_vrai="$debut_de_retention-1";
nom="archive_du_"`date --date="$date_vrai day ago 0" +"%d-%m-%Y"`;
mkdir $bdir/$nom;
mv $bdir/PJ $bdir/$nom;
mv $bdir/flux.txt $bdir/$nom;
tar -cf $bdir/$nom.tar $nom > /dev/null 2>&1;
bzip2 $bdir/$nom.tar;
rm -r $bdir/$nom;
echo -e "\033[0;32m[+]\033[0m Archivage dans $nom.tar.bz2";


# Déplacement de l'archive créée dans le bon dossier
dossier_annee="Archive_"`date --date="$debut_de_retention day ago 0" +"%Y"`
dossier_mois=`date --date="$debut_de_retention day ago" +"%B"`
if [[ ! -d $dossier_annee/$dossier_mois ]]; then
    mkdir -p $bdir/$dossier_annee/$dossier_mois;
fi
mv $bdir/$nom.tar.bz2 $bdir/$dossier_annee/$dossier_mois/;
echo -e "\033[0;32m[+]\033[0m Archive déplacé dans $bdir/$dossier_annee/$dossier_mois/ !";


# Constitution de la liste des fichiers devant être supprimés
docker exec -it $hote psql -P pager=off -U $user $db -t -c "select path from fileinfo where createat < $tssup;" > $tmp;
docker exec -it $hote psql -P pager=off -U $user $db -t -c "select thumbnailpath from fileinfo where createat < $tssup;" >> $tmp;
docker exec -it $hote psql -P pager=off -U $user $db -t -c "select previewpath from fileinfo where createat < $tssup;" >> $tmp;


#############################################
#                                           #
# TODO : Essayer la partie suivante du code #
#                                           #
#############################################
exit 0; # FIXME : Ligne à supprimer

# Suppression des messages dans la base de données PostgreSQL
docker exec -it $hote psql -P pager=off -U $user $db -t -c "delete from posts where createat < $tssup;"
docker exec -it $hote psql -P pager=off -U $user $db -t -c "delete from fileinfo where createat < $tssup;"
echo -e "\033[0;32m[+]\033[0m Messages plus vieux que le $(date  --date="$jour_de_supression day ago") supprimés !"


# Suppression des fichiers de /opt/Mattermost/mattermost-docker/volumes/app/mattermost/data/
# On vient lire la liste effectuée dans $tmp
while read -r fp; do
    if [ -n "$fp" ]; then
        echo "$chemin_volume""$fp";
        shred -u "$chemin_volume""$fp";
    fi
done < $tmp
echo -e "\033[0;32m[+]\033[0m Fichiers plus vieux que le $(date  --date="$jour_de_supression day ago") supprimés !"


# Suppression des derniers fichiers et dossiers inutiles
rm $tmp
find $chemin_volume -type d -empty -delete
exit 0;
