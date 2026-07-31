# BoosterFish — dossier de passation V+8

**Date de passation :** 31 juillet 2026  
**Projet local :** `/Users/salimben/Desktop/Projets/spots_app`  
**Application :** BoosterFish  
**Package Android :** `com.zagorito.spots_app`  
**Candidate actuelle :** `1.0.5 (versionCode 8)`  
**Branche :** `main`  
**But de ce document :** permettre à une nouvelle session de reprendre le travail sans refaire l'audit, sans perdre les décisions déjà prises et sans modifier le code par erreur.

> Ce dossier est une passation technique et opérationnelle. Il ne constitue pas une
> autorisation de publier en production, de modifier le code ou de pousser vers
> GitHub. Toute action externe importante doit être validée explicitement.

## 1. Résumé exécutif

L'audit pré-production et les corrections prioritaires ont été réalisés dans le
dépôt principal. La candidate `1.0.5+8` a été construite avec le script de
release obligatoire, contrôlée, installée localement en Release et validée sur
un appareil physique pour les parcours déjà exécutés.

Le code suivi du dépôt principal est propre. Le seul élément marqué comme
modifié par Git est le sous-dépôt utilisateur `spots_app_temp`, qui est
volontairement hors périmètre de la candidate et ne doit pas être touché.

La situation réelle est donc la suivante :

| Domaine | État |
|---|---|
| Corrections de code de l'audit prioritaire | Réalisées et couvertes par les tests disponibles |
| Build `1.0.5 (8)` | Produit et validé localement |
| Installation Release par câble | Réalisée sur Samsung Android 16 |
| Pages légales publiques | Accessibles en HTTPS et vérifiées |
| Validation depuis Google Play Internal Testing | À faire pour cette candidate |
| App Check / Play Integrity sur l'installation Play | À confirmer depuis Google Play |
| Publication Communauté avec compte Play | À confirmer après installation Play |
| Déclarations Play Console | À relire et finaliser manuellement |
| Fiche Play Store (captures, visuel, vidéo) | À refaire : ancien thème obsolète |
| Disponibilité pays/régions | À choisir |
| Production | Interdite pour le moment |

Il n'y a pas, dans les contrôles locaux connus, de défaut bloquant avéré du
code. Les principaux risques restants sont des validations externes ou des
déclarations Play Console incomplètes/inexactes. Ils doivent être traités avant
toute promotion.

## 2. Règles de continuité à respecter

La nouvelle session doit impérativement :

1. Lire `AGENTS.md`, ce fichier, `docs/releases/1.0.5-8-evidence.md` et
   `docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md` avant toute modification.
2. Considérer `1.0.5+8` comme la base fonctionnelle à préserver.
3. Ne pas refaire l'audit depuis zéro et ne pas réimplémenter une correction
   déjà présente sans preuve d'un défaut reproduit.
4. Ne pas exécuter `flutter run` directement. Utiliser
   `tools/run_app.sh`.
5. Utiliser `tools/build_release.sh` pour tout build Play.
6. Utiliser `flutter test --dart-define-from-file=.env` pour les tests qui
   exigent le catalogue chiffré.
7. Ne pas activer l'enforcement App Check avant validation sur une installation
   provenant de Google Play Internal Testing.
8. Ne pas modifier la logique de zoom/sélection accidentelle de la carte :
   l'utilisateur a volontairement différé ce changement jusqu'à une nouvelle
   réclamation des testeurs.
9. Ne pas modifier les clés, le catalogue chiffré, les règles Firestore ou les
   fonctions backend sans demande explicite et plan de non-régression.
10. Ne pas toucher au sous-dépôt `spots_app_temp`.
11. Ne pas pousser vers GitHub sans autorisation explicite dans la nouvelle
    session.
12. Ne pas passer en production tant que les contrôles de la section 9 ne sont
    pas terminés et documentés.

## 3. Chronologie fonctionnelle et décisions produit

### 3.1 Spots officiels, favoris et spots personnels

La décision produit finale est :

