# Audit de production et rapport des corrections — BoosterFish

Date : **21 juillet 2026**  
Version auditée : **1.0.1 (4)**  
Package Android : `com.zagorito.spots_app`

## Résumé exécutif

BoosterFish est techniquement stable, signée et fonctionnelle sur appareil réel.
L'analyse statique est propre, les 9 tests Release passent, l'AAB et l'APK ont
été produits avec R8, et aucun crash ni ANR n'a été observé pendant les contrôles
sur un Samsung Galaxy A03s sous Android 13.

Les corrections ont fermé les principaux risques de perte de données, de fuite
de secrets dans le dépôt, d'écriture Firestore non autorisée, de consentement
publicitaire incorrect, de suppression de compte incomplète, de mémoire excessive
sur la carte et de non-conformité Android 16. Les pages légales sont désormais
publiques et à jour.

Il reste **un blocage juridique externe de gravité ÉLEVÉE** : les workflows
GitHub distants utilisent encore l'API Open-Meteo gratuite, alors que BoosterFish
affiche des publicités. Les conditions officielles classent explicitement comme
commerciale une application avec publicité. Les workflows commerciaux corrigés
sont prêts localement, mais leur secret `OPEN_METEO_API_KEY` n'existe pas encore
sur GitHub. Il ne faut pas pousser cette migration avec une clé vide, car les
prévisions expireraient après 72 heures.

Il reste également une opération Play Console manuelle : reporter exactement les
réponses Data Safety, publicité, public cible et suppression de compte préparées
dans `docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md`.

- État général : **très bon techniquement, publication Production bloquée par la licence Open-Meteo**.
- Niveau de risque actuel : **MOYEN**, concentré sur un seul fournisseur et la saisie Play Console.
- Probabilité de réussite technique de l'examen Play après ces deux actions : **environ 93 %**.
- Internal Testing : **prêt techniquement**.
- Closed Testing : **prêt techniquement**, régularisation Open-Meteo à terminer.
- Open Testing : **à promouvoir après la clé commerciale et la fiche Data Safety**.
- Production : **ne pas promouvoir avant les deux actions restantes**.

## Tableau des problèmes encore ouverts

| Gravité | Domaine | Fichier / système | Description | Impact utilisateur | Impact Google Play / légal | Pourquoi c'est un vrai problème | Priorité |
|---|---|---|---|---|---|---|---|
| ÉLEVÉE | Licence / backend météo | GitHub Secrets et branche distante de `Zagorito-coder/Zagorito` | `OPEN_METEO_API_KEY` est absent. Les workflows distants exécutent encore les anciennes sources sur les endpoints gratuits. | Les données fonctionnent aujourd'hui, mais la migration commerciale ne peut pas être activée sans clé ; avec une clé vide, les données deviendraient périmées. | Open-Meteo réserve le service gratuit aux usages non commerciaux et cite les applications avec publicité comme usage commercial. | Secret et versions distantes vérifiés le 21/07/2026 ; seuls `FIREBASE_KEY_JSON` et `FIREBASE_SERVICE_ACCOUNT` sont présents. | P0 avant Production |
| ÉLEVÉE | Google Play Console | Contenu de l'application / Sécurité des données | Les réponses préparées ne peuvent pas être saisies automatiquement sans accès à la fiche Play Console. | Aucun impact dans l'APK. | Une déclaration incomplète ou incohérente avec AdMob/Firebase peut bloquer une mise à jour ou entraîner une mesure coercitive. | Google impose la déclaration des données collectées par le code et les SDK tiers pour les pistes fermée, ouverte et Production. | P0 avant Open/Production |
| FAIBLE | Identité professionnelle | DNS Hostinger `boosterfish.com` | Le domaine pointe vers Hostinger, mais aucun enregistrement MX n'est publié ; `support@boosterfish.com` ne peut donc pas recevoir d'e-mails. | Aucun : `booster2fish@gmail.com` est fonctionnel et publié temporairement. | Pas de refus Play tant que l'adresse Gmail répond réellement. | Vérification DNS : A=`2.57.91.91`, `www` vers le domaine, MX absent. | P2 après la release |

## Corrections réalisées et vérifiées

