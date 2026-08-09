# Audit professionnel avant test fermé — BoosterFish

- Date de référence : 1 août 2026
- Version auditée : `1.0.5+8`
- Base initialement auditée : `main` — commit `b1a6fc3`
- Sauvegarde locale post-audit : `backup/pre-closed-audit-2026-08-01` — commit `9d278ed`
- Projet Android : `com.zagorito.spots_app`

## 1. Verdict exécutif

**Décision actuelle : NO-GO pour la production et NO-GO pour téléverser le code local courant comme nouveau candidat de test fermé.**

L'application possède une base de production sérieuse : build Release valide, signature cohérente, catalogue chiffré de 6 365 spots contrôlé avant build, règles Firestore restrictives, App Check Play Integrity déjà validé sur une installation Google Play, pages légales publiques disponibles, absence de vulnérabilité npm connue et analyse Flutter sans erreur.

Le candidat courant n'est cependant pas publiable tant que les points bloquants suivants ne sont pas corrigés et revérifiés :

1. deux tests Flutter sont reproductiblement rouges ;
2. le compteur de signalements communautaires peut être artificiellement augmenté ;
3. plusieurs scénarios de suppression communautaire peuvent laisser une photo publique orpheline ou un ancien classement conservé ;
4. une URL d'avatar arbitraire peut être publiée et utilisée comme pixel de suivi ;
5. le code météo local n'est pas encore présent sur GitHub : les tâches cloud exécutent l'ancienne logique et n'alimentent donc pas encore le résumé GFS requis par la page Marées ;
6. une validation physique Profile a réussi sur un SM A037F Android 13, mais le candidat Release exact reste non validé : sa signature est incompatible avec l'installation Debug/Profile existante et son installation nécessiterait une désinstallation avec perte potentielle des données locales ;
7. les 37 fichiers de travail sont sécurisés dans un commit local dédié, mais cette branche n'est pas encore sauvegardée sur GitHub et `origin/main` reste en retard.

La version interne déjà publiée peut rester disponible. En revanche, le nouvel AAB généré pendant l'audit ne doit pas être téléversé avant fermeture de ces écarts.

## 2. Périmètre et méthode

L'audit a couvert :

- état Git local et GitHub ;
- analyse statique, tests Flutter, Node, Python et règles Firestore ;
- build Android Release, signature, manifest fusionné, permissions et Android Lint ;
- Firebase Auth, Firestore, Cloud Functions, App Check et suppression de compte ;
- Cloudflare Worker/R2 et cycle de vie des photos ;
- stockage local, synchronisation cloud et confidentialité ;
- communauté, signalement, blocage, likes et classement hebdomadaire ;
- cartes OSM, tuiles, Overpass, animation du vent et mémoire image ;
- publicité AdMob/UMP, Crashlytics et déclarations Google Play ;
- accessibilité, localisation, dette de maintenance et CI/CD.
- validation physique Profile sur SM A037F Android 13 : installation, démarrages à froid, carte, vols vers les spots, mémoire, fluidité UI/GPU et recherche de crash/ANR.

Cet audit n'a modifié aucun comportement applicatif, aucune règle distante, aucune donnée Firebase/R2 et aucune version publiée. Le présent rapport est le seul fichier ajouté par l'audit.

## 3. Résultats vérifiés

| Contrôle | Résultat | État |
|---|---:|---|
| `flutter analyze` | aucune erreur | Réussi |
| Suite Flutter complète avec `.env` | 101 réussis, 1 ignoré, 2 échecs | Bloquant |
| Tests Worker Cloudflare | 13/13 | Réussi |
| Tests Cloud Functions communauté | 2/2 | Réussi mais couverture insuffisante |
| Tests Python récolte | 11/11 | Réussi |
| Tests règles Firestore avec émulateur | 5/5 | Réussi mais couverture insuffisante |
| Audit npm production + complet, deux projets Node | 0 vulnérabilité connue | Réussi |
| Android Lint Release | aucune anomalie | Réussi |
| Build AAB via `tools/build_release.sh` | réussi | Réussi |
| Build APK via `tools/build_release.sh` | réussi | Réussi |
| Vérification de signature APK | schéma v2 valide, 1 signataire | Réussi |
| Détection du téléphone | SM A037F, Android 13/API 33, ADB `R9YRB0N9JHL` | Réussi |
| Installation Profile via `tools/run_app.sh` | réussie sans suppression des données ; 6 365 spots validés | Réussi |
| Démarrages à froid Profile | 4,063 s, 3,715 s et 3,649 s ; médiane 3,715 s | Réussi en Profile |
| Crash/ANR pendant la validation Profile | aucun ; `exit-info` contient seulement les `FORCE STOP` volontaires | Réussi sur le parcours observé |
| Vol cartographique physique | deux déplacements vers des spots distincts réussis | Réussi en Profile |
| Validation physique du Release exact | non exécutée à cause de l'incompatibilité de signature et du risque de perte des données locales | Bloquant avant téléversement |
| Format Dart des 26 fichiers changés | `lib/main.dart` non conforme | À corriger |

