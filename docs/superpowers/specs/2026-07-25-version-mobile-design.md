# Version mobile de KLR TECH — Conception

**Date** : 25/07/2026
**Portée** : rendre toute l'application utilisable sur téléphone, et produire une
vraie application Android installable.

---

## 1. Objectif et cadrage

L'application est aujourd'hui conçue pour le bureau : sidebar permanente,
padding de 28 px, six tableaux dont la largeur minimale monte à 1020 px,
dialogues de largeur fixe, Kanban en glisser-déposer à la souris. Les cibles
compilées sont Windows et le web — il n'existe ni dossier `android/` ni
dossier `ios/`.

Cette version ajoute :

1. une mise en page téléphone pour **tous** les écrans conservés ;
2. le dossier `android/` et un APK vérifié sur émulateur ;
3. le pavé de signature au doigt, prévu de longue date pour le mobile ;
4. la correction du chemin d'enregistrement PDF, aujourd'hui cassé sur mobile.

**Hors périmètre** : compilation iOS (impossible depuis Windows — le dossier est
généré, jamais construit), refonte visuelle du bureau, toute notion de
multi-utilisateur.

---

## 2. Décision structurante : brancher sur la largeur, pas sur la plateforme

Un unique prédicat, ajouté à `lib/widgets/responsive.dart` :

```dart
/// Vrai sous 700 px de large : téléphone en portrait, ou fenêtre de bureau
/// réduite. Volontairement fondé sur la largeur et non sur la plateforme.
bool isPhone(BuildContext context) => MediaQuery.sizeOf(context).width < 700;
```

Trois conséquences voulues :

- l'application Windows en fenêtre étroite devient utilisable, gratuitement ;
- une tablette, ou un téléphone en paysage, garde la mise en page riche ;
- **tout se vérifie dans Chrome en redimensionnant la fenêtre**, sans démarrer
  l'émulateur à chaque itération.

Aucun écran n'est dupliqué. Chaque écran conserve un seul `build`, qui branche
localement là où c'est nécessaire. C'est ce qui garantit qu'une évolution
fonctionnelle future ne soit pas à écrire deux fois.