- les spots officiels restent la base de la carte principale ;
- un utilisateur peut ajouter un spot officiel à ses favoris ;
- un utilisateur peut créer un spot personnel immédiatement ;
- son spot personnel apparaît aussitôt dans « Mes spots » et sur sa carte ;
- l'utilisateur n'est pas informé dans l'interface que la création personnelle
  alimente aussi un flux de modération ;
- une copie de modération est conservée dans Firestore afin que
  l'administrateur puisse décider plus tard d'intégrer le spot à la carte
  officielle ou de le considérer comme faux ;
- les spots personnels utilisent le style de marqueur des spots officiels avec
  une couleur bleu marine distincte ;
- les limites sont de 30 favoris et 30 spots personnels ;
- lorsque la limite est atteinte, l'utilisateur doit supprimer un élément avant
  d'en ajouter un autre ;
- le formulaire d'ajout ne présente pas de bouton « envoyer pour validation » :
  l'action visible reste l'enregistrement du spot personnel.

Le long appui sur la carte suit ce parcours :

1. l'utilisateur maintient le doigt sur la carte ;
2. une petite confirmation « Ajouter à mes spots » apparaît à la position
   pressée ;
3. un appui hors de cette confirmation annule sans rien enregistrer ;
4. un appui sur l'action ouvre le formulaire ;
5. les coordonnées sont calculées à partir du point réellement pressé ;
6. les coordonnées invalides sont rejetées ;
7. le spot est enregistré dans l'espace personnel, puis la copie de modération
   est gérée en arrière-plan par le service prévu.

### 3.2 Page « Mes spots »

Les attentes finales sont :

- onglets Favoris / Personnels ;
- nom visible dans la carte ;
- au clic sur la carte, panneau détaillé avec photo, nom et accès direct à la
  carte ;
- accès carte disponible par icône/raccourci ;
- actions Modifier et Supprimer sous forme d'icônes seules ;
- actions présentes sur toutes les cartes et visibles dans la zone inférieure ;
- description et notes lisibles, avec défilement si le panneau est plein ;
- les données personnelles restent privées ;
- les spots personnels réapparaissent sur la carte après relance.

Le code actuel utilise une fiche détaillée plus grande, un
`SingleChildScrollView`, une `Scrollbar` et des tailles de texte augmentées.
Une vérification visuelle reste utile sur un petit écran avec une police système
agrandie, mais la logique de données et les limites n'ont pas été refondues dans
la candidate.

### 3.3 Carte, sélection, vent et outils

Les décisions conservées :

- le démarrage de la carte est en mode satellite ;
- le zoom à deux doigts reste actif ;
- la sélection d'un spot ouvre le panneau de détails et active le vent ;
- quitter le panneau désélectionne le spot et désactive le vent ;
- sélectionner à nouveau le même spot peut réactiver le vent ;
- les outils cartographiques ferment le panneau de spot ;
- la fermeture des outils laisse l'écran disponible pour mesurer ;
- l'outil d'unité de mesure affiche le compteur en temps réel après le premier
  point ;
- le compteur est centré au-dessus de la barre de recherche, isolé et non
  superposé à celle-ci ;
- un bouton X placé à droite permet une fermeture rapide ;
- l'afficheur disparaît lorsque l'outil est quitté ;
- les gestes de carte restent volontairement inchangés pour ne pas introduire
  de régression de sélection pendant un zoom.

Le problème « je touche parfois un spot en zoomant » a été analysé, mais aucun
changement risqué n'a été accepté. Il est explicitement différé jusqu'à une
plainte reproductible d'un testeur.

### 3.4 Communauté et Mes prises

Le modèle final demandé par l'utilisateur comprend :

- une photo de prise ;
- le nom du pêcheur ;
- le spot ou une zone approximative ;
- le montage ;
- l'appât ;
- des notes et conseils ;
- un poids en kilogrammes, pas une longueur en centimètres ;
- un seul visuel public par pêcheur et par spot selon les règles du produit ;
- une galerie privée pouvant contenir 20 images ;
- chaque photo limitée à 2 Mio ;
- une publication publique au maximum par jour ;
- une durée publique de sept jours ;
- les nouvelles données remplacent les anciennes données expirées selon les
  règles serveur ;
