#!/bin/python3
#####################################################################################
#                                                                                   #
#   Script de réarangement des données servant à une meilleure lecture du rendu     #
#       Ce script est supposé appelé par un script bash lisant sa sortie            #
#                                                                                   #
#   Pour me contacter en cas de question : samuel.stef@pm.me                        #
#                                          @Sam_Leetfus sur Telegram                #
#                                                                                   #   
#   Aucune license n'a été prévu pour ce morceau de code...                         #
#                                                                                   #
#####################################################################################
from datetime import datetime

conversations = {0 : {}}

# Gestion des équipes sous forme de dictionnaire
#   i[0] : id de l'équipe
#   i[1] : nom de l'équipe
f = open("equipes.csv")
equipes = {0 : "Conversations privées"}
for i in f.read().split('\n')[:-1]:
    i = i.split(',')
    equipes[i[0]] = i[1]
    conversations[i[0]] = {}
f.close()


# Gestion des cannaux sous forme de dictionnaire
#   i[0] : id du canal
#   i[1] : id de l'équipe du canal
#   i[2] : nom du canal
f = open("canaux.csv")
canaux = {}
for i in f.read().split('\n')[:-1]:
    i = i.split(',')
    if i[1] == '""':
        i[1] = 0
    canaux[i[0]] = [i[0], i[1], i[2]]
    conversations[i[1]][i[0]] = []
f.close()


# Gestion des utilisateurs sous forme de dictionnaire
#   i[0] : id de l'utilisateur
#   i[1] : pseudo (@user)
#   i[2] : prénom si renseigné, sinon i[2] = ""
#   i[3] : nom si renseigné, sinon i[3] = ""
f = open("users.csv")
users = {}
for i in f.read().split('\n')[:-1]:
    i = i.split(',')
    if i[3] == '""' and not i[2] == '""':
        nom = i[2]
    elif not i[2] == '""' and not i[3] == '""':
        nom = i[2] + " " + i[3]
    else:
        nom = i[1]
    users[i[0]] = nom
f.close()


# Gestion des messages sous forme de chaînes de caractères
#   i[0] : id du message
#   i[1] : timestamp unix du message
#   i[2] : id de l'utilisateur ayant posté
#   i[3] : id du canal dans lequel le message est posté
#   i[4] : contenu textuel du message
f = open("messages.csv")
for i in f.read().split(']\n')[:-1]:

    # Isolation du contenu brut du message
    i = i + "]"
    i = i.split(',')
    if len(i) > 6:
        i[4] = "".join(i[4:-1]).replace('"', ' ')

    # Isolation d'éventuelles pièces jointes
    if "[  " in i[4] and "  ]" in i[4]:
        i[4] = i[4].split("\n")
        i[4][1] = "\n".join(i[4][1:])[91:]
        i[4][0] = "[PJ] id : " + ", ".join(i[0].split("    "))
        i[4] = "\n".join(i[4])
    
    # Création de la balise de temps pour le message avec le module timestamp
    try:
        ts = int(i[1][:-3])
        d = datetime.utcfromtimestamp(ts).strftime('%d-%m-%Y %H:%M:%S')
    except ValueError:
        d = "?"

    # emplacement = [id du canal, id de l'équipe, nom du canal]
    emplacement = canaux[i[3]]
    contenu = "[" + d + "] " + users[i[2]] + " : " + i[4]
    
    # Marquage des contenus privés afin de rendre le rendu plus clair
    if emplacement[1] == 0:
        if "__" in emplacement[2]:
            canaux[i[3]] = [emplacement[0], 0, users[i[2]] + " - ?"]
        elif not users[i[2]] in canaux[i[3]][2]:
            canaux[i[3]][2] = canaux[i[3]][2][:-1] + users[i[2]]
        emplacement = canaux[i[3]]
    
    # Ajout du contenu final au dictionnaire des conversations
    conversations[emplacement[1]][i[3]].append(contenu)
f.close()


# Impression à la sortie standard de manière hierarchisée
for i, j in conversations.items():
    print("[E]", equipes[i], ":")
    for k, v in j.items():
        if len(v) == 0:
            continue
        print("\t[C]", canaux[k][2], ":")
        for l in v:
            print("\t\t", l.replace("\n", "\n\t\t" + " " * (l.index(" : ") + 4)))
