# BoosterFish — Rapport de préparation iOS

Date de l'audit : 13 août 2026
Projet audité : `/Users/salimben/Desktop/Projets/spots_app`
Périmètre : application iOS uniquement. Le site web et le dossier CNDP sont exclus.

## 1. Conclusion exécutive

BoosterFish est désormais **compilable pour un appareil iPhone en mode Release sans signature**. Le projet Flutter, Xcode, les ressources natives iOS, Firebase et les tests automatisés sont cohérents.

L'application n'est toutefois **pas encore prête à être envoyée sur l'App Store**. Les principaux blocages restants sont :

1. absence actuelle de compte/certificat Apple de signature sur ce Mac ;
2. absence d'iPhone détecté pour le test physique ;
3. ajout nécessaire d'une connexion conforme à la règle Apple 4.8, en pratique « Se connecter avec Apple », puisque Google Sign-In sert à créer ou authentifier le compte principal ;
4. audit final de confidentialité iOS et préparation des déclarations App Store Connect ;
5. décision et validation du support iPad et du mode paysage ;
6. validation complète de Firebase App Check, Google Sign-In et des fonctions communautaires sur un vrai iPhone.

Verdict par niveau :

| Niveau | État | Conclusion |
|---|---:|---|
| Compilation iOS locale | Vert | Réussie pour `arm64`, sans signature |
| Configuration native | Vert | Nom, icônes, langues, Firebase et URL Google cohérents |
| Tests automatisés | Vert | 177 tests réussis, 1 test volontairement ignoré |
| Analyse statique | Vert | Aucune anomalie Flutter détectée |
| Installation sur iPhone | Bloquée extérieurement | Aucun iPhone et aucune identité de signature détectés |
| TestFlight | Non disponible | Abonnement Apple Developer requis |
| Soumission App Store | Non prête | Connexion Apple, confidentialité et validation physique à terminer |

## 2. Point important : iOS n'utilise pas les APK

Un iPhone ne peut pas installer un fichier Android `.apk` ou `.aab`.

Les formats iOS sont :

- `.app` : application compilée, utilisée notamment par Xcode ;
- `.ipa` : archive iOS qui doit être signée et provisionnée correctement ;
- TestFlight : canal Apple de distribution de test, réservé au programme développeur payant.

L'artefact actuellement présent est :

`build/ios/iphoneos/Runner.app`

Il est compilé pour un appareil réel `arm64`, mais il n'est pas signé. Le copier dans le stockage de l'iPhone ne permet donc pas de l'installer. iOS impose une signature et un profil de provisionnement valides.

## 3. Test gratuit sur votre propre iPhone

Un abonnement annuel n'est pas nécessaire pour un test personnel sur votre propre iPhone. Un compte Apple gratuit peut être utilisé dans Xcode avec une « Personal Team ».

Limites officielles du compte gratuit :

- installation uniquement pour le développement personnel ;
- profil valable sept jours ;
- réinstallation ou nouvelle signature nécessaire après expiration ;
- jusqu'à trois appareils de test par plateforme et dix App IDs actifs, avec les limites Apple en vigueur ;
- aucune distribution TestFlight ou App Store.

### Préparation du téléphone

1. Utiliser un iPhone compatible avec iOS 15 ou une version supérieure.
2. Le connecter d'abord au Mac avec un câble USB.
3. Déverrouiller l'iPhone et accepter « Faire confiance à cet ordinateur ».
4. Activer **Réglages > Confidentialité et sécurité > Mode développeur**.
5. Redémarrer l'iPhone si iOS le demande, puis confirmer le mode développeur.

### Préparation de Xcode

1. Ouvrir Xcode.
2. Aller dans **Xcode > Settings > Accounts**.
3. Ajouter le compte Apple utilisé pour le test.
4. Ouvrir `ios/Runner.xcworkspace`, et non `Runner.xcodeproj`.
5. Sélectionner la cible **Runner > Signing & Capabilities**.
6. Activer **Automatically manage signing**.
7. Choisir la **Personal Team** du compte Apple.
8. Conserver le Bundle ID `com.zagorito.boosterfish`, afin de ne pas désynchroniser Firebase et Google Sign-In.