Les résultats Profile réduisent le risque fonctionnel et permettent un profilage représentatif, mais ne valident ni la signature Release, ni Crashlytics Release, ni le comportement exact de Play Integrity/App Check du candidat à téléverser.

### Artefacts locaux générés

- AAB : `87 466 610` octets, SHA-256 `c08a7ef9fb25c776fe264c24801cf80b98df787bb2c9ab83abccb7956e5f970c`
- APK universel : `87 242 806` octets, SHA-256 `559956140a0f6e5021e39150595c24ec1b02351addc2b2ddfce68c53e074153e`
- certificat de signature SHA-256 : `19368c...03f97`, présent dans la configuration Firebase
- `targetSdk 36`, `minSdk 24`, version `1.0.5+8`

Le poids universel de l'APK additionne trois architectures. Le téléchargement arm64 attendu depuis Google Play est estimé autour de 28 Mo avant surcoût des splits ; le poids utilisateur n'est donc pas un blocage. Une grande partie du poids de l'AAB correspond aux symboles natifs et au mapping d'obfuscation utiles à la symbolication.

### Validation physique Profile — SM A037F

Le téléphone `SM A037F`, Android 13/API 33, a été détecté sous l'identifiant ADB `R9YRB0N9JHL`. L'application Profile a été installée via `tools/run_app.sh --profile` sans désinstallation et sans perte des données existantes. Le verrou de build a validé 6 365 spots avant installation.

Trois démarrages à froid non destructifs ont pris respectivement 4,063 s, 3,715 s et 3,649 s, soit une médiane de 3,715 s. L'écran Maps, les tuiles satellite et les marqueurs se sont correctement affichés. Aucun crash, ANR, exception non gérée ou erreur fatale n'a été observé dans les journaux Android. Les seules sorties recensées par `exit-info` correspondent aux `FORCE STOP` volontairement provoqués par les commandes de redémarrage.

Après stabilisation du dernier démarrage, Android rapportait `362 011 KB` de PSS, `461 506 KB` de RSS et `92 934 KB` de mémoire graphique. Le premier instantané à froid rapportait `350 793 KB` de PSS et `450 244 KB` de RSS. Ces valeurs Profile sur un seul appareil ne prouvent pas une fuite mémoire, mais confirment un budget mémoire élevé qui doit être surveillé sur le Release exact et sur plusieurs appareils. Le relevé Android limité aux 22 premières frames de démarrage comptait 10 frames lentes ; cet échantillon court confirme surtout que l'initialisation est lourde.

Deux vols cartographiques vers des spots différents ont abouti correctement. Avec le vent actif, le thread UI restait sain (`p95 8,012 ms`, aucune frame UI au-delà de 16,7 ms), tandis que le raster atteignait `p95 20,394 ms`, avec environ 56 % des frames au-delà de 16,7 ms. Sans vent, le raster s'améliorait à `p95 17,743 ms` et environ 35 % de frames hors budget ; le thread UI restait sous le budget (`p95 10,138 ms`). Sans sélection de spot et sans vent, aucune frame continue n'a été produite pendant la période d'inactivité observée.

Cette comparaison indique un goulot principalement graphique, accentué par le vent, les tuiles satellite et les effets du spot sélectionné. Elle ne montre pas de surcharge permanente lorsque la carte est réellement inactive. Le journal contient aussi des avertissements non fatals issus de Google Mobile Ads/Google Play services et de l'accès aux API Android internes ; ils n'ont pas empêché l'affichage, mais leur compatibilité doit être revérifiée lors de la validation Release.