| Gravité initiale | Domaine | Fichiers principaux | Problème vérifié | Correction réalisée | Preuve / état |
|---|---|---|---|---|---|
| CRITIQUE | Données des spots | `assets/spots.csv.enc`, `tools/*.py`, `lib/services/spot_service.dart` | Le catalogue actif de 170 spots ne contenait pas les 6 195 spots valides du backup chiffré. | Fusion déterministe des 6 195 lignes valides et des 170 nouvelles, puis rechiffrement Release. | 6 365 spots déchiffrés et validés par test Release ; 1 ligne invalide exclue, aucun chevauchement entre les deux sources. |
| ÉLEVÉE | Secrets | `tools/count_spots.py`, `tools/analyze_spots.py`, `tools/merge_spots.py`, `.env.example` | Des clés AES historiques étaient codées en dur dans les outils. | Suppression des clés codées en dur ; clé Release injectée par `.env`/`dart-define`, jamais imprimée. | Recherche globale propre ; SHA-256 de l'asset chiffré `f66ae12868a35bc8bc5c2830ceb38887da3cce8bf06faad91788fb7c33edf748`. |
| ÉLEVÉE | Robustesse des données | `lib/models.dart`, `tools/encrypt_spots.py`, tests | Parsing CSV fragile et risque d'embarquer des coordonnées invalides. | Parsing des champs cités/virgules, validation des colonnes, nombres finis et bornes géographiques avant build. | Tests des virgules, guillemets échappés et ligne mal fermée ; build interrompu si l'asset ne contient pas 6 365 spots valides. |
| ÉLEVÉE | Licence / vie privée | `lib/services/tide_service.dart`, `lib/services/tide_forecast_mapper.dart` | Le mobile contactait directement l'API gratuite Open-Meteo avec les coordonnées de l'utilisateur. | Sélection locale de la station la plus proche, puis lecture de prévisions déjà publiées dans Firestore ; aucune position utilisateur envoyée à Open-Meteo. | Marées affiche Casablanca après déploiement des règles, sans erreur Firestore. Migration backend commerciale prête mais secret encore requis. |
| ÉLEVÉE | Firestore | `firestore.rules`, `.firebaserc` | Les règles devaient être durcies et réellement publiées. | Écritures client interdites sur prévisions/conditions/index ; anciens abonnements non lisibles/non créables et supprimables uniquement par leur propriétaire ; projet CLI verrouillé. | Ruleset `581ff2fc-a6fc-47f7-a5e5-1f863c8e5723` compilé et déployé le 21/07/2026 sur `zagorito-9a0c4`. |
| ÉLEVÉE | Consentement publicitaire | `lib/services/ad_service.dart`, `lib/widgets/adaptive_banner_ad.dart`, `lib/pages/settings_page.dart` | Risque d'initialiser AdMob sans statut UMP valide ou de conserver une annonce après changement du consentement. | `canRequestAds()` est l'autorité unique ; comportement fail-safe, timeouts, destruction des annonces et accès aux préférences UMP. | Une panne UMP n'empêche jamais l'utilisation de l'application ; la politique décrit aussi les annonces limitées/non personnalisées. |
| ÉLEVÉE | Suppression de compte | `lib/services/auth_service.dart`, `firestore.rules`, page légale | Une suppression Firebase pouvait échouer après effacement préalable des données, et le parcours web Play était incomplet. | Réauthentification avant suppression Firestore/Auth, nettoyage local au mieux, parcours dans l'app et lien web direct. | URL publique : `https://zagorito-coder.github.io/boosterfish/privacy-policy/#account-deletion`. |
| ÉLEVÉE | Android / Play | `android/app/build.gradle.kts`, `android/settings.gradle.kts`, wrapper Gradle | Configuration Android antérieure aux exigences 2026. | `compileSdk=36`, `targetSdk=36`, Java/Kotlin 17, AGP 8.11.1, Gradle 8.14, minSdk 24. | APK inspecté : version 1.0.1 (4), compile/target 36, min 24. Google exigera API 36 pour les nouvelles apps/mises à jour à partir du 31/08/2026. |
| ÉLEVÉE | Sécurité réseau | `AndroidManifest.xml` | Le trafic en clair ne devait pas être toléré. | `android:usesCleartextTraffic="false"`; aucun endpoint HTTP applicatif. | Manifeste fusionné et APK inspectés. |
| MOYENNE | Performance carte | `lib/pages/home_page.dart`, services/cache marqueurs | L'aperçu Home construisait jusqu'à 500 marqueurs animés et consommait fortement la mémoire sur appareil modeste. | Échantillon déterministe et réparti de 170 marqueurs sur l'aperçu ; la carte complète conserve les 6 365 spots. | Mesure finale au démarrage : 237 877 Ko PSS / 334 408 Ko RSS. Mesure antérieure : environ 498 Mo PSS / 588 Mo RSS. |
| MOYENNE | Cycle de vie | `lib/services/auth_service.dart`, contrôleurs/pages modifiés | Abonnements et contrôleurs risquaient de survivre aux widgets/services. | Annulation des abonnements et `dispose()` cohérents ; gardes `mounted` autour des opérations asynchrones. | Analyse statique propre et aucun signal de fuite/crash durant les scénarios appareil. |
| MOYENNE | UX / localisation | `assets/lang/*.json`, `test/localization_assets_test.dart` | La carte affichait la clé technique `map.searchHint` au lieu d'un texte traduit. | Traduction ajoutée en français, anglais, espagnol et arabe ; test de parité des catalogues. | 224 clés identiques et non vides dans chaque langue ; libellé « Rechercher… » confirmé sur appareil. |
| MOYENNE | UX hors permission | carte et service de localisation | L'application devait rester utilisable si la localisation était refusée. | Comportement de repli conservé ; aucune dépendance serveur à la position utilisateur. | Refus Android testé sur installation neuve : carte et navigation opérationnelles. |
| MOYENNE | Confidentialité / CGU | `docs/privacy_policy.html`, `docs/terms_of_service.html`, GitHub Pages | Pages distantes obsolètes : absence d'AdMob, ancien Premium, adresse invalide et clause juridique placeholder. | Pages réécrites selon le comportement réel, Open-Meteo commercial, UMP, Firebase, compte et suppression ; contact Gmail temporaire. | Pages publiques servies, datées du 21/07/2026 ; commits Pages `1fe3f83` et `df60075`. |
| MOYENNE | Data Safety | `docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md` | Risque de sous-déclarer AdMob, Firebase Auth, IP, interactions, diagnostics ou identifiants. | Fiche exacte préparée : données collectées/partagées, finalités, caractère facultatif/obligatoire, public cible et autorisations. | Alignée sur la documentation officielle AdMob/Firebase et le manifeste fusionné. |
| MOYENNE | Monétisation | code Premium/Billing et CGU | L'interface et les textes pouvaient laisser croire à un achat/abonnement non implémenté. | Fonctions accessibles gratuitement, absence de Play Billing et textes légaux alignés sur un financement AdMob. | Test de régression : toutes les fonctions historiques restent accessibles sans paiement. |
| FAIBLE | Navigation / accessibilité | pages, shell, widgets | Libellés, retours, contrastes et états de chargement devaient être cohérents dans les quatre langues et thèmes. | États explicites, labels de navigation, dark mode/RTL et contrôles adaptés maintenus/corrigés. | Validation visuelle appareil et analyse des catalogues ; aucun écran bloqué rencontré. |