### Lancement conforme aux règles du dépôt

Ne jamais lancer directement `flutter run` dans ce projet. Après détection de l'iPhone :

```bash
flutter devices
tools/run_app.sh --profile -d <identifiant-iphone>
```

Le script vérifie `.env`, la clé de chiffrement et les 6 000+ spots officiels avant de remplacer une application déjà installée.

### Firebase App Check pendant ce test

Les builds Debug et Profile iOS utilisent volontairement le fournisseur App Check de développement. Lors du premier lancement :

1. relever le jeton App Check de debug dans la console Xcode ;
2. l'enregistrer temporairement dans **Firebase Console > App Check > application iOS > Manage debug tokens** ;
3. ne jamais placer ce jeton dans Git, une capture publique ou le code ;
4. supprimer le jeton de Firebase lorsque les tests sont terminés.

Sans cette étape, les fonctions protégées peuvent afficher « vérification de sécurité indisponible » si App Check est appliqué sur le backend.

## 4. Configuration iOS confirmée

### Identité et compatibilité

- Nom affiché : `BoosterFish`.
- Bundle ID : `com.zagorito.boosterfish`.
- Version locale : `1.0.6 (14)`.
- Architecture de l'artefact : `arm64`.
- Version iOS minimale : `15.0`.
- Cibles actuelles : iPhone **et** iPad.
- Orientations iPhone déclarées : portrait et paysage gauche/droite.
- Orientations iPad déclarées : portrait, portrait inversé et paysages.

### Firebase et Google Sign-In

- La configuration Flutter iOS correspond maintenant au fichier Firebase natif.
- `GoogleService-Info.plist` est bien inclus dans les ressources de la cible Runner.
- Le Bundle ID Firebase correspond au Bundle ID Xcode.
- Le schéma URL Google correspond à `REVERSED_CLIENT_ID`.
- Un test automatique protège ces correspondances contre une future régression.

### Autorisations natives

Les textes système sont présents en français, anglais, arabe et espagnol pour :

- la localisation pendant l'utilisation ;
- l'accès à une photo choisie ;
- l'appareil photo.

Ces autorisations devront être testées dans les quatre langues, en acceptation et en refus.

### Icône

Toutes les icônes iOS du catalogue AppIcon ont été rendues opaques, sans canal alpha, y compris l'icône App Store 1024 × 1024. Ce point évite une erreur classique de validation App Store.

### Publicité

Les identifiants actuellement présents sont Android. Pour éviter un crash ou une mauvaise configuration, la publicité est volontairement désactivée sur iOS tant qu'une application AdMob iOS et ses propres identifiants n'existent pas.

Cette solution est sûre pour les essais iOS et pour une première version iOS sans publicité. Si la publicité est ajoutée plus tard, il faudra :

1. créer une application iOS séparée dans AdMob ;
2. créer des unités publicitaires iOS ;
3. ajouter le `GADApplicationIdentifier` iOS ;
4. auditer le consentement UMP, le suivi et l'éventuelle nécessité d'ATT ;
5. vérifier que les déclarations App Store correspondent exactement au comportement réel.

Ne jamais réutiliser les identifiants Android sur iOS.

## 5. Points conformes ou déjà présents

- L'application peut fonctionner partiellement sans connexion et réserve les fonctions de compte aux utilisateurs connectés.
- La suppression du compte existe dans l'application et supprime l'identité ainsi que les données associées prévues par le flux actuel.
- Les contenus communautaires disposent déjà des parcours de signalement et de blocage exigés pour une application avec contenu utilisateur.
- Les liens de confidentialité et de support sont disponibles sur `https://www.boosterfish.com/`.
- App Transport Security n'autorise pas arbitrairement le trafic HTTP non sécurisé.
- Aucun achat intégré ou abonnement payant n'est implémenté dans les dépendances actuelles.
- Le fournisseur « premium » actuel ouvre les fonctions sans achat ; il n'existe donc pas, à ce stade, de flux de paiement numérique à déclarer à Apple.

