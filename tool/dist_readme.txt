KLR TECH - GESTION
Version de test
===========================================================

INSTALLATION
------------
1. Faire un clic droit sur le fichier ZIP > "Extraire tout..."
   Choisir un dossier, par exemple le Bureau ou Documents.

   IMPORTANT : ne pas lancer l'application depuis l'interieur du ZIP.
   Il faut d'abord l'extraire.

2. Ouvrir le dossier extrait et double-cliquer sur :
   KLR TECH - Gestion.exe

3. Au premier lancement, Windows peut afficher un ecran bleu :
   "Windows a protege votre ordinateur"

   C'est normal : l'application n'est pas encore signee numeriquement.
   Cliquer sur "Informations complementaires", puis sur "Executer quand meme".


CONNEXION
---------
   Identifiant  : admin
   Mot de passe : admin

Ces acces peuvent etre modifies dans l'application :
   Parametres > Securite


PREMIER DEMARRAGE
-----------------
L'application demarre avec des donnees d'exemple (clients et documents
fictifs) pour permettre de tester immediatement.

Pour repartir de zero :
   Parametres > Donnees > Reinitialiser les donnees


ENREGISTREMENT DES DONNEES
--------------------------
Les donnees sont enregistrees automatiquement sur cet ordinateur, dans :
   %APPDATA%\ci.klrtech\klr_tech_app\klr_data.json

Elles restent locales a la machine : rien n'est envoye sur internet.
Pour faire une sauvegarde, copier ce fichier.


CONFIGURATION REQUISE
---------------------
   Windows 10 ou 11, 64 bits


PROBLEME AU LANCEMENT ?
-----------------------
Si un message signale un fichier DLL manquant, verifier que tous les
fichiers du dossier ont bien ete extraits (l'application a besoin du
dossier "data" et des fichiers .dll places a cote de l'executable).
