# Préparation au test interne — BoosterFish 1.0.6 (9)

- État relevé : 2 août 2026
- Branche locale : `fix/production-readiness-2026-08-01`
- Checkpoint de branche avant l'étape IAM : `c3a1cae`
- Version candidate : `1.0.6+9`
- Appareil Profile : Samsung SM A037F, Android 13
- Décision actuelle : **NO-GO pour le téléversement tant que les points ouverts
  ci-dessous ne sont pas fermés.**

Ce document complète l'audit initial du 1 août. Il distingue volontairement
quatre états qui ne doivent jamais être confondus : correction présente dans le
code, preuve locale, déploiement cloud et validation du binaire distribué par
Google Play.

## Résumé des preuves locales actuelles

| Contrôle | Résultat | État |
|---|---:|---|
| `flutter analyze` | aucune erreur | Réussi |
| Suite Flutter complète avec `.env` | 125 réussis, 1 ignoré | Réussi |
| Tests communautaires ciblés après Profil | 5/5 | Réussi |
| Tests unitaires Cloud Functions | 8/8 | Réussi |
| Tests Worker Cloudflare | 20/20 | Réussi |
| Tests Python météo | 11/11 | Réussi avec avertissement Python local 3.9 |
| Format Dart `lib` et `test` | 131 fichiers conformes | Réussi |
| Syntaxe Functions et Worker | valide | Réussi |
| JSON langues, indexes et cycle de vie R2 | valides | Réussi |
| Compilation des règles Firestore | réussie par Firebase | Réussi |
| Règles Firestore de production | déployées sur `zagorito-9a0c4` | Réussi |
| Installation Profile 1.0.6 (9) | catalogue de 6 365 spots validé | Réussi |
| Audit npm des deux backends | 0 vulnérabilité | Réussi localement et dans la CI backend |
| Tests règles Firestore sur émulateur | 8/8 | Réussi localement et dans la CI backend |
| Tests Functions avec émulateur | 7/7 | Réussi |

## État des anciens P0

### P0-01 — Tests Flutter et vol cartographique

**Fermé localement.** Le vol repose sur un plan déterministe testable et la
suite Flutter complète est verte sans suppression des assertions métier. Les
vols restent à inclure dans le parcours Release final.

### P0-02 — Signalements rejouables et compteur non idempotent

**Fermé localement et dans les règles déployées.** Les règles de production
interdisent maintenant la suppression client d'un signalement. Le code
Functions recalcule le compteur à partir des documents existants, supporte les
livraisons dupliquées et possède des tests unitaires et émulateur verts. Les
Functions correspondantes ne sont cependant pas encore déployées.

### P0-03 — Nettoyage des publications et photos

**Partiellement fermé.** Le code local ajoute une file de nettoyage Firestore,
des reprises, des suppressions R2 idempotentes, la remise à zéro du classement
vide et des tâches planifiées. Le Worker utilise `no-store` et une règle de
cycle de vie R2 de secours de 14 jours est préparée. Les Functions, le Worker et
le cycle de vie ne sont pas encore synchronisés avec la production. L'inventaire
R2 et la vérification des tâches doivent précéder l'activation du cycle de vie.

### P0-04 — Avatar arbitraire

**Fermé dans le code et les règles déployées.** Seul l'hôte Google explicitement
autorisé est conservé ; les autres URLs sont refusées ou remplacées par une
valeur vide. La validation du parcours de publication reste obligatoire sur la
candidate Google Play.

### P0-05 — Parité GitHub et données GFS

**Partiellement fermé.** La branche candidate et le commit `485ef8f` sont sur
GitHub. Le job backend de la CI est vert. Le job Flutter est correctement
bloqué parce que le secret GitHub Actions `CSV_ENCRYPTION_KEY` n'est pas encore
configuré. Après résolution, les workflows météo devront être exécutés depuis
le commit approuvé, cinq documents `conditions` contrôlés et les valeurs
pression/pluie/humidité vérifiées sur le téléphone.

### P0-06 — Validation du Release exact

**Ouvert et bloquant avant AAB.** Le Profile a été installé et lancé, mais il ne
valide ni la signature Release, ni Crashlytics Release, ni l'attestation d'une
installation distribuée par Google Play. L'installation Release câblée peut
nécessiter de remplacer l'application Profile signée différemment et donc de
perdre ses données locales. Ce risque doit être traité explicitement avant
toute désinstallation.

## État des anciens P1