## 4. Bloquants — priorité P0

### P0-01 — Deux tests Flutter rouges

`test/map_location_stream_resilience_test.dart` cherche la signature textuelle exacte `void _initPositionStream()`, alors que la méthode accepte maintenant un paramètre nommé. Le test échoue par `RangeError` avant de vérifier le comportement. Il doit être rendu structurel ou mis à jour sans réduire sa garantie.

`test/map_long_press_test.dart` attend que la carte atteigne `31.2 / -9.8` après la sélection d'un spot personnel ; le centre reste à `30.5`. Le nouveau vol cartographique utilise un `Stopwatch` réel et des délais asynchrones, ce qui n'est pas déterministe sous l'horloge simulée des tests Flutter. Il faut vérifier si le problème est uniquement de testabilité ou s'il existe aussi sur appareil, puis garantir l'arrivée exacte au spot.

Sur le SM A037F, deux vols vers des spots distincts ont visuellement abouti. Cela réduit la probabilité d'une panne fonctionnelle générale et renforce l'hypothèse d'un problème de déterminisme sous horloge simulée. Le test reste néanmoins bloquant tant que l'arrivée exacte et déterministe n'est pas garantie automatiquement.

Critère de fermeture : suite Flutter complète verte, sans suppression ni affaiblissement des assertions métier.

### P0-02 — Signalement communautaire rejouable et agrégat non idempotent

Les règles autorisent un utilisateur à supprimer son propre document de signalement, puis à recréer le même identifiant. Chaque recréation déclenche une nouvelle incrémentation de `reportCount`. Trois cycles peuvent donc masquer artificiellement une publication légitime.

En plus, Firebase documente que les événements Firestore sont livrés **au moins une fois** et qu'un même événement peut invoquer plusieurs fois une fonction. `onCommunityReportCreated` incrémente pourtant directement le compteur sans registre d'événement idempotent. Une livraison dupliquée peut donc produire le même effet sans action malveillante.

Critère de fermeture : rendre les signalements non supprimables côté client, rendre la fonction idempotente, ajouter des tests de suppression/recréation et de double livraison, puis prévoir une méthode fiable de recalcul du compteur.

