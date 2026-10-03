# BoosterFish — contre-vérification de l’affichage bord à bord

Date : 2 octobre 2026. Périmètre : les deux avertissements « Expérience
utilisateur » montrés dans Play Console pour **1.0.9 (24)**, leur origine native
et les dispositions Flutter susceptibles de chevaucher les barres Android.
Ce contrôle ne constitue pas une nouvelle certification générale de l’application.

## Conclusion du contrôle initial

Le premier contrôle était incomplet : ses deux tests validaient le contenu des
fichiers, pas la géométrie des widgets. Trois défauts d’affichage supplémentaires
ont été reproduits par des tests de widgets puis corrigés localement. Les tests
de régression ciblés réussissent, mais aucun téléphone n’était connecté : la
validation physique reste à effectuer avant d’intégrer les changements dans un
nouvel AAB et de le téléverser.

La capture de Play Console montre des avertissements d’expérience utilisateur,
pas une notification de rejet. Leur présence seule ne permet ni de conclure à
un rejet, ni de certifier l’affichage ou l’acceptation en production.

## Identité de l’artefact contrôlé

- Archive locale :
  `artifacts/release_backups/1.0.9-24_d9bd9c74/BoosterFish-1.0.9-24-release-d9bd9c74.aab`.
- SHA-256 :
  `d9bd9c74a154554bd068c28993d343fede41050c439c802b6b09760fb04778ee`.
- Manifeste protobuf extrait de cet AAB : version `1.0.9`, code `24`,
  `minSdkVersion=24`, `targetSdkVersion=36`, `compileSdkVersion=36`.
- Métadonnées de compilation : Android Gradle Plugin `9.0.1`.
- SDK local ayant le même moteur que l’archive : Flutter `3.44.4`, moteur
  `a10d8ac38de835021c8d2f920dbf50a920ccc030`.
- Révision du dépôt avant corrections : `d0f820b`. Les fichiers d’interface
  corrigés ici n’avaient pas changé depuis `e911383`, qui porte la version 24.

L’archive locale a été inspectée directement. Aucun nouvel exemplaire n’a été
téléchargé depuis Play Console pour comparer son empreinte ; la correspondance
avec la distribution Play repose sur l’archive de version et la capture fournie.

## Origine des références Android obsolètes

Les deux DEX de l’AAB et sa table de correspondance R8 ont été examinés.

| Emplacement dans l’AAB | Constat |
|---|---|
| `MainActivity.onCreate` | `WindowCompat.enableEdgeToEdge(window)` a été intégré dans la méthode par R8. Il contient des appels à `setStatusBarColor(0)` et `setNavigationBarColor(0)` sans garde de version autour de ces deux appels. |
| `FlutterActivity.configureStatusBarForFullscreenFlutterExperience` et `FlutterFragmentActivity` | Le moteur contient encore un appel à `setStatusBarColor`, protégé pour les anciennes versions Android. |
| `PlatformPlugin.setSystemChromeSystemUIOverlayStyle` | Le moteur conserve les appels de couleur des barres pour la compatibilité avec Android antérieur à l’API 35. |
| Classes AndroidX fusionnées/renommées par R8 | Présence de références à `setDecorFitsSystemWindows` et à la couleur du séparateur de navigation. Le nom obfusqué ne suffit pas à attribuer l’appel à un SDK sans lire la table R8. |

**Rectification du premier diagnostic :** tous les appels obsolètes ne sont pas
conditionnels. En particulier, ceux intégrés depuis AndroidX dans MainActivity
ne le sont pas tous. Cela ne rend pas incorrect l’appel de BoosterFish :
`WindowCompat.enableEdgeToEdge(window)` est précisément la méthode actuellement
recommandée dans la documentation Android, notamment pour les versions anciennes.

Le correctif Flutter `#180061` est déjà présent dans le SDK local. Il ajoute des
gardes d’exécution et ne supprime pas toutes les références du DEX. Le code de
la révision locale `origin/stable` étiquetée `3.47.5` conserve aussi ces appels.
Une montée de version Flutter ne suffit donc pas à prouver que les avertissements
disparaîtront. Aucun moteur ni SDK n’a été modifié ici.

Les références trouvées peuvent expliquer l’avertissement d’API obsolètes. La
liste détaillée de Play Console derrière « Lire la suite » n’a pas été fournie :
elle reste nécessaire pour attribuer exactement chaque signalement de Google.
Le mécanisme interne de détection de Google n’a pas été reproduit.

## Défauts de disposition reproduits et corrigés