- affichage du nombre de likes ;
- annonce de la meilleure prise de la semaine avec photo et nom du pêcheur ;
- conservation de la fenêtre de meilleure prise jusqu'à son remplacement ;
- possibilité de liker, signaler, bloquer et retirer sa propre publication.

Le sélecteur Communauté / Mes prises a été modernisé dans le code :

- hauteur 64 px ;
- zone active en dégradé bleu ;
- icônes 20 px dans une zone 32 × 32 ;
- texte 14,5 px avec contraste clair/sombre amélioré ;
- animation et bordure plus visibles ;
- `IndexedStack` conservé afin de ne pas perdre l'état des deux sections.

Une plainte antérieure indiquait que l'ancien sélecteur était encore visible.
Cette plainte est antérieure à la correction actuelle : la nouvelle candidate
doit donc être contrôlée visuellement après installation depuis Google Play,
sans conclure à une régression avant ce test.

### 3.5 Accès, sécurité et publication Communauté

Les erreurs déjà rencontrées étaient :

- « Cette action n'est pas autorisée » ;
- « La vérification de sécurité est momentanément indisponible » ;
- échec d'envoi de photo avec un message ressemblant à un problème de réseau.

Les causes et corrections connues sont documentées dans la section 5. Une
installation locale par câble ne suffit pas à prouver que Play Integrity
fournit un jeton accepté. La validation doit être faite sur l'application
installée depuis la piste Test interne Google Play.

## 4. Corrections techniques réalisées

### 4.1 Démarrage et carte

Fichiers principaux :

- `lib/main.dart`
- `test/community_map_startup_and_selector_test.dart`
- `test/map_location_stream_resilience_test.dart`

Corrections :

- `MapStyle.satellite` est la valeur initiale ;
- le mode hors ligne reste disponible lorsqu'il est choisi explicitement, mais
  il ne remplace plus silencieusement le satellite au démarrage ;
- le flux GPS évite les abonnements multiples ;
- les erreurs de permission ou de fournisseur sont interceptées ;
- le flux est annulé proprement en cas d'erreur et peut être relancé ;
- la dernière position et le cap sont remis dans un état cohérent.

### 4.2 App Check / Play Integrity

Fichiers principaux :

- `lib/splash_bootstrap.dart`
- `test/app_check_bootstrap_test.dart`

Ordre de bootstrap actuel :

```text
Firebase.initializeApp()
  -> App Check
  -> Crashlytics
  -> chargement des données
  -> AppShell
```

En Release Android, le fournisseur est `AndroidPlayIntegrityProvider`. En
debug, le fournisseur de debug est utilisé uniquement pour le développement.
Une indisponibilité App Check est journalisée sans empêcher le démarrage.

Lors d'une publication, l'absence de jeton est distinguée d'un refus Firestore
générique et la chaîne traduite explique de fermer puis relancer l'application.
Cette distinction améliore le diagnostic, mais ne contourne aucune règle de
sécurité.

### 4.3 Photos de spots personnels

Fichiers principaux :

- `lib/services/user_spot_photo_processor.dart`
- `lib/services/user_spot_service.dart`
- `lib/widgets/user_spot_form_sheet.dart`
- `test/user_spot_photo_processor_test.dart`

Cause traitée : certaines photos Android possédaient des octets PNG/WebP mais
un nom ou un MIME JPEG. Le worker vérifiait la signature réelle et refusait la
requête.

Le processeur actuel :

- lit les octets ;
- décode l'image en isolate ;
- corrige l'orientation EXIF ;
- redimensionne ;
- aplatit la transparence ;
- encode en JPEG ;
- tente plusieurs qualités ;
- garantit une taille finale ≤ 2 Mio ;
- vérifie le type par signature ;
- refuse une source > 20 Mio ou invalide.

