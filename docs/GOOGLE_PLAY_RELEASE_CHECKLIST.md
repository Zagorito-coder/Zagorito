# BoosterFish — fiche de publication Google Play

Version auditée : **1.0.3 (6)**
Dernière mise à jour : **30 juillet 2026**

Cette fiche décrit l'état réel de l'application et les réponses à reporter dans
Google Play Console. Toute modification future des SDK, de l'authentification,
de la publicité ou de la transmission de la localisation impose de réviser cette
fiche et la politique de confidentialité.

## URLs publiques

- Politique de confidentialité :
  `https://zagorito-coder.github.io/boosterfish/privacy-policy/`
- Conditions d'utilisation :
  `https://zagorito-coder.github.io/boosterfish/terms-of-service/`
- Suppression de compte :
  `https://zagorito-coder.github.io/boosterfish/privacy-policy/#account-deletion`
  (section dédiée, étapes dans l'application et lien de demande sans
  réinstallation).
- Contact temporaire : `booster2fish@gmail.com`
- Contact professionnel prévu après configuration Hostinger :
  `support@boosterfish.com`

Les pages publiques doivent être republiées avant l'envoi en examen afin que
leur contenu corresponde aux fichiers `docs/` de cette version.

## Présence publicitaire et accès

- **Contient des annonces : Oui.** L'application intègre Google Mobile Ads et
  UMP.
- **Achats intégrés / abonnements : Non.** Aucun produit Play Billing n'est
  proposé et aucune bibliothèque Billing n'est intégrée.
- **Accès à l'application :** sélectionner que **tout ou partie des
  fonctionnalités est restreinte**. Les fonctions principales et le fil public
  sont accessibles sans compte, mais la galerie privée, les spots personnels
  et la publication communautaire nécessitent Google Sign-In.
- Avant l'envoi en examen, créer un **compte Google dédié aux reviewers**,
  réutilisable, valide depuis tout pays, sans validation en deux étapes, OTP,
  appareil de confiance ni mot de passe expirant. Saisir ses identifiants
  uniquement dans le champ sécurisé « Accès à l'application » de Play Console
  et fournir en anglais les étapes : ouvrir l'application, accéder à
  Communauté/Mes prises ou Mes spots, choisir Google Sign-In, puis utiliser le
  compte fourni. Ne jamais enregistrer ces identifiants dans Git, un ticket, un
  rapport ou cette checklist.
- **Création de compte : Oui, facultative**, via Google Sign-In et Firebase Auth.
- **Suppression de compte : Oui**, dans Paramètres > Confidentialité, avec
  réauthentification Google ; demande externe possible depuis l'URL publique.
- **Public visé :** sélectionner `16–17 ans` et `18 ans et plus`, conformément à
  la politique actuelle. Ne pas déclarer l'application comme destinée aux
  enfants.

## Sécurité des données — réponses générales

- L'application collecte-t-elle ou partage-t-elle des données utilisateur ?
  **Oui.**
- Toutes les données sont-elles chiffrées en transit ? **Oui**, les services
  utilisés sont appelés en HTTPS/TLS et le trafic HTTP en clair est bloqué dans
  le manifeste Android.
- Les utilisateurs peuvent-ils demander la suppression de leurs données ?
  **Oui.**
- Les données sont-elles traitées de manière éphémère uniquement ? **Non** pour
  les données de compte ; ne pas cocher une exemption globale éphémère.

## Types de données à déclarer