## Top 10 des risques réels

1. **OUVERT — Licence Open-Meteo commerciale absente.** Risque contractuel réel tant qu'AdMob et les endpoints gratuits coexistent côté backend distant.
2. **OUVERT — Formulaire Data Safety non encore reporté dans Play Console.** Risque direct de refus si la fiche déclare « aucune donnée » malgré AdMob/Firebase.
3. **RÉSOLU — Catalogue de 6 195 spots historiques absent de l'asset actif.** Aurait fortement dégradé la fonction principale.
4. **RÉSOLU — Clés historiques présentes dans les scripts.** Risque d'exposition du matériau de chiffrement du dépôt.
5. **RÉSOLU — Écritures Firestore client insuffisamment verrouillées/déployées.** Risque d'injection de prévisions ou de droits.
6. **RÉSOLU — Consentement AdMob susceptible d'être mal interprété en cas d'erreur UMP.** Risque de non-conformité publicitaire.
7. **RÉSOLU — Suppression de compte non atomique et parcours web incomplet.** Risque de refus Play et de données orphelines.
8. **RÉSOLU — Position envoyée directement au fournisseur météo.** Risque Data Safety et confidentialité supprimé par la sélection locale de station.
9. **RÉSOLU — Pression mémoire excessive de l'aperçu cartographique.** Risque de kill par le système et de jank sur appareils modestes.
10. **RÉSOLU — Libellé technique visible dans la recherche de carte.** Dégradation UX confirmée sur appareil et corrigée dans les quatre langues.