Les mesures ci-dessous sont en pixels logiques Flutter, pas en pixels physiques
du Samsung. Les tests utilisent Roboto provenant du SDK Flutter, afin d’éviter
les débordements artificiels de la police Ahem des tests.

| ID | Fichier | Reproduction avant correction | Correction locale |
|---|---|---|---|
| BF-E2E-01 | `lib/widgets/user_spot_form_sheet.dart:260` | Écran 412 × 915, défilement au bas du formulaire : le bouton « Enregistrer » descend à y=895. La limite sûre est y=891 avec une barre de 24, ou y=867 avec une barre de 48. | La marge finale du formulaire inclut maintenant `MediaQuery.padding.bottom`. Le clavier continue d’être traité séparément. |
| BF-E2E-02 | `lib/main.dart:2073` | Paysage 915 × 412, marge latérale gauche de 48 : le bouton des poissons commence à x=16 et empiète donc de 32 sur cette zone. | Prise en compte des marges latérales pour le bouton, la liste des poissons, la recherche et le bandeau d’ajout de spot ; marge inférieure prise en compte pour les contrôles bas. |
| BF-E2E-03 | `lib/main.dart:2228` | Dans le vrai AppShell en paysage, le panneau Outils est ancré à une distance fixe du bas, sans hauteur maximale. Le libellé « Standard » commence à y≈14,3 alors que la zone sûre commence à y=24 ; les éléments précédents sont encore plus hauts. | Panneau borné en haut et en bas, position adaptée à l’orientation et contenu défilable. Le dernier outil reste accessible après défilement. |

Ces constats concernent l’ergonomie et l’accès aux commandes. Aucun de ces
tests n’a démontré un crash/ANR ou un rejet Google Play ; ces catégories ne leur
sont donc pas attribuées.

## Autres occurrences du même problème contrôlées dans le code

`showModalBottomSheet(useSafeArea: true)` évite les intrusions en haut, à gauche
et à droite, **mais pas en bas**. Quatre autres listes/fiches utilisaient une
marge inférieure fixe, indépendante de la barre système. Le même ajout de marge
a été appliqué à :

- la fiche d’un magasin (`lib/pages/shops_map_page.dart`) ;
- la fiche d’une prise communautaire (`lib/features/community/widgets/community_map_view.dart`) ;
- la liste des cartes hors ligne (`lib/widgets/offline_map_manager_sheet.dart`) ;
- la liste des utilisateurs bloqués (`lib/pages/settings_page.dart`).

Les routes de la fiche magasin et de modification du profil ont également reçu
`useSafeArea: true`. Une SafeArea placée à l’intérieur d’une route qui supprime
déjà la marge haute ne suffit pas à restaurer cette marge.

Ces occurrences ont été confirmées par lecture des routes et de leurs marges.
Elles n’ont pas chacune fait l’objet d’un scénario connecté avec données réelles.
Les tests de formulaire et de carte décrits plus haut constituent les
reproductions géométriques directes de ce contrôle.

La navigation principale possède déjà une SafeArea basse : ses cinq commandes
passent les nouveaux tests avec des marges de 24 et 48. Les états de chargement,
d’erreur et de contenu de Marées utilisent une SafeArea. Les écrans utilisant
BoosterFishPageShell sont protégés par sa SafeArea. Ces observations de code ne
remplacent pas la vérification visuelle de chaque état sur appareil.

## Vérifications exécutées

- `flutter analyze` : **aucune anomalie signalée**.
- **58 tests ciblés réussis**, répartis dans 16 fichiers. Ils comprennent tests
  statiques, tests de widgets et références visuelles de l’accueil/du menu.
- Nouveau fichier `test/edge_to_edge_layout_test.dart` : six tests de géométrie
  couvrant deux tailles de barre système, la navigation, le défilement jusqu’au
  bouton d’enregistrement, l’ouverture/fermeture d’un clavier simulé de 320,
  les outils en portrait/paysage et l’accès à leur dernière commande.
- Les tests existants de navigation, retour Android, recherche de ville, appui
  long, commandes de carte, mesure, communauté, profil, accueil et paramètres
  ont été exécutés dans cette sélection.

Commande reproductible :

```sh
flutter test \
  test/edge_to_edge_layout_test.dart \
  test/android_edge_to_edge_configuration_test.dart \
  test/app_shell_navigation_widget_test.dart \
  test/app_shell_double_back_exit_test.dart \
  test/map_controls_accessibility_test.dart \
  test/map_tools_panel_selection_test.dart \
  test/map_measurement_search_indicator_test.dart \
  test/map_city_search_test.dart \
  test/map_long_press_test.dart \
  test/community_map_startup_and_selector_test.dart \
  test/community_ugc_compliance_test.dart \
  test/profile_avatar_configuration_test.dart \
  test/personal_spot_detail_ui_test.dart \
  test/boosterfish_theme_pilot_test.dart \
  test/home_dashboard_test.dart \
  test/settings_accessibility_configuration_test.dart
```