| Catégorie Play | Données réellement concernées | Collectées | Partagées | Obligatoire / facultatif | Finalités à cocher |
|---|---|---:|---:|---|---|
| Informations personnelles — nom | Nom d'affichage Google, affiché avec une prise publiée | Oui | Oui pour une publication volontaire | Facultatif, seulement avec connexion/publication | Fonctionnalité de l'application ; gestion du compte |
| Informations personnelles — adresse e-mail | Adresse du compte Google | Oui | Non¹ | Facultatif, seulement avec connexion | Fonctionnalité de l'application ; gestion du compte |
| Identifiants utilisateur | UID Firebase | Oui | Non¹ | Facultatif, seulement avec connexion | Fonctionnalité de l'application ; gestion du compte ; sécurité/prévention des abus |
| Photos et vidéos — photos | Photo de profil Google ; photo de prise publiée volontairement | Oui | Oui pour une publication volontaire | Facultatif | Fonctionnalité de l'application ; gestion du compte |
| Localisation précise | Coordonnées d'un spot personnel synchronisé dans l'espace privé ; coordonnées des tuiles de la zone affichée lorsqu'une carte en ligne est centrée sur la position de l'appareil | Oui | Oui pour les fournisseurs de cartes en ligne ; non¹ pour Firestore | Facultatif, après autorisation ou action de l'utilisateur | Fonctionnalité de l'application |
| Localisation approximative | Zone d'environ 5 km d'une prise publiée ; estimation par adresse IP de Google Mobile Ads, Firebase Auth et Cloud Functions | Oui | Oui pour Google Mobile Ads ; non¹ pour Firebase | Facultative pour la communauté ; requise lors de l'authentification, des appels serveur ou de la diffusion d'annonces | Fonctionnalité de l'application ; gestion du compte ; publicité ou marketing ; analyses ; prévention de la fraude, sécurité et conformité |
| Activité dans l'application — interactions | Likes, blocages, signalements, lancements et interactions avec l'application ou les annonces | Oui | Oui pour les signaux publicitaires ; seul le total des likes est public | Facultatif pour la communauté ; requis lorsque les annonces sont diffusées | Fonctionnalité de l'application ; analyses ; sécurité/prévention des abus ; publicité ou marketing |
| Autres contenus générés par les utilisateurs | Espèce, poids, zone, montage, appât, notes et conseil associés à une prise publiée ; informations d'un spot personnel | Oui | Oui pour une publication volontaire | Facultatif | Fonctionnalité de l'application ; sécurité/prévention des abus |
| Informations sur l'application et performances — journaux de plantage | Piles de crash et ANR Firebase Crashlytics, état technique pertinent de l'application | Oui | Non¹ | Requise dans la version Release | Analyses |
| Informations sur l'application et performances — diagnostics | Métadonnées techniques Crashlytics ; temps de lancement, blocages, consommation d'énergie et diagnostics du SDK publicitaire | Oui | Oui pour les signaux publicitaires ; non¹ pour Crashlytics | Requise dans la version Release et lorsque les annonces sont diffusées | Analyses ; prévention de la fraude, sécurité et conformité ; publicité ou marketing |
| Appareil ou autres identifiants | Identifiant publicitaire Android, App Set ID et identifiants de compte publicitaire ; jeton FCM transmis par le client Cloud Functions ; UUID d'installation Crashlytics et jeton d'intégrité App Check/Play Integrity | Oui | Oui pour Google Mobile Ads ; non¹ pour Firebase | Requise lorsque les annonces, le diagnostic Release, l'attestation ou les appels serveur sont utilisés | Fonctionnalité de l'application ; publicité ou marketing ; analyses ; prévention de la fraude, sécurité et conformité |

¹ Firebase Auth, Google Sign-In et Firebase Crashlytics sont utilisés comme
prestataires de service respectivement pour l'authentification et le diagnostic.
Cette transmission n'est pas déclarée comme un « partage » si l'exception
fournisseur de services de Google Play s'applique à la configuration
contractuelle du compte développeur. Si une donnée est réutilisée par un
destinataire pour ses propres finalités, la déclarer aussi comme partagée.

### Données locales ou non transmises

- La position exacte associée à une prise de la galerie privée reste sur
  l'appareil. Lors d'une publication, seule une cellule d'environ 5 km est
  envoyée. La galerie privée de 20 prises n'est jamais synchronisée ni publiée
  automatiquement.
- La position utilisée pour centrer la carte, calculer les distances et choisir
  localement une station de prévisions n'est pas envoyée à Open-Meteo. Les
  coordonnées d'un spot personnel sont toutefois synchronisées dans Firestore
  lorsque l'utilisateur choisit de créer ce spot ; c'est pourquoi la
  localisation précise doit être déclarée comme collecte facultative. Lorsqu'une
  carte en ligne est centrée sur la position, les coordonnées des tuiles
  nécessaires à la zone affichée sont transmises au fournisseur cartographique ;
  par prudence, déclarer aussi la localisation précise comme partagée pour la
  fonctionnalité de l'application.
- Aucun mot de passe Google, donnée bancaire, contact, message, donnée de santé,
  fichier personnel ou historique d'achat n'est collecté par l'application.
- Firebase Crashlytics collecte les crashs et ANR techniques uniquement dans la
  version Release. Aucun UID Firebase, nom, e-mail, emplacement, nom de spot,
  note, photo, journal personnalisé ni événement Google Analytics n'est ajouté
  aux rapports. Les identifiants et rapports Crashlytics sont conservés 90
  jours selon la documentation Firebase.

Les fournisseurs de cartes reçoivent néanmoins les coordonnées des tuiles de la
zone affichée ainsi que des données techniques réseau. Cette information est
décrite dans la politique de confidentialité ; elle doit être réévaluée si un
fournisseur ou un SDK de cartographie est ajouté.

## Autorisations et déclarations

- `INTERNET` : cartes, Firestore, authentification et publicité.
- `ACCESS_COARSE_LOCATION` et `ACCESS_FINE_LOCATION` : uniquement lorsque
  l'utilisateur demande le centrage, une fonction de proximité ou
  l'enregistrement privé du lieu d'une prise ; aucune localisation en
  arrière-plan.
- Ne pas déclarer de localisation en arrière-plan, de caméra, microphone,
  contacts, téléphone, stockage partagé ou notifications : ces autorisations ne
  figurent pas dans le manifeste source. Les images sont choisies avec le
  sélecteur système sans autorisation générale sur le stockage.