Le service d'envoi revalide le contenu et différencie les erreurs HTTP 401, 403,
413 et 415. Les photos déjà enregistrées ne sont pas réécrites.

### 4.4 Lisibilité des détails

Fichiers principaux :

- `lib/pages/my_spots_page.dart`
- `test/personal_spot_detail_ui_test.dart`

La fiche détaillée utilise maintenant :

- nom jusqu'à deux lignes ;
- nom 16 px ;
- coordonnées 11 px ;
- notes/avertissements 13 px ;
- interligne supérieur ;
- `Scrollbar` ;
- `SingleChildScrollView` ;
- `BouncingScrollPhysics` ;
- zone d'actions inférieure distincte ;
- accès carte ;
- Modifier/Supprimer en icônes seules ;
- clés d'accessibilité conservées.

`_DetailLine` étant partagé entre certaines cartes, la taille peut aussi
affecter visuellement les favoris. Cette conséquence doit être contrôlée, pas
corrigée par une refonte non demandée.

### 4.5 Backend, règles et quotas

Les travaux précédents ont sécurisé :

- les règles Firestore propriétaires ;
- les spots personnels et favoris ;
- les prises privées et publiques ;
- les likes ;
- les signalements ;
- le blocage ;
- le retrait par l'auteur ;
- les délais de publication ;
- l'expiration ;
- les schémas et limites ;
- l'absence de droits client pour une souscription premium.

Les limites importantes présentes dans le code sont :

| Fonction | Limite |
|---|---:|
| Favoris | 30 |
| Spots personnels | 30 |
| Galerie privée de prises | 20 |
| Photo de spot personnel | 2 Mio |
| Photo de prise | 2 Mio |
| Publication publique | 1 par 24 h |
| Durée d'une prise publique | 7 jours |
| Doublon de spot personnel | rayon 100 m |
| Nom de spot | 80 caractères |
| Notes de spot | 1 000 caractères |
| Danger/avertissement | 500 caractères |

### 4.6 Robustesse, vie privée et Android

Les contrôles précédents ont confirmé :

- target/compile SDK 36 ;
- min SDK 24 ;
- Java/Kotlin 17 ;
- R8 et réduction des ressources activés ;
- signature Release valide ;
- `allowBackup=false` ;
- règles de sauvegarde/extraction présentes ;
- cleartext HTTP bloqué ;
- manifeste source sans caméra, microphone, stockage partagé, notifications ou
  localisation arrière-plan ;
- localisation coarse/fine uniquement à la demande ;
- Crashlytics Release-only et sans identifiants métier ajoutés ;
- pages légales HTTPS publiques ;
- catalogue chiffré restauré et contrôlé ;
- au moins 6 000 spots officiels exigés par le verrou Gradle.

Le manifeste fusionné peut contenir des permissions transitoires de SDK
(notamment `AD_ID` et `FOREGROUND_SERVICE`). Toute déclaration Play doit être
fondée sur l'App Bundle Explorer et non sur une supposition.

## 5. Preuves et état de la candidate

La preuve détaillée est dans `docs/releases/1.0.5-8-evidence.md`.

### 5.1 Artefacts

```text
AAB :
build/app/outputs/bundle/release/app-release.aab

APK Release :
build/app/outputs/flutter-apk/app-release.apk
```

| Élément | Valeur |
|---|---|
| Package | `com.zagorito.spots_app` |
| Version | `1.0.5` |
| Version code | `8` |
| Min SDK | 24 |
| Target SDK | 36 |
| Taille AAB | 87 035 074 octets |
| SHA-256 AAB | `81a04e72609b447e6014409fec45274b073fa79496abbe1f4b5c839bb22e86c5` |
| Taille APK | 41 839 537 octets |
| SHA-256 APK | `5f32ea0d0f832d1f2bde94d21a33c772488455cac3e87cac900c63cb868ad533` |
| Spots officiels | 6 365 |
| Hash catalogue chiffré | `f66ae12868a35bc8bc5c2830ceb38887da3cce8bf06faad91788fb7c33edf748` |
| Certificat d'importation Play | `19:36:8C:2C:2D:F8:6B:11:C0:53:D0:66:6A:1D:38:A0:AB:E7:1B:95:95:E3:C7:FC:2D:A8:C8:A8:D7:60:3F:97` |