## 6. Blocages à résoudre avant l'App Store

### 6.1 Adhésion Apple Developer

Le programme Apple Developer coûte officiellement 99 USD par année, ou l'équivalent local lorsqu'il est proposé.

Le type d'adhésion doit être choisi avant l'inscription :

- **Individuel** : le nom légal personnel du titulaire apparaît comme vendeur sur l'App Store ;
- **Organisation** : le nom de l'entité juridique apparaît comme vendeur et un numéro D‑U‑N‑S est généralement requis.

Si l'objectif est d'afficher une société ou la marque BoosterFish comme vendeur plutôt qu'un nom personnel, cette décision doit être traitée avant l'inscription.

### 6.2 « Se connecter avec Apple » — blocage de revue

BoosterFish utilise Google Sign-In pour le compte principal. La règle Apple 4.8 impose alors une option de connexion équivalente qui limite les données au nom et à l'adresse e-mail, permet de masquer l'adresse e-mail et n'utilise pas les interactions à des fins publicitaires sans consentement.

La solution normale est **Sign in with Apple**. Elle devra être ajoutée avant une soumission App Store, avec :

- capacité Apple activée sur l'App ID ;
- configuration du fournisseur Apple dans Firebase Authentication ;
- bouton Apple conforme aux règles visuelles Apple ;
- liaison correcte avec Firebase Auth ;
- suppression et réauthentification compatibles pour les comptes Apple ;
- tests du choix « Masquer mon adresse e-mail » ;
- vérification des collisions de comptes Google/Apple utilisant la même adresse.

Cette fonction demande l'adhésion payante Apple et ne doit pas être simulée avec un compte gratuit.

### 6.3 Confidentialité iOS et App Store Connect

Le bundle compilé contient les manifestes de confidentialité fournis par de nombreux SDK tiers, mais le projet n'a pas encore un dossier de décision final pour son propre manifeste `PrivacyInfo.xcprivacy`.

Avant soumission :

1. générer le rapport de confidentialité avec Xcode ;
2. vérifier les API à justification obligatoire réellement utilisées par l'application et ses SDK ;
3. ajouter ou compléter un manifeste propre à Runner lorsque requis par le rapport ;
4. remplir les « App Privacy Details » d'App Store Connect à partir du comportement réel ;
5. comparer ces déclarations avec la politique publiée sur BoosterFish ;
6. ne déclarer ni moins ni plus que ce que le binaire et le backend font réellement.

Catégories à auditer au minimum :

- position précise et approximative ;
- nom, adresse e-mail, identifiant Firebase et photo de profil ;
- photos de prises et de spots ;
- contenu généré par l'utilisateur ;
- interactions avec l'application ;
- diagnostics et journaux de crash ;
- identifiants de l'appareil utilisés par Firebase/App Check ou les SDK ;
- données locales hors ligne ;
- données envoyées à Firebase, Cloudflare/R2, Open-Meteo et autres fournisseurs réels.

### 6.4 Crashlytics iOS

Le code actuel active Crashlytics uniquement pour une Release Android. La collecte est donc désactivée sur iOS, même en Release.

Ce choix ne bloque pas la compilation, mais une publication professionnelle devrait disposer d'une surveillance iOS minimale et respectueuse de la vie privée :

- activer explicitement Crashlytics pour la Release iOS ;
- conserver l'absence de noms, e-mails, coordonnées, textes utilisateur et URL de tuiles dans les rapports ;
- configurer et vérifier l'envoi des dSYM ;
- provoquer un crash contrôlé sur TestFlight ;
- confirmer sa présence dans Firebase Crashlytics ;
- aligner cette collecte avec App Store Connect et la politique de confidentialité.