| Risque | Code local | Cloud / preuve finale |
|---|---|---|
| App Check des photos personnelles | Client et Worker corrigés, tests verts | Worker à déployer après stratégie de compatibilité des anciennes versions |
| Rafraîchissements Overpass | TTL 14 jours, requête unique en vol et budget réseau | À observer en Release/réseau lent |
| Animation du vent | suspension sur mouvements, cadence adaptative et tests | profilage Release final requis |
| Paramètres/accessibilité | page défilable, cibles tactiles et tests statiques | TalkBack, 200 %, paysage et quatre langues à valider manuellement |
| Police distante | dépendance `google_fonts` supprimée ; police système locale | fermé, aucune requête de police réseau |
| CI mobile | workflow local présent | à committer, pousser et exécuter avec secret GitHub protégé |
| Identité Functions au moindre privilège | compte dédié créé et déclaré dans les 7 Functions, test 8/8 | activation au prochain déploiement contrôlé ; les Functions actuelles utilisent encore le compte par défaut |
| Suppression de compte reprenable | logique locale renforcée et recalcul des agrégats | émulateur, déploiement Functions et test réel à terminer |

## Fonction Profil ajoutée après l'audit

- Le pêcheur choisit anonymat ou surnom public sans modifier son compte Google.
- Le document `community_public_profiles/{uid}` est privé et limité au
  propriétaire par les règles déployées.
- Le choix ne modifie que les publications futures.
- L'indicateur vert de Paramètres disparaît après un choix réellement enregistré
  et reste masqué après redémarrage grâce à l'existence du document cloud.
- La suppression de compte efface ce document dans le code Functions local ; ce
  nettoyage sera actif après le déploiement contrôlé des Functions.

## Ordre obligatoire restant

1. ~~Terminer l'audit npm en ligne.~~ Réussi : aucune vulnérabilité détectée
   dans les deux projets Node.
2. ~~Revoir le diff complet, exclure `spots_app_temp` et tout secret, puis créer
   un checkpoint cohérent sur la branche de préparation.~~ Réalisé dans
   `485ef8f`; les deux rapports locaux et `spots_app_temp` restent exclus.
3. ~~Obtenir l'autorisation ciblée de pousser cette branche.~~ La branche est
   publiée sur GitHub au commit `485ef8f`. Le job backend de la CI est vert. Le
   job Flutter s'arrête volontairement avant les tests car le secret Actions
   `CSV_ENCRYPTION_KEY` n'est pas encore configuré ; aucun secret n'est écrit
   dans le dépôt.
4. ~~Fermer la parité GFS GitHub/Firestore/téléphone.~~ Le correctif limité est
   intégré dans `origin/main`, le workflow manuel a écrit les cinq résumés GFS
   et pression/pluie/humidité ont été validées sur le téléphone.
5. ~~Définir et valider l'identité Functions au moindre privilège.~~ Le compte
   `boosterfish-community-runtime` existe sans clé privée ni rôle Editor. Il a
   uniquement `datastore.user`, `eventarc.eventReceiver`, l'accès au seul
   secret communautaire et l'invocation ciblée des services concernés. Les
   sept définitions locales imposent cette identité et un test l'interdit au
   compte par défaut. La bascule effective reste attachée à l'étape 6.
6. Déployer atomiquement les Functions nécessaires et vérifier leurs révisions.
7. Organiser le déploiement Worker sans casser les anciennes installations,
   puis vérifier R2 et seulement ensuite son cycle de vie de secours.
8. Protéger les données locales du téléphone, installer le Release exact avec
   `tools/run_app.sh --release`, puis exécuter toute la checklist manuelle.
9. Après validation manuelle explicite, générer l'AAB avec
   `tools/build_release.sh` et calculer ses preuves.
10. Téléverser en test interne uniquement après autorisation, réinstaller depuis
    Google Play et retester App Check, publication, like, signalement, blocage,
    retrait, suppression de compte, Crashlytics, ANR et Vitals.
11. Concevoir le formulaire de première utilisation en dernière tâche produit,
    puis recommencer les contrôles affectés avant toute promotion Production.

## Conclusion actuelle

La candidate est nettement plus proche du test interne, mais elle n'est pas
encore déclarée prête. Aucun AAB ne doit être généré ou téléversé sur la base des
seules validations Profile. La prochaine preuve technique à obtenir est la
réussite des tests émulateur et de l'audit npm, suivie de la revue/CI de la
branche courante.