Le certificat d'importation ci-dessus est distinct du certificat de signature
d'application Google Play. Ne jamais remplacer l'un par le hash SHA-256 de
l'AAB.

### 5.2 Résultats de tests

- `flutter analyze` : aucun problème ;
- `flutter test --dart-define-from-file=.env` : 82 réussis, 1 test
  intentionnellement ignoré ;
- traitement photo ciblé : 5 réussis ;
- règles Firestore sur émulateur : 5/5 ;
- Cloud Functions : 2/2 ;
- worker Cloudflare : 13/13 ;
- audits npm backend : aucune vulnérabilité connue ;
- `bundletool validate` : réussi ;
- test ZIP de l'AAB : réussi ;
- `jarsigner -verify` : signature valide ;
- APK v2 : valide.

### 5.3 Appareil physique

- Appareil : Samsung `R5CWB06Y7ZZ` ;
- Android 16 / API 36 ;
- installation Release réalisée avec
  `tools/run_app.sh --release -d R5CWB06Y7ZZ` ;
- démarrage satellite validé ;
- persistance de photos privées après relance validée ;
- correctif d'envoi d'une photo personnelle validé manuellement.

Cette validation locale ne prouve pas l'attestation Play Integrity. Elle doit
être complétée par une installation depuis le canal Internal Testing.

## 6. État Git et sauvegarde

### 6.1 Branche et remote

```text
Branche : main
Remote  : https://github.com/Zagorito-coder/Zagorito.git
Origin  : 4311276
HEAD    : 8c7b43e
Écart   : main est en avance de 4 commits sur origin/main
```

### 6.2 Commits locaux de la candidate

| Commit | Objet |
|---|---|
| `f47f7c9` | Préparation de la release auditée `1.0.5+8` |
| `d3a0617` | Normalisation et correction de l'envoi des photos personnelles |
| `159a6e8` | Documentation des preuves de validation de la release interne |
| `8c7b43e` | Vérification des pages légales en ligne |

Le dépôt principal ne présente pas de modification suivie hors de ces commits.
`spots_app_temp` est un sous-dépôt marqué dirty et doit rester exclu.

Les quatre commits locaux n'ont pas été poussés vers GitHub dans cette
passation, car aucune autorisation explicite de push n'a été donnée dans le
dernier échange. Dans une nouvelle session, demander une confirmation claire
avant `git push origin main`.

## 7. Tâches manuelles restantes dans Google Play Console

Ces tâches sont la priorité opérationnelle. Elles ne signifient pas
automatiquement qu'un défaut de code existe.

### 7.1 Avant de téléverser V+8

1. Ouvrir **Test et publier > Tests internes**.
2. Créer ou modifier la release avec
   `build/app/outputs/bundle/release/app-release.aab`.
3. Vérifier dans l'App Bundle Explorer :
   - package `com.zagorito.spots_app` ;
   - version `1.0.5 (8)` ;
   - target SDK 36 ;
   - permissions réellement détectées ;
   - aucun artefact plus ancien n'est sélectionné par erreur.
4. Enregistrer les notes de version sans déclarer une fonctionnalité absente.
5. Ne pas promouvoir en production à cette étape.

### 7.2 Installer depuis Google Play

Après le traitement de l'AAB :

1. ouvrir le lien du test interne ;
2. rejoindre le test avec le compte testeur ;
3. désinstaller toute version sideloadée ;
4. installer depuis Google Play ;
5. vérifier que l'écran **Informations sur l'application** affiche bien
   `1.0.5 (8)`.

Cette étape est indispensable pour vérifier Play Integrity/App Check.

### 7.3 Parcours de validation manuelle obligatoire