### 6.5 App Check de production

La Release iOS utilise actuellement `DeviceCheck`, ce qui est cohérent comme fournisseur de production. Après l'adhésion Apple :

- enregistrer correctement l'application iOS dans App Check ;
- configurer les éléments Apple nécessaires ;
- distribuer une première build TestFlight ;
- vérifier Auth, Firestore, Functions et les uploads protégés ;
- activer l'application des règles service par service seulement après validation des métriques.

### 6.6 iPad et mode paysage

La cible actuelle annonce une compatibilité iPhone et iPad, avec plusieurs orientations. Cela oblige à tester les interfaces lourdes — carte, marées, communauté, fiches et formulaires — sur ces formats.

Deux stratégies professionnelles sont possibles :

- conserver iPhone + iPad et effectuer une vraie campagne de validation iPad/landscape ;
- limiter la première version à l'iPhone si aucun test iPad sérieux n'est prévu.

Il ne faut pas annoncer une compatibilité iPad complète sans l'avoir testée. Cette décision doit être prise avant la création finale de la fiche App Store.

### 6.7 Swift Package Manager et boussole

La compilation réussit, mais Flutter signale que `flutter_compass` ne prend pas encore en charge Swift Package Manager. Ce n'est pas un blocage actuel. Il faudra néanmoins :

- surveiller les mises à jour du package ;
- tester le cap magnétique sur plusieurs iPhone ;
- préparer une migration si une future version de Flutter transforme cet avertissement en erreur.

## 7. Tests physiques obligatoires avant TestFlight

### Installation et cycle de vie

- installation propre ;
- démarrage à froid ;
- redémarrage après fermeture forcée ;
- retour depuis l'arrière-plan ;
- mode avion puis reconnexion ;
- stockage presque plein ;
- suppression/réinstallation ;
- aucune boucle de splash ou écran blanc.

### Compte et sécurité

- navigation sans connexion ;
- Google Sign-In ;
- restauration de session ;
- déconnexion ;
- suppression du compte ;
- App Check accepté ;
- comportement propre si App Check, Firebase ou le réseau est indisponible.

### Carte et capteurs

- autorisation localisation acceptée/refusée ;
- position et recentrage ;
- cap magnétique et course GPS distincts ;
- zoom, tuiles satellite, replis 18/17/16 et absence de tuiles blanches ;
- spots officiels et personnels ;
- téléchargement, lecture et suppression de carte hors ligne ;
- relance sans réseau avec une carte déjà téléchargée.

### Marées et météo

- dix jours réellement disponibles ;
- changement ville/pays ;
- courbe, extrêmes, activité horaire et conditions marines ;
- absence de valeurs fabriquées lorsque la donnée est indisponible ;
- lisibilité en mode clair/sombre et portrait/paysage.

### Communauté

- ajout de prise avec photo ;
- like et retrait du like ;
- signalement ;
- blocage et déblocage ;
- retrait/suppression ;
- zones approximatives ;
- limites de publication et messages d'erreur exacts.

### Autorisations et accessibilité

- appareil photo accepté/refusé ;
- galerie acceptée/refusée ;
- textes système en FR, EN, ES et AR ;
- taille de texte augmentée ;
- VoiceOver sur les contrôles importants ;
- contraste en clair et sombre.

## 8. Préparation App Store Connect après adhésion

