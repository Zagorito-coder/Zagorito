# Synchronisation de l'identité publique communautaire

Cette note distingue le déploiement de la synchronisation de photo du
19 septembre 2026 et celui de l'extension du surnom du 22 septembre 2026.
Le déploiement du surnom est terminé ; sa recette sur deux téléphones reste
à valider par l'utilisateur.

## Périmètre

Correction préparée localement le 19 septembre 2026. Le correctif serveur a
été déployé sur Firebase le 19 septembre 2026, sans publication d'une nouvelle
version Google Play.

Périmètre du correctif photo du 19 septembre : synchroniser uniquement les
photos personnelles et les avatars prédéfinis. L'option photo Google conserve
son fonctionnement existant; aucune permission Firebase supplémentaire n'est
ajoutée.

Le profil enregistré dans `community_public_profiles/{uid}` est la source de
la photo choisie. Les publications contiennent une copie de l'avatar : modifier
le profil seul ne modifiait donc pas leurs champs `avatarId` / `avatarUrl`.

Deux fonctions serveur ont été ajoutées :

- `onCommunityPublicProfileWritten` synchronise les publications existantes
  du propriétaire à chaque enregistrement du profil.
- `onCommunityCatchCreated` réconcilie une nouvelle publication, notamment
  lorsqu'un autre appareil utilise encore un profil en cache.

La fiche communautaire ouverte suit désormais le flux de publications au lieu
de conserver uniquement la copie reçue à l'ouverture. Les libellés des quatre
langues expliquent le nouveau comportement.

## Garanties prévues par le code

- Seuls `avatarId` et `avatarUrl` sont modifiés dans les publications.
  Surnom, photo de prise, likes, statut, dates et coordonnées restent inchangés.
- Les publications anonymes restent anonymes. Les anciennes versions sont
  reconnues par le nom réservé `Pêcheur anonyme`; un utilisateur ayant choisi
  ce même surnom est également ignoré par prudence.
- Les nouvelles publications ajoutent un booléen `publishAnonymously`.
  Les règles acceptent toujours les anciens clients sans ce champ. Un client
  ne peut pas modifier l'identité d'une publication existante.
- Les profils restent lisibles uniquement par leur propriétaire. Les règles
  Storage et l'application d'App Check ne sont pas modifiées.
- Seuls la photo personnelle et l'avatar prédéfini sont synchronisés.
  Une photo personnelle doit appartenir au chemin Storage du même UID.
  Le paramètre de version déjà présent dans les URL distingue les photos
  successives, même si elles remplacent le même fichier `avatar.jpg`.
- Lorsque le profil courant choisit `google`, la synchronisation ne modifie
  aucun avatar de publication ni de classement, même si un événement plus
  ancien arrive en retard. Aucun appel Firebase Authentication n'est effectué.
  La connexion Google, le choix de photo Google dans les paramètres et sa
  copie lors d'une nouvelle publication conservent leur fonctionnement.
  Revenir à Google ne remplace donc pas les avatars des anciennes publications;
  choisir ensuite une photo personnelle ou un avatar prédéfini réactive leur
  synchronisation.
- Les transactions traitent au plus 100 publications par lot et relisent le
  profil courant. Un événement ancien ou reçu plusieurs fois ne doit pas
  rétablir un ancien avatar. Aucun document supprimé n'est recréé.
- Les copies d'avatar du classement hebdomadaire sont aussi mises à jour,
  sans changer le classement ni sa date d'annonce. La sélection hebdomadaire
  relit les avatars pour ne pas réintroduire une copie périmée.

La propagation dépend de la connexion et de l'exécution serveur : ce n'est pas
une garantie de rafraîchissement instantané, notamment hors ligne.

## Vérifications et conditions avant déploiement

Résultats locaux du 19 septembre 2026 : analyse Flutter sans problème;
257 tests Flutter réussis, 1 ignoré conditionnellement; 14 tests unitaires
serveur réussis; syntaxe des fichiers JavaScript et `git diff --check` valides.
Après restriction du périmètre excluant Google, la nouvelle exécution sur
émulateur Firestore a réussi : 15 tests de règles et 17 tests d'intégration,
dont le test de non-modification Google. L'émulateur a été arrêté proprement.

