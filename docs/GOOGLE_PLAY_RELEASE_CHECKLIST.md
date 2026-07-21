# BoosterFish — fiche de publication Google Play

Version auditée : **1.0.1 (4)**  
Dernière mise à jour : **21 juillet 2026**

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
- **Accès à l'application :** les fonctions principales sont accessibles sans
  compte ; ne fournir aucun identifiant de test dans la section « Accès à
  l'application ».
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
| Informations personnelles — nom | Nom d'affichage Google | Oui | Non¹ | Facultatif, seulement avec connexion | Fonctionnalité de l'application ; gestion du compte |
| Informations personnelles — adresse e-mail | Adresse du compte Google | Oui | Non¹ | Facultatif, seulement avec connexion | Fonctionnalité de l'application ; gestion du compte |
| Identifiants utilisateur | UID Firebase | Oui | Non¹ | Facultatif, seulement avec connexion | Fonctionnalité de l'application ; gestion du compte ; sécurité/prévention des abus |
| Photos et vidéos — photos | Photo de profil Google ou son URL | Oui | Non¹ | Facultatif, seulement avec connexion | Personnalisation/fonctionnalité de l'application ; gestion du compte |
| Localisation approximative | Estimation par l'adresse IP du SDK Google Mobile Ads | Oui | Oui | Requise lorsque les annonces sont autorisées/diffusées | Publicité ou marketing ; analyses ; prévention de la fraude, sécurité et conformité |
| Activité dans l'application — interactions | Lancements, interactions avec l'application et les annonces | Oui | Oui | Requise lorsque les annonces sont autorisées/diffusées | Publicité ou marketing ; analyses ; prévention de la fraude, sécurité et conformité |
| Informations sur l'application et performances — diagnostics | Temps de lancement, blocages, consommation d'énergie et diagnostics du SDK publicitaire | Oui | Oui | Requise lorsque les annonces sont autorisées/diffusées | Analyses ; prévention de la fraude, sécurité et conformité ; publicité ou marketing |
| Appareil ou autres identifiants | Identifiant publicitaire Android, App Set ID et identifiants apparentés | Oui | Oui | Requise lorsque les annonces sont autorisées/diffusées | Publicité ou marketing ; analyses ; prévention de la fraude, sécurité et conformité |

¹ Firebase Auth et Google Sign-In sont utilisés comme prestataires de service
pour l'authentification. Cette transmission n'est pas déclarée comme un
« partage » si l'exception fournisseur de services de Google Play s'applique à
la configuration contractuelle du compte développeur. Si une donnée est
réutilisée par un destinataire pour ses propres finalités, la déclarer aussi
comme partagée.

### Données à ne pas déclarer comme transmises par BoosterFish

- La position GPS précise reste sur l'appareil : elle sert à centrer la carte,
  calculer les distances et choisir localement la station de prévisions. Elle
  n'est ni envoyée à Open-Meteo ni enregistrée dans Firestore.
- Les coordonnées des spots et des stations sont des données publiques, pas la
  position personnelle de l'utilisateur.
- Aucun mot de passe Google, donnée bancaire, contact, message, donnée de santé,
  fichier personnel ou historique d'achat n'est collecté par l'application.

Les fournisseurs de cartes reçoivent néanmoins les coordonnées des tuiles de la
zone affichée ainsi que des données techniques réseau. Cette information est
décrite dans la politique de confidentialité ; elle doit être réévaluée si un
fournisseur ou un SDK de cartographie est ajouté.

## Autorisations et déclarations

- `INTERNET` : cartes, Firestore, authentification et publicité.
- `ACCESS_COARSE_LOCATION` et `ACCESS_FINE_LOCATION` : uniquement lorsque
  l'utilisateur demande le centrage ou une fonction de proximité ; aucune
  localisation en arrière-plan.
- Ne pas déclarer de localisation en arrière-plan, de caméra, microphone,
  contacts, téléphone, stockage partagé ou notifications : ces autorisations ne
  figurent pas dans le manifeste source.
- Si Play Console demande la justification de la localisation, indiquer :
  « Centrer la carte sur l'utilisateur, calculer la distance aux spots et choisir
  localement la station météo/marine publique la plus proche. La position n'est
  pas stockée dans un profil serveur. »

## Déclarations supplémentaires

- **Identifiant publicitaire : Oui**, utilisé par Google Mobile Ads ; le SDK
  apporte l'autorisation correspondante dans le manifeste fusionné.
- **App d'actualité : Non.**
- **App de santé : Non.**
- **Fonctionnalités financières : Non.**
- **Application gouvernementale : Non.**
- **COVID-19 : Non.**
- **Classement du contenu :** refaire le questionnaire avec la présence de
  publicité et les liens/contacts externes réels.
- **Play Integrity :** non intégré et non obligatoire pour les fonctions
  actuelles ; à envisager seulement si un risque d'abus le justifie.

## Contrôles avant chaque envoi

1. Vérifier que les deux URLs légales publiques répondent sans connexion et
   affichent la même date, les mêmes SDK et la même adresse que les fichiers du
   dépôt.
2. Vérifier que la fiche « Sécurité des données », la déclaration publicitaire
   et le public cible correspondent exactement à cette fiche.
3. Télécharger l'AAB signé correspondant au `versionCode` attendu, puis vérifier
   dans l'App Bundle Explorer les autorisations et SDK détectés.
4. Installer l'APK release sur un appareil propre, refuser puis accepter les
   choix UMP, tester la localisation refusée/acceptée, la connexion et la
   suppression du compte.
5. Consulter les rapports de pré-lancement, Android vitals, ANR et crashs avant
   de promouvoir la version vers une piste plus large.

## Sources officielles

- Google Play — formulaire Sécurité des données :
  <https://support.google.com/googleplay/android-developer/answer/10787469>
- Google Play — suppression de compte :
  <https://support.google.com/googleplay/android-developer/answer/13327111>
- Google Mobile Ads — divulgation des données :
  <https://developers.google.com/admob/android/privacy/play-data-disclosure>
- Firebase Android — divulgation des données :
  <https://firebase.google.com/docs/android/play-data-disclosure>
- Google Play — exigences de niveau d'API cible :
  <https://support.google.com/googleplay/android-developer/answer/11926878>