1. Créer l'identifiant Apple de l'application avec `com.zagorito.boosterfish`.
2. Activer les capacités nécessaires, notamment Sign in with Apple et DeviceCheck/App Check.
3. Configurer signature automatique, certificats et profils.
4. Créer l'enregistrement App Store Connect avec le même Bundle ID.
5. Choisir une nouvelle version et incrémenter le numéro de build à chaque envoi.
6. Préparer les métadonnées FR, EN, ES et AR.
7. Fournir politique de confidentialité, support et suppression de compte.
8. Remplir les déclarations de confidentialité et de chiffrement/exportation.
9. Préparer les captures réelles des appareils et formats officiellement pris en charge.
10. Fournir à App Review un compte de démonstration pleinement fonctionnel si nécessaire.
11. Maintenir Firebase, Cloudflare/R2 et les autres backends accessibles pendant la revue.
12. Décrire dans les notes de revue les fonctions de localisation, météo, carte hors ligne, communauté, signalement et suppression de compte.
13. Envoyer d'abord sur TestFlight interne.
14. Valider la build téléchargée depuis TestFlight sur plusieurs iPhone.
15. N'envoyer à l'examen qu'après une checklist complète sans blocage.

## 9. État de l'environnement local au 13 août 2026

- Flutter : `3.44.4` stable.
- Dart : `3.12.2`.
- Xcode : `26.6`.
- CocoaPods : `1.16.2`.
- macOS : `26.5.2`.
- Identités Apple valides détectées : `0`.
- Appareils Flutter détectés : macOS et Chrome uniquement.
- Deux appareils Apple sont visibles sur le réseau mais non connectables : l'iPad et l'iPhone « AP-PC » doivent être déverrouillés, connectés par câble ou au même réseau, et placés en mode développeur.

## 10. Validations réalisées

- `flutter analyze` : **aucune anomalie**.
- `flutter test --dart-define-from-file=.env` : **177 tests réussis, 1 ignoré volontairement**.
- build iOS Release sans signature : **réussi**.
- application produite : `build/ios/iphoneos/Runner.app`.
- architecture : **Mach-O arm64**.
- nom, Bundle ID, version et version iOS minimale vérifiés dans l'artefact.
- icônes sans canal alpha vérifiées automatiquement.
- configuration Firebase native incluse dans l'artefact.

## 11. Ordre recommandé des prochaines actions

### Maintenant, sans payer

1. connecter et préparer un iPhone physique ;
2. ajouter le compte Apple gratuit dans Xcode ;
3. signer avec Personal Team ;
4. enregistrer temporairement le jeton App Check de test ;
5. installer avec `tools/run_app.sh --profile -d <identifiant-iphone>` ;
6. exécuter la checklist physique ci-dessus ;
7. corriger uniquement les défauts réellement observés sur iPhone.

### Avant de payer

1. choisir adhésion individuelle ou organisation ;
2. décider iPhone seul ou iPhone + iPad ;
3. préparer la conception de Sign in with Apple ;
4. préparer la matrice de confidentialité App Store ;
5. confirmer que la première version iOS restera sans publicité.

### Après l'adhésion Apple Developer

1. activer Sign in with Apple et DeviceCheck ;
2. finaliser la signature de distribution ;
3. finaliser confidentialité, Crashlytics iOS et dSYM ;
4. créer App Store Connect ;
5. produire une Archive Release signée ;
6. tester sur TestFlight ;
7. seulement ensuite préparer l'envoi à l'examen.

## 12. Références officielles

- Apple — adhésion et test gratuit : https://developer.apple.com/support/compare-memberships/
- Apple — règles de revue : https://developer.apple.com/app-store/review/guidelines/
- Apple — manifestes de confidentialité : https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Apple — envoi des builds : https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- Firebase — Google Sign-In sur Apple : https://firebase.google.com/docs/auth/ios/google-signin
- Firebase — App Check en développement : https://firebase.google.com/docs/app-check/flutter/debug-provider

## 13. Limites de ce rapport

Ce rapport confirme la configuration et la compilation locales observées le 13 août 2026. Il ne remplace pas :

- un test sur un vrai iPhone ;
- une Archive signée et sa validation Xcode ;
- le traitement du binaire par App Store Connect ;
- la revue humaine d'Apple ;
- un conseil juridique sur les déclarations de confidentialité ou d'exportation.

Aucune publication, inscription Apple, création de certificat, installation sur iPhone, modification App Store Connect, génération d'IPA signée, ni activation de service de production n'a été effectuée pendant cet audit.