Ne pas déployer tant que les tests Firestore sur émulateur n'ont pas réussi.
Ils couvrent les règles, l'anonymat, les autres propriétaires, la pagination,
les événements anciens/dupliqués, les suppressions, les transitions de photo
et le classement. Les tests widget couvrent la fiche ouverte, son retrait et
la récupération après une erreur de flux.

Commandes locales :

```sh
flutter analyze --no-pub
flutter test --no-pub --dart-define-from-file=.env
npm test --prefix firebase_functions
firebase emulators:exec --project demo-boosterfish --only firestore "node firebase_functions/firestore.rules.test.js && node --test firebase_functions/index.emulator.test.js"
```

L'émulateur exige l'ouverture de ports locaux, autorisée séparément. Les tests
utilisent uniquement le projet fictif `demo-boosterfish`.

La consultation IAM en lecture seule a confirmé que le compte de service
`boosterfish-community-runtime@zagorito-9a0c4.iam.gserviceaccount.com` est actif,
avec `roles/datastore.user` et `roles/eventarc.eventReceiver` directement
attribués sans condition. Il n'a pas `firebaseauth.users.get` dans ces rôles;
aucun parent ni membre indirect n'a été identifié. Le diagnostic complémentaire
Policy Troubleshooter a renvoyé une erreur 500, sans essai d'exécution sous
l'identité du compte. Puisque Google est exclu de la nouvelle synchronisation,
cette permission Auth n'est plus nécessaire à cette correction. Aucun droit
n'a été modifié.

## Déploiement Firebase

Déploiement ciblé réalisé le 19 septembre 2026 sur le projet
`zagorito-9a0c4` :

- règles Firestore publiées avec le ruleset
  `projects/zagorito-9a0c4/rulesets/03082449-63d4-4d59-80cd-bad75ca4256a`
  et le hash SHA-256
  `67e0cf10cb997501e1282629607e628f2766d6b244fd5b100a6fce3206e11cc5`;
- `onCommunityPublicProfileWritten` créée et active en `europe-west1`;
- `onCommunityCatchCreated` créée et active en `europe-west1`;
- `selectWeeklyCommunityWinner` mise à jour et active en `europe-west1`.

Les fonctions communautaires non ciblées ont conservé leurs dates de mise à
jour précédentes. Les nouvelles fonctions utilisent le même compte de service
`boosterfish-community-runtime@zagorito-9a0c4.iam.gserviceaccount.com`.

Firebase a confirmé l'application d'App Check à Storage. Aucune règle Storage,
aucun réglage App Check et aucun droit IAM n'ont été modifiés par cette
correction.

Le 21 septembre 2026, les journaux ont révélé que les deux nouveaux services
Cloud Run étaient actifs mais refusaient les invocations Eventarc. Le rôle
`roles/run.invoker` a été accordé **uniquement** sur ces deux services au compte
`boosterfish-community-runtime@zagorito-9a0c4.iam.gserviceaccount.com`.
La stratégie IAM a été relue après écriture. L'utilisateur a ensuite validé
sur deux téléphones que les changements de photo se propagent dans la
communauté. Aucun accès public n'a été ajouté.

## Extension du surnom — déployée, recette manuelle en attente

Préparée le 22 septembre 2026 après constat que le surnom restait ancien sur
la page Communauté. Les publications stockent une copie du nom dans
`anglerName` ; les deux déclencheurs synchronisaient seulement l'avatar.

Le code déployé lit désormais `publicDisplayName` dans le profil **courant** et
met à jour `anglerName` sur les publications non anonymes du propriétaire,
y compris les publications archivées et les copies du classement hebdomadaire.
Une publication créée depuis un appareil au profil périmé est également
réconciliée. La sélection hebdomadaire relit le nom du document de publication
pour éviter de rétablir une copie ancienne. Les transactions restent bornées
à 100 publications par lot et les écritures sont idempotentes.