Sur l'installation distribuée par Google Play :

1. démarrage à froid ;
2. fermeture forcée puis relance ;
3. absence de crash et d'ANR ;
4. carte satellite au premier affichage ;
5. localisation refusée, puis autorisée ;
6. UMP/consentement publicitaire refusé, puis accepté ;
7. connexion Google ;
8. déconnexion ;
9. suppression de compte ;
10. ajout d'un spot officiel aux favoris ;
11. création d'un spot personnel ;
12. présence du spot personnel dans « Mes spots » et sur la carte ;
13. modification ;
14. suppression ;
15. ajout d'une photo ≤ 2 Mio ;
16. fermeture complète et relance avec persistance ;
17. ouverture de Communauté ;
18. bascule Communauté / Mes prises ;
19. import d'une photo privée ;
20. publication d'une prise ;
21. publication avec App Check/Play Integrity ;
22. like depuis un second compte ;
23. signalement ;
24. blocage ;
25. retrait de sa propre publication ;
26. vérification du compteur de likes et de l'affichage du poids en kg ;
27. contrôle de la fenêtre de meilleure prise ;
28. vérifier qu'aucun des messages suivants ne réapparaît sans cause :
   - « Cette action n'est pas autorisée » ;
   - « La vérification de sécurité est momentanément indisponible » ;
   - « L'envoi de la photo a échoué. Vérifiez votre connexion. »

Chaque échec doit être noté avec : appareil, version, compte, heure, action,
message exact et capture. Un échec de validation bloque la promotion.

### 7.4 Déclarations à relire

Avant l'examen, vérifier dans Play Console :

- Sécurité des données ;
- Identifiant publicitaire : **Oui** pour AdMob ;
- Annonces : **Oui** ;
- Application gratuite, sans Play Billing ;
- Public cible : 16–17 et 18+ selon la configuration retenue ;
- Classification du contenu et interactivité UGC ;
- Contenu en ligne ;
- Accès à l'application ;
- suppression de compte ;
- déclarations éventuelles de sécurité des mineurs ;
- catégorie Sports ;
- pays/régions ;
- adresse e-mail de contact ;
- URL de confidentialité et URL de suppression ;
- absence d'URL fictive non opérationnelle.

Le formulaire Data Safety doit correspondre à la configuration réelle des SDK et
aux exceptions Google de fournisseur de services. La checklist existante donne
la matrice de travail, mais il faut relire les questions si une bibliothèque ou
un flux a changé.

### 7.5 Compte reviewer

Le compte reviewer doit être :

- dédié ;
- réutilisable ;
- sans 2FA/OTP obligatoire ;
- sans mot de passe expirant ;
- accessible depuis un appareil propre ;
- documenté en anglais dans « Accès à l'application ».

Ne jamais inscrire le mot de passe ou des jetons dans Git, dans ce rapport ou
dans le prompt de nouvelle session.

### 7.6 Fiche Play Store

Le thème de l'application a changé après la création de l'ancienne fiche.

À refaire avant la production :

- captures de téléphone ;
- captures tablette si elles sont conservées ;
- image de présentation 1 024 × 500 ;
- vidéo YouTube publique ou non répertoriée sans limite d'âge ni publicité ;
- textes et descriptions si les anciennes images ne correspondent plus ;
- cohérence de la fiche avec la page Home, la carte, Communauté et Mes spots.

L'URL `http://www.boosterfish.com` ne doit pas rester comme site officiel tant
que le domaine n'est pas réellement lancé. La remplacer par une URL publique
valide ou la laisser vide selon le champ Play Console.

### 7.7 Météo et données distantes

Avant la production, vérifier manuellement :

- abonnement commercial Open-Meteo actif ;
- secret `OPEN_METEO_API_KEY` présent et non expiré ;
- données fraîches dans Firestore ;
- exécution planifiée automatique du workflow ;
- absence de clé ou de secret imprimé dans les logs.

Des exécutions manuelles du workflow ont réussi dans l'audit précédent, mais la
fraîcheur du cron et des secrets doit être reconfirmée.