- Si Play Console demande la justification de la localisation, indiquer :
  « Centrer la carte sur l'utilisateur, calculer la distance aux spots et choisir
  localement la station météo/marine publique la plus proche. L'utilisateur peut
  aussi enregistrer le lieu exact d'une prise dans sa galerie privée ; seule une
  zone d'environ 5 km est envoyée s'il décide de publier cette prise. »

## Déclarations supplémentaires

- **Identifiant publicitaire : Oui**, utilisé par Google Mobile Ads ; le SDK
  apporte l'autorisation correspondante dans le manifeste fusionné.
- **App d'actualité : Non.**
- **App de santé : Non.**
- **Fonctionnalités financières : Non.**
- **Application gouvernementale : Non.**
- **COVID-19 : Non.**
- **Contenu généré par les utilisateurs : Oui.** Déclarer le partage de photos
  et d'informations de pêche, les likes, le signalement intégré, le blocage, la
  modération et le retrait par l'auteur.
- **Standards de sécurité des mineurs :** même si l'application reste classée
  dans la catégorie Sports, sa fonction communautaire publie des photos et
  profils. Utiliser l'ancre publique
  `https://zagorito-coder.github.io/boosterfish/terms-of-service/#child-safety`,
  certifier le signalement intégré (motif dédié « Sécurité ou exploitation d'un
  mineur »), le retrait des contenus CSAM connus et leur signalement aux
  autorités compétentes selon le droit applicable. Désigner dans Play Console
  un responsable nominatif capable de traiter ces alertes ; l'adresse de
  contact actuelle est `booster2fish@gmail.com`.
- **Classement du contenu :** refaire le questionnaire en déclarant le contenu
  généré par les utilisateurs, la présence de publicité et les
  liens/contacts externes réels.
- **Play Integrity :** intégré via Firebase App Check. En Android Release,
  l'application utilise `AndroidPlayIntegrityProvider`; le fournisseur Debug
  n'est utilisé qu'en build de développement. Le SHA-256 du certificat Play
  App Signing est enregistré dans Firebase. L'enforcement reste désactivé
  jusqu'à validation d'une installation distribuée par Google Play en Internal
  Testing, puis doit être activé progressivement sur Firestore, Storage et
  Functions.
- **Crashlytics :** intégré uniquement pour la version Release, sans Analytics,
  identifiant utilisateur, clé personnalisée ni journal applicatif. Dans la
  console Firebase, désactiver le partage optionnel « Crash Insights » avant la
  production si vous ne souhaitez pas contribuer les piles anonymisées aux
  comparaisons globales.

## Contrôles avant chaque envoi

1. Vérifier que les deux URLs légales publiques répondent sans connexion et
   affichent la même date, les mêmes SDK et la même adresse que les fichiers du
   dépôt.
2. Vérifier que le compte Google reviewer dédié fonctionne sans 2FA/OTP sur un
   appareil ou profil où il n'était pas déjà connecté, puis renseigner
   « Accès à l'application » en anglais.
3. Vérifier que la fiche « Sécurité des données », la déclaration publicitaire
   et le public cible correspondent exactement à cette fiche. Si Play Console
   affiche la déclaration « Standards de sécurité des mineurs », renseigner
   l'URL ancrée, le contact nominatif et les certifications décrites ci-dessus.
4. Télécharger l'AAB signé correspondant au `versionCode` attendu, puis vérifier
   dans l'App Bundle Explorer les autorisations et SDK détectés.
5. Installer l'APK release sur un appareil propre, refuser puis accepter les
   choix UMP, tester la localisation refusée/acceptée, la connexion et la
   suppression du compte. Tester aussi l'import privé, la publication avec une
   photo de moins de 2 Mo, le like depuis un second compte, le signalement, le
   blocage et le retrait par l'auteur. Pour valider Play Integrity et l'envoi
   Cloudflare protégé par App Check, installer l'AAB depuis Google Play Internal
   Testing : un APK installé par câble n'est pas une preuve d'attestation Play
   valide.
6. Consulter les rapports de pré-lancement, Android vitals, ANR et crashs avant
   de promouvoir la version vers une piste plus large.

## Sources officielles

- Google Play — formulaire Sécurité des données :
  <https://support.google.com/googleplay/android-developer/answer/10787469>
- Google Play — suppression de compte :
  <https://support.google.com/googleplay/android-developer/answer/13327111>
- Google Play — contenu généré par les utilisateurs :
  <https://support.google.com/googleplay/android-developer/answer/9876937>
- Google Play — standards de sécurité des mineurs :
  <https://support.google.com/googleplay/android-developer/answer/14747720>
- Google Play — identifiants et instructions d'accès pour la revue :
  <https://support.google.com/googleplay/android-developer/answer/15748846>
- Google Mobile Ads — divulgation des données :
  <https://developers.google.com/admob/android/privacy/play-data-disclosure>
- Firebase Android — divulgation des données :
  <https://firebase.google.com/docs/android/play-data-disclosure>
- Google Play — exigences de niveau d'API cible :
  <https://support.google.com/googleplay/android-developer/answer/11926878>