Le surnom n'est appliqué que si le profil appartient au même UID, qu'il est
non anonyme et que le nom validé compte 2 à 40 caractères. Le nom réservé
`Pêcheur anonyme` est exclu. Les publications anonymes, y compris celles des
anciens clients sans booléen explicite, ne sont jamais renommées. Activer
l'anonymat dans le profil n'anonymise pas rétroactivement une publication déjà
publique. La photo Google, la photo de prise, les likes, le statut, les dates,
les coordonnées et les publications d'un autre compte ne sont pas modifiés.
Une photo Google peut rester sélectionnée pendant que seul le surnom change.

Vérifications locales avant déploiement : 16 tests unitaires backend réussis ;
15 tests de règles et 21 tests d'intégration réussis sur l'émulateur
`demo-boosterfish` ; analyse Flutter sans problème ; 258 tests Flutter réussis,
1 ignoré conditionnellement.

Après validation explicite de l'utilisateur, déploiement ciblé réussi le
22 septembre 2026 sur `zagorito-9a0c4` des trois seules fonctions
`onCommunityPublicProfileWritten`, `onCommunityCatchCreated` et
`selectWeeklyCommunityWinner`. La consultation Firebase après déploiement
confirme leur état `ACTIVE`, leur région `europe-west1`, leur runtime Node.js 22
et le compte de service communautaire attendu. Les stratégies Cloud Run des
deux déclencheurs ont été relues : chacune conserve uniquement le compte
`boosterfish-community-runtime@zagorito-9a0c4.iam.gserviceaccount.com` dans
`roles/run.invoker`. Aucune règle Firestore ou Storage, aucune version Play et
aucun push n'ont été inclus dans ce déploiement. L'outil a signalé que la
version de `firebase-functions` n'est pas la dernière, sans bloquer le
déploiement ; elle n'a pas été modifiée.

Recette manuelle restante sur deux téléphones : changer le surnom du
compte A, fermer et rouvrir la page Communauté sur B et contrôler une ancienne
publication publique ; vérifier qu'une publication anonyme, la photo Google
et la publication du compte B restent inchangées. L'actualisation d'une fiche
déjà ouverte exige la future version de l'application contenant
`LiveCommunityCatchBuilder`.

## Séquence réalisée et limites restantes

1. Les tests locaux, les tests émulateur et la vérification IAM ont réussi.
2. Après autorisation explicite, les règles Firestore compatibles, les deux
   nouveaux déclencheurs et la version modifiée de
   `selectWeeklyCommunityWinner` ont été déployés. Storage et App Check n'ont
   pas été modifiés par le code.
3. Enregistrer à nouveau le profil d'un compte de test déclenche la
   synchronisation de ses anciennes publications. Aucun rattrapage global
   des données de tous les utilisateurs n'est lancé par cette correction.
4. La version 20 existante peut recevoir les champs synchronisés dans son
   flux communautaire. La réactivité d'une fiche déjà ouverte et les nouveaux
   libellés nécessitent une nouvelle version de l'application. Les nouvelles
   règles doivent précéder cette version (nouveau champ d'anonymat).
5. Avant une publication Play, suivre `GOOGLE_PLAY_RELEASE_CHECKLIST.md` et
   les scripts imposés dans `AGENTS.md`. Aucun changement de numéro de
   version, build Release, téléversement ou push n'est inclus ici.

## Recette manuelle photo restant à compléter

Sur deux téléphones connectés avec des comptes distincts, application installée
depuis Google Play :

- Garder visible une publication publique du compte A sur le téléphone B.
- Sur A, changer avatar prédéfini → photo personnelle → autre photo personnelle
  → avatar prédéfini. Vérifier chaque transition sur A et B.
- Choisir ensuite photo Google : vérifier que les anciennes publications ne
  sont pas réécrites et que la photo Google fonctionne toujours dans les
  paramètres et lors d'une nouvelle publication comme auparavant.
- Répéter avec la fiche de la publication laissée ouverte.
- Vérifier qu'une publication anonyme reste sans photo ni identité révélée.
- Vérifier que la photo de prise, les likes et les publications d'un autre
  compte restent inchangés. Si le surnom change, il doit suivre le profil
  public courant sur les publications non anonymes.
- Publier depuis un second appareil dont le profil était en cache et vérifier
  la convergence vers la photo actuelle.
- Contrôler les erreurs des nouveaux déclencheurs et les métriques App Check.

Ne pas annoncer la correction validée en production avant cette recette.