## Limites du contrôle initial et étape avant publication

`adb devices -l` n’a trouvé aucun appareil. Aucun test Android natif, démarrage
à froid, essai de clavier Samsung, mesure ANR ou parcours d’attestation App Check
n’a été réalisé pendant ce contrôle. La suite complète du dépôt n’a pas été
exécutée ; seule la sélection indiquée ci-dessus l’a été.

Les changements sont locaux. Aucun nouvel APK/AAB n’a été construit ou publié,
et la version 24 déjà installée via Google Play ne contient pas ces changements.
Ils ne garantissent pas la disparition des deux avertissements natifs.

Avant le prochain envoi : appliquer `AGENTS.md` et
`docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md`, installer la candidate Release via
`tools/run_app.sh --release -d <device-id>`, puis vérifier sur téléphone :
portrait/paysage, navigation gestuelle/trois boutons, thème clair/sombre,
formulaires avec clavier, dernière action des fiches et outils, démarrage à
froid et parcours essentiels. La validation de la distribution Play et de
l’attestation doit ensuite être effectuée depuis Google Play selon la checklist.

## Références officielles consultées

- [Android — activer le bord à bord et traiter les marges système](https://developer.android.com/develop/ui/views/layout/edge-to-edge)
- [Flutter — limites exactes de useSafeArea dans les fenêtres modales](https://api.flutter.dev/flutter/material/ModalBottomSheetRoute/useSafeArea.html)
- [Flutter — avertissements Play Console, problème 169810](https://github.com/flutter/flutter/issues/169810)
- [Android 16 — suppression de la désactivation du bord à bord](https://developer.android.com/about/versions/16/behavior-changes-16)

## Complément sur appareil physique — 2 octobre 2026

Un Samsung S23 Ultra (SM-S918B), Android 16, a ensuite été connecté.
BoosterFish était absent du téléphone au moment du contrôle ADB. Installation
Release effectuée via `tools/run_app.sh`, après validation des 6 365 spots.
Ce build local conserve 1.0.9 (24) et ne correspond pas au binaire publié.

Premiers constats visuels : carte et catalogue affichés ; page Marées
Casablanca affichée avec courbe et informations, sans écran vide lors de cet
essai. Cette observation ne certifie pas la justesse scientifique des données.

Un quatrième défaut a été observé sur l'écran physique en paysage : la
recherche était peinte devant une partie du panneau Outils. L'ordre des
widgets dans le Stack a été corrigé pour afficher les outils devant la
recherche. Les huit tests de disposition et de sélection des outils passent
après ce changement ; `flutter analyze` ne signale aucune erreur.

La seconde installation est terminée. Vérifications visuelles réussies :
le panneau Outils apparaît devant la recherche en paysage ; la dernière action
« Gérer les cartes » est accessible après défilement ; la recherche reste
visible avec le clavier Samsung ouvert en portrait.

Démarrage à froid via `am force-stop`, puis `am start -W` : statut `ok`,
`LaunchState: COLD`, activité lancée en 345 ms. Ce temps Android ne mesure pas
le chargement complet des données ; la carte affichée a été vérifiée ensuite.
Aucune entrée dans le filtre logcat AndroidRuntime:E/flutter:E collecté après
les essais. L'historique de sorties consulté montre les arrêts forcés du test
et des sorties système, sans crash/ANR répertorié. Cela ne constitue pas un
test d'endurance ni une garantie d'absence de crash.

APK local : `build/app/outputs/flutter-apk/app-release.apk`.
SHA-256 : `764548d5c1f4919c7aa6f42a3e9e215382d8e94b299cb7af517d227e0beccf3b`.
Package installé : versionName 1.0.9, versionCode 24, minSdk 24, targetSdk 36.
Réglages restaurés : accelerometer_rotation=1, user_rotation=0.
Captures avant/après : `evidence/2026-10-02/`.

Aucun AAB n'a été téléversé. Les contrôles d'authentification et d'App Check
depuis Google Play restent à effectuer, ainsi que les parcours communautaires,
le formulaire de spot sur appareil connecté à un compte, le mode trois boutons
et le thème sombre. La validation physique complète de la checklist n'est
donc pas acquise. Les avertissements Play Console ne sont pas déclarés résolus.