## 8. Risques classés

### Risques critiques avant production

1. **App Check/Play Integrity non prouvé sur une installation Google Play.**
   Peut maintenir l'erreur de publication malgré le correctif code.
2. **Déclarations Play inexactes ou encore en brouillon.**
   Peut retarder ou provoquer un rejet.
3. **Compte reviewer inutilisable.**
   Peut empêcher l'examen de toutes les fonctions restreintes.
4. **Fiche Play Store obsolète.**
   Les visuels ne doivent pas présenter l'ancien thème.
5. **URL de site non opérationnelle.**
   Ne pas afficher `http://www.boosterfish.com` comme site réel.

### Risques importants mais contrôlables

1. Régression visuelle du sélecteur ou des cartes sur petits écrans.
2. Variation de comportement de consentement UMP selon le pays.
3. Données Data Safety trop larges ou trop étroites par rapport aux SDK.
4. Fraîcheur du workflow météo/secret.
5. Résultats du rapport de pré-lancement et Android Vitals.

### Risques différés volontairement

1. Sélection accidentelle d'un spot pendant le pinch-zoom.
2. Migration du plugin Kotlin historique de `cloud_functions` et
   `firebase_app_check`.
3. Domaine/support e-mail professionnel.
4. Refactor architectural non nécessaire à la release.

Ces points ne doivent pas être modifiés dans une session de préparation Play
sans défaut reproduit et sans plan de tests.

## 9. Ordre recommandé pour la nouvelle session

La reprise la plus sûre est :

1. Lire les documents de passation.
2. Vérifier `git status --short --branch` et confirmer que seul
   `spots_app_temp` est dirty.
3. Ne pas modifier le code.
4. Faire un contrôle léger :
   `flutter analyze`, puis les tests selon le temps disponible.
5. Préparer l'installation/validation de V+8 dans Google Play Internal Testing.
6. Reporter les résultats dans `docs/releases/1.0.5-8-evidence.md` ou dans un
   nouveau journal daté, sans réécrire l'historique.
7. Corriger uniquement un défaut reproduit.
8. Refaire le build avec `tools/build_release.sh` si le code a changé.
9. Réinstaller la même version Release sur appareil physique.
10. Revalider manuellement avant tout nouveau téléversement.
11. Demander explicitement avant un push GitHub.

## 10. Fichiers de référence

- `AGENTS.md` — règles impératives du dépôt ;
- `docs/SESSION_HANDOFF_V8_2026-07-31.md` — ce dossier ;
- `docs/NEW_SESSION_PROMPT_V8.md` — prompt prêt à copier-coller ;
- `docs/releases/1.0.5-8-evidence.md` — preuves de build et de tests ;
- `docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md` — checklist Play et Data Safety ;
- `lib/splash_bootstrap.dart` — bootstrap App Check ;
- `lib/main.dart` — carte, satellite, mesure et état de sélection ;
- `lib/pages/community_page.dart` — sélecteur Communauté / Mes prises ;
- `lib/pages/my_spots_page.dart` — détails et actions des spots ;
- `lib/services/user_spot_photo_processor.dart` — normalisation photo ;
- `lib/services/user_spot_service.dart` — validation/envoi photo ;
- `firestore.rules` — règles de sécurité ;
- `tools/run_app.sh` — installation/test appareil ;
- `tools/build_release.sh` — build signé Play.

## 11. Conclusion de passation

La session longue a produit une candidate fonctionnelle et documentée, mais la
production n'est pas encore autorisée. Le prochain travail n'est pas de
recommencer les corrections déjà faites : c'est de prouver la candidate depuis
Google Play Internal Testing, de finaliser les déclarations manuelles et de
remplacer les éléments obsolètes de la fiche Play Store.

Si un nouveau défaut est découvert, le reproduire d'abord sur la version exacte
`1.0.5 (8)`, distinguer un problème de distribution/App Check d'un problème de
code, puis corriger la plus petite surface possible.