Référence : [Cloud Firestore triggers — livraison au moins une fois](https://firebase.google.com/docs/functions/firestore-events).

### P0-03 — Suppression et conservation des publications/photos non garanties

Plusieurs chemins présentent un risque de conservation involontaire :

- si une semaine ne contient aucun candidat, l'ancien gagnant et l'ancien classement interne ne sont pas effacés ;
- pendant une rotation, l'échec de suppression R2 est ignoré puis le document Firestore est supprimé sans nouvelle tentative photo ;
- l'écriture du nouveau classement précède le nettoyage de l'ancien, ce qui peut perdre la référence nécessaire à une reprise ;
- les triggers de création de signalement et de suppression de publication déployés ont été observés avec `retry=false` ;
- la réponse publique des photos communautaires autorise un cache de 24 heures, donc une image supprimée de R2 peut rester visible dans un cache intermédiaire ou local ;
- aucun cycle de vie R2 de sécurité n'a été prouvé pour éliminer les objets orphelins.

R2 est fortement cohérent en accès direct, mais Cloudflare précise qu'un objet supprimé peut rester disponible lorsqu'il est encore en cache. Une purge/version de révocation ou un TTL plus court est nécessaire pour les suppressions sensibles.

Critère de fermeture : rendre le nettoyage idempotent et reprenable, traiter explicitement chaque échec R2, vider l'ancien état lorsqu'il n'y a aucun candidat, configurer les reprises, ajouter une expiration R2 de secours et tester les scénarios de panne.

Références : [cohérence et cache R2](https://developers.cloudflare.com/r2/reference/consistency/), [cycles de vie R2](https://developers.cloudflare.com/r2/buckets/object-lifecycles/).

### P0-04 — URL d'avatar publique arbitraire

La règle de publication accepte toute valeur correspondant à `https://.+`. Un utilisateur authentifié peut donc publier une URL qu'il contrôle. À l'affichage, l'application la charge comme image réseau : le serveur distant peut alors recevoir l'adresse IP, l'agent utilisateur et l'heure de consultation des autres pêcheurs.

Critère de fermeture : accepter seulement une liste stricte d'hôtes de confiance ou supprimer/relocaliser les avatars publics via un proxy contrôlé. Ajouter des tests de règles pour les hôtes autorisés et refusés.

### P0-05 — Parité locale/GitHub/cloud absente pour les nouvelles données GFS

Les modifications locales ajoutent un résumé `gfs` dans `conditions/{ville}` et empêchent la tâche quotidienne de l'écraser. Elles sont sécurisées dans le commit local `9d278ed`, basé sur `b1a6fc3`, mais ne sont pas sur `origin/main`. Les tâches GitHub Actions continuent donc à exécuter le commit distant `4311276`.

Conséquence : la page Marées peut encore afficher pression, pluie et humidité comme indisponibles, même si la page Marées Pro possède les valeurs dans `spots_meteo`.

Critère de fermeture : tests verts, commit contrôlé, push sur une branche de préparation, revue, fusion, exécution manuelle des deux workflows, puis lecture de cinq documents `conditions` et vérification sur téléphone.

### P0-06 — Release exact toujours non validé sur appareil physique

La validation physique Profile a été réalisée sur un SM A037F Android 13 : installation protégée par `tools/run_app.sh`, catalogue de 6 365 spots validé, trois démarrages à froid stables, écran Maps correct, deux vols réussis et aucun crash/ANR observé.

Cette validation ne ferme toutefois pas le blocage Release. Le certificat du Release est incompatible avec celui de l'application Debug/Profile actuellement installée. Android refuse donc la mise à jour directe ; une désinstallation serait nécessaire et supprimerait les données applicatives locales non synchronisées.

Critère de fermeture : sécuriser préalablement les données nécessaires ou utiliser un appareil de test distinct, installer le candidat exact avec `tools/run_app.sh --release -d <device-id>`, puis exécuter intégralement `docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md`. La validation doit inclure le démarrage à froid, Crashlytics Release, App Check/Play Integrity et les parcours essentiels. Une validation échouée bloque le téléversement.

## 5. Risques élevés — priorité P1

### P1-01 — App Check absent sur les photos de spots personnels

Les écritures de photos communautaires vérifient Auth **et** App Check, mais les routes `spot-photos` vérifient seulement Auth. Cela contredit la politique publiée, qui affirme que les écritures de photos sont protégées par les deux mécanismes, et facilite les abus de stockage avec un jeton Auth obtenu hors de l'application authentique.

Action : exiger App Check aussi pour `PUT` et `DELETE` des spots personnels, prévoir le comportement reviewer, ajouter des tests Worker et maintenir la lecture privée par propriétaire.

### P1-02 — Rafraîchissements Overpass trop agressifs

Chaque appel `loadShops` renvoie le cache/CSV puis lance quand même un rafraîchissement Overpass. Il n'existe ni TTL, ni déduplication d'une requête en cours, ni annulation. Pour 111 villes côtières, un rafraîchissement peut déclencher environ 14 lots et jusqu'à 42 requêtes HTTP, avec des délais pouvant atteindre 90 secondes. Plusieurs écrans peuvent en lancer en parallèle.

Les journaux téléphone précédents contenaient déjà des réponses 406, 429 et 403. Le fallback CSV maintient l'affichage, mais la stratégie actuelle risque batterie, données mobiles, lenteur et blocage des services publics.

Action recommandée : faire la récolte côté serveur et distribuer un fichier/dataset mis en cache. À défaut : TTL de plusieurs jours, une seule requête en vol, timeout court, backoff et actualisation explicite.

### P1-03 — Animation du vent coûteuse sur appareils à forte densité

À forte densité, 200 particules sont recréées dans une nouvelle liste avec un nouveau générateur pseudo-aléatoire à chaque frame, jusqu'à 30 fps. Le commentaire annonçant une pause pendant le déplacement de carte n'est pas accompagné d'un abonnement aux événements de mouvement. Un vol de carte ajoute ainsi ses propres mouvements aux reconstructions du vent.

Le profilage physique confirme que le thread Dart/UI n'est pas le facteur limitant : avec le vent, son p95 est de 8,012 ms sans frame au-delà de 16,7 ms. Le raster/GPU atteint en revanche un p95 de 20,394 ms et dépasse le budget sur environ 56 % des frames. Sans vent, le raster descend à 17,743 ms et environ 35 % de frames hors budget. Le vent représente donc une part mesurable du coût, sans être l'unique source de charge graphique. Lorsque le spot est fermé et le vent désactivé, aucune frame continue n'est produite à l'arrêt ; aucun indice de boucle de rendu permanente n'a été observé dans cet état.

Action : suspendre pendant geste/vol, préallouer les graines, utiliser le delta de temps réel, réduire le niveau de détail sur appareils modestes et piloter le `CustomPainter` via un `Listenable` sans reconstruire le widget complet.

### P1-04 — Page Paramètres non défilable et accessibilité incomplète

La page utilise `NeverScrollableScrollPhysics` avec un `SliverFillRemaining` et une colonne dense. Sur petit écran, orientation paysage ou grande taille de police, le contenu peut être coupé et l'action de suppression de compte devenir difficile à atteindre. Plusieurs textes ont aussi une taille de 8 à 11 px et un nombre de lignes forcé.

Action : autoriser le défilement, tester à 200 % de taille de texte, en paysage, avec TalkBack et avec les quatre langues. Maintenir des cibles tactiles d'au moins 48 dp et ajouter des tests de non-overflow.

### P1-05 — Police Inter téléchargée à l'exécution

`google_fonts` autorise le téléchargement HTTP par défaut. Aucune police Inter n'est déclarée dans les assets et aucune désactivation du téléchargement n'est configurée. La page Marées peut donc contacter `fonts.gstatic.com`, afficher d'abord une police de secours et dépendre du réseau. Ce destinataire n'est pas cité dans la politique actuelle.

Action : embarquer les fichiers Inter et leur licence, enregistrer la licence dans Flutter, puis désactiver explicitement le téléchargement à l'exécution.

Référence : [documentation `google_fonts` sur le bundling](https://pub.dev/packages/google_fonts).

### P1-06 — Aucun contrôle CI pour l'application mobile

Les deux workflows GitHub sont correctement limités à `contents: read` et auditent leurs dépendances, mais ils servent uniquement aux récoltes météo planifiées. Aucun workflow sur push/PR n'exécute `flutter analyze`, les tests, les tests Node/Python/règles, le format ou un build de contrôle.

Action : ajouter un pipeline CI sans secret de production, puis un job Release protégé utilisant des secrets d'environnement uniquement sur branche/tag autorisé. Protéger `main` contre une fusion lorsque les contrôles échouent.

### P1-07 — Identité d'exécution Cloud Functions trop large et dérive de déploiement

Les fonctions actives utilisent le compte de calcul par défaut. Les hashes de source observés ne sont pas homogènes entre toutes les fonctions, ce qui indique des déploiements partiels et empêche d'affirmer que le cloud correspond exactement au dépôt.

Action : créer un compte de service dédié au moindre privilège, déployer le codebase communauté de manière atomique, enregistrer le commit déployé et vérifier toutes les revisions/hashes.

### P1-08 — Suppression de compte partielle possible

Le flux efface plusieurs catégories avant de supprimer Firebase Auth. Si une étape tardive échoue, le compte reste actif alors qu'une partie des données a déjà disparu. Le nettoyage est globalement bien conçu, mais il doit être clairement reprenable et idempotent.

La suppression des signalements d'un utilisateur ne recalcule pas non plus les `reportCount` des publications concernées, ce qui peut conserver des compteurs gonflés.

Action : état de progression serveur, reprise sûre, recalcul des agrégats et tests d'intégration avec panne injectée.

## 6. Risques moyens — priorité P2

- Les limites de 30 favoris/spots sont vérifiées par comptage puis écriture côté client ; deux appareils peuvent dépasser la limite simultanément. Préférer une transaction/compteur serveur.
- La galerie privée « Mes prises » est isolée dans SQLite et dans des JPEG locaux, mais n'utilise pas de chiffrement applicatif SQLCipher. L'isolation Android, le chiffrement de l'appareil et l'exclusion des sauvegardes réduisent le risque sans protéger un appareil rooté ou une extraction hors ligne.
- Le catalogue embarqué est chiffré en AES-CBC mais la clé est livrée à l'application et le JSON déchiffré est mis en cache dans le répertoire applicatif. Il s'agit d'une protection contre la copie simple, pas d'un secret inviolable.
- Les cinq onglets sont créés à la demande et leurs animations cachées sont suspendues. Sur le SM A037F en Profile, le dernier démarrage stabilisé atteignait `362 011 KB` de PSS et `461 506 KB` de RSS, dont `92 934 KB` pour Graphics. Ce niveau justifie une surveillance sur davantage d'appareils et sur le Release exact, mais l'arrêt complet des frames sans spot sélectionné ni vent est positif.
- Les deux PNG Paramètres pèsent environ 2 Mo chacun et décodent en plusieurs mégaoctets. Convertir en WebP/AVIF adapté ou fournir des variantes à la taille d'affichage réduirait mémoire et temps de décodage.
- Le projet contient environ 32 446 lignes Dart réparties dans 90 fichiers, avec plusieurs fichiers de 900 à 2 400 lignes. Cela augmente le risque de régression. Ne pas lancer une refonte avant le test fermé ; planifier ensuite une extraction progressive par fonctionnalité.
- Il n'existe aucun dossier `integration_test`. Les 34 fichiers de tests unitaires/widgets sont utiles mais ne couvrent pas un parcours réel complet Auth → ajout → publication → like → signalement → blocage → suppression.
- Python local est en 3.9, version en fin de vie, avec un avertissement LibreSSL. Le CI utilise Python 3.11 : la production planifiée n'est pas bloquée, mais le poste local doit être aligné.
- Treize mises à jour de dépendances sont compatibles avec les contraintes. Ne pas faire de mise à niveau groupée avant le test fermé ; traiter les mises à jour par petits lots avec tests et profilage, notamment les versions bêta des tuiles vectorielles.
- Aucune page dédiée aux licences open source n'est exposée. Ajouter une page de licences améliore la conformité aux notices des dépendances et doit accompagner l'embarquement des polices.

## 7. Points solides confirmés

- Le build Android refuse automatiquement une clé absente/invalide ou un catalogue de moins de 6 000 spots.
- Le Release est minifié, les ressources sont réduites, le cleartext HTTP est refusé et les sauvegardes Android sont désactivées/exclues.
- Aucun accès large aux photos, au stockage, au micro, aux notifications ou à la localisation en arrière-plan n'est déclaré dans le manifest Release. Le sélecteur système est utilisé pour la galerie.
- Les photos sont réencodées, limitées à 2 Mo et débarrassées de leurs métadonnées EXIF avant enregistrement.
- Les données privées Firestore sont isolées par UID ; les prévisions publiques sont en lecture seule côté client.
- App Check Release via Play Integrity a déjà été validé sur une installation provenant de Google Play. Le refus du token Debug non autorisé est le comportement attendu.
- Crashlytics est activé en Release et désactivé en Debug/Profile ; le service évite volontairement UID, e-mail, position et texte privé.
- Sur SM A037F Android 13, le Profile démarre correctement, affiche la carte, termine deux vols vers des spots et ne produit aucun crash/ANR dans `logcat` ou `exit-info` sur le parcours observé.
- Le rendu devient réellement inactif lorsque le spot est fermé et le vent désactivé, ce qui limite la consommation permanente dans cet état.
- UMP bloque la demande publicitaire tant que le SDK ne retourne pas `canRequestAds`, avec accès aux préférences lorsque requis.
- L'intégration OSM utilise l'URL officielle, un User-Agent identifiable, une attribution visible, un cache local de 256 Mo et aucun téléchargement hors ligne depuis `tile.openstreetmap.org`. Les cartes hors ligne viennent de PMTiles auto-hébergés.
- Les quatre fichiers de langue sont des JSON valides et leurs ensembles de clés sont cohérents.
- Les pages publiques de confidentialité et CGU répondent en HTTP 200 et correspondent octet pour octet aux fichiers du dépôt.
- `.env`, clés de signature, `key.properties`, fichiers Firebase locaux et caches Wrangler sont ignorés. Aucun secret privé actuel n'a été trouvé dans les fichiers suivis. Un ancien `google-services.json` reste dans l'historique Git ; sa clé Firebase est une configuration publique, mais les restrictions API et App Check doivent rester actives.
- Les tâches GitHub météo récentes réussissent et utilisent des actions épinglées par SHA, des permissions `contents: read`, une concurrence contrôlée et des secrets non écrits durablement.

Référence OSM : [Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).

## 8. Données locales et cloud

L'expression « tout enregistrer localement et dans le cloud » doit être séparée entre le **code** et les **données utilisateur**.

### Code

Les 37 fichiers de travail sont enregistrés dans le commit local `9d278ed` sur `backup/pre-closed-audit-2026-08-01`. Ils ne sont toutefois pas encore sauvegardés sur GitHub. Le push direct sur `main` reste interdit tant que les tests et les P0 sont ouverts. La méthode sûre est : branche distante de sauvegarde dédiée, contrôle des secrets, exclusion de `spots_app_temp`, revue, CI verte, puis fusion contrôlée.

### Données utilisateur

Le comportement actuel est volontairement hybride :

| Donnée | Local | Cloud | Visibilité |
|---|---|---|---|
| Prises privées | SQLite + JPEG | Non | appareil/compte local |
| Spots personnels | cache Firestore | Firestore + photo R2 privée | propriétaire/reviewer |
| Favoris | cache Firestore | Firestore | propriétaire |
| Publications communauté | cache | Firestore + R2 public | public pendant publication/classement |
| Préférences | SharedPreferences/stockage sécurisé | Non | appareil |
| Cartes hors ligne | fichiers locaux | source R2 | propriétaire de l'appareil |
| Prévisions | cache Firestore | Firestore | publiques |

Synchroniser les prises privées ou leurs coordonnées exactes vers le cloud serait une nouvelle finalité de traitement, pas une simple sauvegarde technique. Cela exigerait un choix utilisateur clair, une architecture chiffrée, des règles/quotas, une suppression cloud, une mise à jour de la politique et du formulaire Data Safety. Aucun changement de ce type ne doit être implicite.

## 9. Google Play et politique

### Conforme ou bien engagé

- `targetSdk 36` satisfait déjà l'exigence Android 16 applicable aux nouvelles soumissions à partir du 31 août 2026.
- Le parcours de suppression existe dans l'application et la politique publique possède une ancre de suppression avec une demande par e-mail hors application.
- La communauté impose l'acceptation des CGU avant publication et fournit signalement et blocage.
- Le manifest n'utilise pas `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`, conformément au principe de sélection ponctuelle.

### À vérifier obligatoirement dans Play Console

Le formulaire Data Safety doit refléter l'application et tous ses SDK. Au minimum, réévaluer :

- localisation approximative et précise, optionnelles, pour la fonctionnalité cartographique ;
- nom, e-mail, photo de profil et identifiant utilisateur, optionnels, pour le compte/communauté ;
- photos et autres contenus créés par l'utilisateur ;
- likes, signalements et blocages comme autres actions ;
- crash logs, diagnostics et identifiants d'installation ;
- IP/localisation générale, interactions publicitaires, diagnostics et identifiants appareil/compte collectés automatiquement par Google Mobile Ads pour publicité, analytics et prévention de fraude ;
- chiffrement en transit et mécanismes de suppression.

Google précise que les déclarations sont requises dès le test fermé et que l'éditeur reste responsable des SDK tiers. La déclaration AdMob exacte doit être comparée à la version réellement embarquée au moment du téléversement.

Références :

- [Data Safety Google Play](https://support.google.com/googleplay/android-developer/answer/10787469)
- [déclaration Google Mobile Ads](https://developers.google.com/admob/android/privacy/play-data-disclosure)
- [déclaration Firebase Android](https://firebase.google.com/docs/android/play-data-disclosure)
- [suppression de compte Google Play](https://support.google.com/googleplay/android-developer/answer/13327111)
- [politique UGC Google Play](https://support.google.com/googleplay/android-developer/answer/9876937)
- [politique de sélection de photos](https://support.google.com/googleplay/android-developer/answer/16935362)
- [niveau API cible](https://support.google.com/googleplay/android-developer/answer/11926878)

Si le compte développeur personnel est concerné, Google demande au moins 12 testeurs inscrits continuellement pendant 14 jours avant la demande d'accès production. Des testeurs simplement inscrits mais non engagés peuvent conduire à une demande de test supplémentaire.

Référence : [exigences du test fermé](https://support.google.com/googleplay/android-developer/answer/14151465).

Pendant le test fermé, surveiller Android Vitals et viser très en dessous des seuils de mauvais comportement : ANR perçu global `0,47 %`, crash perçu global `1,09 %`, et `8 %` par modèle d'appareil.

Référence : [Android Vitals](https://support.google.com/googleplay/android-developer/answer/9844486).

## 10. Plan de remise en état recommandé

### Phase A — sécuriser sans modifier le design

1. créer une branche locale de préparation et exclure explicitement `spots_app_temp` ;
2. corriger les deux tests et rendre le vol cartographique déterministe ;
3. corriger l'idempotence des signalements et interdire leur suppression client ;
4. restreindre les avatars ;
5. fiabiliser suppression/classement/R2 et App Check des spots personnels ;
6. ajouter les tests de règles, Worker et Functions correspondant à chaque correction.

### Phase B — performance, confidentialité et CI

1. réduire la stratégie Overpass ;
2. suspendre/optimiser les particules pendant les mouvements de carte ;
3. rendre Paramètres défilable et tester l'accessibilité ;
4. embarquer Inter et désactiver le téléchargement de police ;
5. créer une CI mobile obligatoire ;
6. aligner le service account Functions au moindre privilège.

### Phase C — sauvegarde GitHub et cloud

1. relancer tous les contrôles localement ;
2. commiter sur une branche GitHub de préparation, jamais directement sur `main` ;
3. ouvrir/revoir le diff, obtenir une CI verte et fusionner ;
4. exécuter manuellement les deux workflows météo et vérifier les documents Firestore ;
5. déployer ensemble règles, indexes, Functions et Worker depuis le commit approuvé ;
6. enregistrer le commit, les revisions cloud, les hashes AAB/APK et le résultat de validation.

### Phase D — appareil et Play Console

1. conserver comme preuve la validation Profile réalisée sur le SM A037F et compléter la matrice avec au moins un Android récent ;
2. sécuriser les données locales ou utiliser un second appareil afin d'installer le Release exact sans perte de données ;
3. installer ce Release via `tools/run_app.sh --release` ;
4. valider démarrage à froid, carte, vol, tuiles, boussole/COG, météo, marées, spots, communauté, Auth, App Check, ads/consentement et suppression ;
5. lancer un test fermé avec une matrice de modèles, langues, thèmes, réseau lent/hors ligne et grande taille de police ;
6. contrôler Pré-launch report, Crashlytics, ANR et Vitals avant toute promotion.

## 11. Règle de sauvegarde GitHub pour l'état courant

La sauvegarde GitHub est autorisée par la demande utilisateur, mais **le push sur `main` reste bloqué par l'audit**. Les protections minimales sont :

- aucune inclusion de `.env`, keystore, `key.properties`, fichiers Google Services ou caches locaux ;
- aucun changement dans le dépôt imbriqué `spots_app_temp` ;
- aucun commit mélangeant rapport d'audit, corrections critiques et artefacts binaires sans séparation claire ;
- branche distante de sauvegarde/préparation avant toute fusion ;
- tests verts et validation physique avant nouveau tag ou téléversement Play.

État Git constaté : `main` est sept commits devant `origin/main`, avec de nombreux fichiers modifiés/non suivis. `origin/main` pointe sur `4311276`; le HEAD local pointe sur `b1a6fc3`. Aucun push n'a été effectué pendant l'audit.

### Sauvegarde locale réalisée après l'audit

Les 37 fichiers de travail ont été enregistrés localement dans le commit `9d278ed` sur la branche `backup/pre-closed-audit-2026-08-01`. Le rapport de sécurité reste volontairement non suivi et local, et `spots_app_temp` reste exclu. Le push GitHub est en attente d'une confirmation explicite du dépôt public `https://github.com/Zagorito-coder/Zagorito.git`; `origin/main` n'a pas été modifié.