Le seuil de 700 px reprend celui déjà utilisé par `ResponsiveSplit`
(`breakpoint: 700` dans l'écran de création) — une seule valeur dans le projet.

---

## 3. Coquille applicative

`AppShell` (dans `lib/main.dart`) branche sur `isPhone` :

| Élément | Bureau (≥ 700) | Téléphone (< 700) |
|---|---|---|
| Navigation | `Sidebar` permanente | `BottomNavigationBar` + feuille « Plus » |
| Barre haute | `AppHeader` (56 px) | `AppBar` : logo, notifications, avatar |
| Recherche | champ visible | icône ouvrant un champ plein largeur |
| Padding page | `fromLTRB(28, 28, 28, 40)` | `fromLTRB(16, 16, 16, 24)` |

**Barre du bas** — cinq entrées : Bord · Docs · Clients · Suivi · Plus.

**Feuille « Plus »** — `showModalBottomSheet` : Gantt, Activités, Rapports,
Paramètres.

`NavScreen` et `AppState.navigate` ne changent pas : seul le rendu de la
navigation diffère. L'état de navigation reste unique et partagé.

Le padding de page est extrait en une constante partagée plutôt que répété dans
neuf écrans :

```dart
EdgeInsets pagePadding(BuildContext c) => isPhone(c)
    ? const EdgeInsets.fromLTRB(16, 16, 16, 24)
    : const EdgeInsets.fromLTRB(28, 28, 28, 40);
```

---

## 4. Écrans retirés sur téléphone

**Projets (Kanban)** est masqué sous 700 px : quatre colonnes de 280 px en
glisser-déposer ne se transposent pas honnêtement au doigt, et le manager gère
ses projets au bureau. Décision utilisateur du 25/07/2026.

Conséquence : `NavScreen.projets` n'apparaît ni dans la barre du bas ni dans la
feuille « Plus » sur téléphone. Le code de l'écran reste intact pour le bureau —
rien n'est supprimé.

**Gantt est conservé** et déplacé dans la feuille « Plus ». C'est aujourd'hui le
seul point d'entrée de l'écran Projets qui disparaît sur mobile ; sans cette
entrée, Gantt deviendrait inatteignable. Le Gantt est en lecture seule et son
défilement horizontal convient à une frise chronologique.

Garde-fou : si l'état est déjà sur `NavScreen.projets` quand la fenêtre
rétrécit sous 700 px (redimensionnement du bureau, rotation), la coquille
redirige vers le tableau de bord plutôt que d'afficher un écran inaccessible.

---

## 5. Tableaux vers cartes

C'est le poste de travail le plus lourd. Six tableaux sont concernés :

| Écran | `minWidth` actuel | Fichier |
|---|---|---|
| Clients | 1020 | `clients_screen.dart` |
| Documents | 1020 | `documents_list_screen.dart` |
| Suivi — Engagements | 1000 | `suivi_screen.dart` |
| Suivi — Factures du mois | 820 | `suivi_screen.dart` |
| Suivi — Dépenses | 720 | `suivi_screen.dart` |
| Suivi — Règlements | 720 | `suivi_screen.dart` |

**Motif retenu** — chaque tableau gagne un widget carte à côté de sa ligne
existante, sélectionné par le prédicat :

```dart
isPhone(context) ? _ClientCard(client: c) : _ClientRow(client: c)
```

La ligne bureau reste **inchangée**, ce qui borne le risque de régression : les
tests de rendu existants continuent d'exercer exactement le même code.

Chaque carte porte : l'identifiant en tête (nom, numéro), les deux ou trois
champs qui comptent, le montant en évidence, et un `⋮` en coin ouvrant le même
`PopupMenuButton` que la ligne bureau. Les actions disponibles sont identiques —
aucune fonction n'est retirée du mobile.

Le Gantt garde `HScrollTable` (frise chronologique, décision utilisateur).
`document_create` garde son `HScrollTable(minWidth: 470)` pour les lignes
d'article : c'est une grille de saisie, pas une liste à lire.

---

## 6. Corrections tactiles

Ces points ne sont pas cosmétiques : ils cassent l'usage sur téléphone.

### 6.1 `AppTabBar` déborde

`lib/widgets/common.dart` construit un `Row` nu. Les cinq onglets du Suivi
(« Engagements, Comptabilité, Dîme, Tâches, Notes ») dépassent largement 360 px
et lèvent un overflow. Correction : envelopper dans un
`SingleChildScrollView(scrollDirection: Axis.horizontal)`. Concerne aussi
Paramètres (4 onglets) et Rapports (3 onglets).

### 6.2 Enregistrement PDF cassé sur Android

`PdfGenerator.saveWithDialog` ne branche que sur `kIsWeb`. Sur Android, il
appelle donc `FilePicker.platform.saveFile`, **que file_picker n'implémente pas
sur Android** ; l'exécution retombe alors sur un sélecteur de dossier puis sur
une supposition du dossier Téléchargements.

Correction : sur Android et iOS, passer par `Printing.sharePdf`, comme le web le
fait déjà — la feuille de partage système permet d'enregistrer dans Drive, les
Fichiers, ou d'envoyer par WhatsApp. C'est l'idiome mobile, et le paquet
`printing` est déjà une dépendance.

Le même correctif s'applique à l'export du rapport PDF (`rapports_screen`, second
appel à `saveFile` dans `pdf_generator.dart`).

### 6.3 Dialogues de largeur fixe

Huit dialogues fixent `SizedBox(width: 380 | 420)`, ce qui déborde sur 360 px.
Correction : `min(largeurVoulue, largeurÉcran − marges)`.

### 6.4 Cibles tactiles

Plusieurs `IconButton` descendent à `minWidth: 28, minHeight: 28`
(`documents_list_screen.dart:479`, aperçu de document). Portés à 48 px sur
téléphone, conformément aux règles d'accessibilité tactile.

Les `MouseRegion` et `Tooltip` existants sont **conservés** : sans souris ils ne
se déclenchent pas, et ils continuent de servir au bureau.

### 6.5 Points déjà corrects

Vérifié pendant l'exploration, aucun travail nécessaire :

- `LineAreaChart` possède déjà un `GestureDetector(onTapDown:)` en plus du
  survol — l'infobulle fonctionne au doigt ;
- `DocumentPreview` est en `AspectRatio` — l'A4 se met à l'échelle seul ;
- `StatGrid` et `ResponsiveSplit` retombent déjà en colonne ;
- `FileStore` fonctionne tel quel sur Android : `kIsWeb` est faux et
  `getApplicationSupportDirectory` y est supporté. **La persistance disque
  fonctionne sur mobile sans modification** — contrairement au web.

---

## 7. Création de proforma : aperçu sur demande

Sur téléphone, l'aperçu A4 ferait environ 330 px de large, avec du texte
composé en 8,5 pt — illisible.

Le formulaire occupe donc tout l'écran, et une barre d'actions basse porte
« Aperçu » et « Enregistrer ». « Aperçu » ouvre l'A4 en plein écran dans une
route dédiée, avec `InteractiveViewer` pour le zoom.

Le même `DocumentPreview` est réutilisé sans modification : seul son contenant
change. Les boutons Imprimer et Télécharger de sa barre d'outils restent
disponibles depuis le plein écran.

Sur bureau, le `ResponsiveSplit` actuel est intégralement conservé.

---

## 8. Pavé de signature

Nouveau fichier `lib/widgets/signature_pad.dart` :

- un `CustomPainter` qui trace les `Path` accumulés par `onPanUpdate` ;
- « Effacer » et « Valider » ;
- à la validation : `PictureRecorder` → `Picture.toImage` → PNG.

Les octets PNG sont passés à `encodeSignaturePng`, **fonction existante** dans
`lib/core/signature_image.dart`. Conséquence : le stockage
(`AppSettings.signature`, base64), l'aperçu A4 et le générateur PDF ne changent
pas d'une ligne. C'était exactement le point d'extension prévu au 25/07/2026.

Le bouton « Dessiner » apparaît à côté d'« Importer » dans la carte « Signature
du document » (Paramètres → Facturation), sur téléphone comme sur bureau — un
écran tactile Windows en bénéficie aussi.

---

## 9. Plateforme Android

```
flutter create --platforms=android,ios .
```

Puis :

- `android/app/src/main/AndroidManifest.xml` : `android:label="KLR TECH"` ;
- `applicationId` : `com.klrtech.gestion` ;
- icône de lanceur dérivée de `assets/logo/klr_mark.png` ;
- `minSdk` et `targetSdk` : valeurs par défaut de Flutter 3.41 ;
- aucune permission ajoutée — `Printing.sharePdf` et
  `getApplicationSupportDirectory` n'en demandent pas. `file_picker`
  (import de signature) utilise le sélecteur système, sans permission de
  stockage.

Le dossier `ios/` est généré pour que le projet soit prêt sur un Mac, mais il
n'est **ni configuré finement ni compilé** : c'est impossible depuis Windows et
serait livré non testé.

`.gitignore` doit accueillir les artefacts Android
(`android/.gradle/`, `android/app/build/`, `local.properties`).

---

## 10. Vérification

Rien n'est déclaré terminé sans la sortie de commande correspondante.

**Non-régression bureau** — le garde-fou principal.

1. `flutter analyze` — zéro problème.
2. `flutter test` — les 15 fichiers de test existants restent verts. Les
   assertions de rendu Flutter (bordures non uniformes, overflow) ne se
   déclenchent qu'en debug : ces tests sont le seul filet.
3. `flutter build windows` puis lancement de l'exécutable — la mise en page
   bureau est inchangée à l'œil.

**Mise en page téléphone.**

4. Nouveau `test/mobile_layout_test.dart`, à 360 × 800 :
   - la coquille rend une `BottomNavigationBar`, pas de `Sidebar` ;
   - Clients, Documents et Suivi rendent des cartes, pas de `HScrollTable` ;
   - `NavScreen.projets` est absent de la navigation ;
   - aucun overflow (le test échoue sur exception de rendu) sur les neuf écrans
     navigables conservés — Bord, Documents, Clients, Gantt, Suivi, Activités,
     Rapports, Paramètres, Création de proforma — plus l'écran de connexion.
5. Chrome à 390 × 844 : parcours de ces dix écrans, lecture de la console.

**Application Android.**

6. `flutter build apk --debug` — succès.
7. Lancement sur émulateur : connexion, création de proforma, aperçu plein
   écran, partage PDF, pavé de signature. Captures d'écran à l'appui.

---

## 11. Fichiers touchés

**Modifiés** — `lib/main.dart` (coquille), `lib/widgets/responsive.dart`
(prédicat + padding), `lib/widgets/common.dart` (`AppTabBar` défilant),
`lib/core/pdf_generator.dart` (partage mobile), les neuf écrans navigables
(padding, cartes, dialogues), `lib/screens/login_screen.dart` (padding de carte
réduit : 24 + 36 de marges ne laissent que 240 px utiles sur 360),
`lib/screens/parametres_screen.dart` (bouton « Dessiner »), `.gitignore`,
`pubspec.yaml` si un paquet manque.

`lib/widgets/sidebar.dart` n'est **pas** modifié : la sidebar n'est simplement
pas montée sous 700 px. C'est la barre du bas qui décide des entrées visibles.

**Ajoutés** — `lib/widgets/signature_pad.dart`,
`lib/widgets/mobile_shell.dart` (barre du bas + feuille « Plus »),
`test/mobile_layout_test.dart`, `android/`, `ios/`.

**Non touchés** — `lib/core/models.dart`, `app_state.dart`, `comptabilite.dart`,
`persistence.dart`, `auth.dart`, `data.dart`, `document_pagination.dart`,
`signature_image.dart`, `theme.dart`. Aucune logique métier ne bouge : c'est une
évolution de présentation, plus deux corrections de plateforme.

---

## 12. Risques

| Risque | Parade |
|---|---|
| Régression silencieuse du bureau | Les lignes de tableau bureau ne sont pas touchées ; `flutter test` à chaque étape |
| Assertion « borderRadius uniforme » réintroduite dans les cartes mobiles | Reprendre le motif documenté : `Border.all` uniforme + `clipBehavior` + bande d'accent en premier enfant |
| Overflow non vu en release | Les tests widget tournent en debug, où les assertions sont actives |
| Accents cassés dans les sources | Ne jamais passer par `Get-Content` / `Set-Content` de PowerShell 5.1 sur les fichiers du projet |
| `flutter build` échoue sur un cache CMake | Supprimer `build/windows` et relancer |