## Validation finale

### Analyse et tests

- `flutter analyze` : **0 problème**.
- `dart analyze` : **0 problème**.
- `flutter test --dart-define-from-file=.env` : **9/9 réussis**.
- Déchiffrement Release : **6 365 spots**.
- Catalogues de langue : **224 clés identiques et non vides** dans 4 langues.

### Artefacts

- AAB : `build/app/outputs/bundle/release/app-release.aab`
  - taille : **71 122 790 octets** ;
  - SHA-256 : `9e33ac240fe743e8168c2e190268b031c9667123420a2be9aa75593946c9895a`.
- APK : `build/app/outputs/flutter-apk/app-release.apk`
  - taille : **69 951 008 octets** ;
  - SHA-256 : `1ea51579fe3fc8e5717f25f5eee50494d853550d07b0f7d5b3cdcd7348181147`.
- Signature APK : valide, schéma v2, certificat SHA-256
  `19368c2c2df86b11c053d0666a1d38a0abe71b9595e3c7fc2da8c8a8d7603f97`.
- R8 et réduction des ressources : actifs.

### Appareil réel

- Appareil : Samsung Galaxy A03s (`SM_A037F`), Android 13.
- Données locales de BoosterFish effacées avant installation.
- APK Release final installé avec succès.
- Démarrage à froid : **3,405 s**.
- Refus de localisation : application utilisable.
- Carte : libellé traduit confirmé.
- Marées après déploiement Firestore : données de Casablanca affichées.
- Logs finaux : aucune `FATAL EXCEPTION`, aucun `ANR`, aucune
  `FirebaseException`, aucun `PERMISSION_DENIED`, aucune exception Flutter non gérée.
- Historique Android : seulement des arrêts volontaires liés à `pm clear` et aux
  installations ; aucun ANR recensé.
- Mémoire finale : **237 877 Ko PSS / 334 408 Ko RSS**.

## Références de conformité

- [Google Play — Sécurité des données](https://support.google.com/googleplay/android-developer/answer/10787469?hl=fr)
- [Google Play — Suppression de compte](https://support.google.com/googleplay/android-developer/answer/13327111?hl=fr)
- [Google Play — Exigences de niveau d'API cible](https://support.google.com/googleplay/android-developer/answer/11926878?hl=fr)
- [Google Mobile Ads — données collectées](https://developers.google.com/admob/android/privacy/play-data-disclosure)
- [Firebase Android — données collectées](https://firebase.google.com/docs/android/play-data-disclosure)
- [Open-Meteo — conditions](https://open-meteo.com/en/terms)
- [Open-Meteo — offre commerciale](https://open-meteo.com/en/pricing)

## Actions finales obligatoires

1. Souscrire au minimum au plan Open-Meteo **Standard**. Le backend actuel fait
   environ 46 066 appels de base par mois, très inférieur au budget Standard de
   1 million d'appels mensuels.
2. Ajouter la clé comme secret GitHub Actions `OPEN_METEO_API_KEY` sans la placer
   dans le dépôt ni dans une conversation.
3. Pousser les fichiers backend/workflows commerciaux déjà préparés, lancer les
   deux workflows manuellement, puis confirmer leur succès et la fraîcheur
   Firestore.
4. Reporter `docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md` dans Play Console, utiliser
   l'URL de suppression avec `#account-deletion`, puis importer l'AAB audité.
5. Attendre le rapport de pré-lancement et vérifier Android vitals avant de
   promouvoir Closed → Open → Production.

## Conclusion obligatoire

Je ne publierais pas cette application en Production dans son état actuel.

Justification technique concise : le binaire est stable et les protections sont
en place, mais l'absence de licence/clé Open-Meteo commerciale maintient un risque
juridique vérifié pour une application avec publicité. Dès que le secret est ajouté,
les workflows corrigés validés et la fiche Data Safety saisie, ce blocage disparaît.

## Notes sur 100

- Architecture : **87/100**
- Qualité Flutter : **90/100**
- Performance : **87/100**
- Sécurité : **92/100**
- UX : **91/100**
- Conformité Google Play : **78/100** actuellement, **94/100** après les deux actions P0
- Maintenabilité : **88/100**
- Score Global de Production : **86/100** actuellement, **91/100** après régularisation Open-Meteo et saisie Play Console
