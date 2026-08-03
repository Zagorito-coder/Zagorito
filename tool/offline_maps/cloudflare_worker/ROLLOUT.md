# Déploiement contrôlé du Worker

Ce Worker doit rester compatible avec les installations Play existantes pendant
la migration App Check des photos de spots personnels.

## Compatibilité des routes

- `/spot-photos/<clé>` reste temporairement disponible pour BoosterFish 1.0.2.
  Les mutations exigent toujours un jeton Firebase Auth valide.
- `/spot-photos-v2/<clé>` est utilisé par BoosterFish 1.0.6 et exige Firebase
  Auth ainsi qu'un jeton Firebase App Check valide pour `PUT` et `DELETE`.
- Les deux routes lisent et écrivent le même bucket et la même clé R2. Aucune
  migration des photos existantes n'est nécessaire.
- La route historique ne doit être retirée qu'après confirmation que 1.0.2 ne
  fait plus partie des versions prises en charge.

## Contrôles avant déploiement

Depuis la racine du dépôt :

```sh
node --test tool/offline_maps/cloudflare_worker/test/worker_test.mjs
flutter test --dart-define-from-file=.env test/user_spot_app_check_test.dart
flutter analyze
```

Depuis ce dossier :

```sh
npx --yes wrangler@latest versions upload --dry-run --config wrangler.jsonc
npx --yes wrangler@latest secret list --config wrangler.jsonc --format json
npx --yes wrangler@latest r2 bucket lifecycle list boosterfish-community-photos --config wrangler.jsonc
```

Le secret `COMMUNITY_ADMIN_KEY` et les trois bindings R2 doivent être présents.

## Déploiement réversible

Créer d'abord une version sans lui envoyer de trafic :

```sh
npx --yes wrangler@latest versions upload --strict --config wrangler.jsonc --message "BoosterFish 1.0.6 App Check migration"
```

Après vérification de la version créée, la basculer explicitement à 100 % :

```sh
npx --yes wrangler@latest versions deploy <nouvelle-version>@100% --config wrangler.jsonc --message "BoosterFish 1.0.6"
```

En cas d'échec des contrôles, remettre immédiatement la version précédente :

```sh
npx --yes wrangler@latest versions deploy <version-précédente>@100% --config wrangler.jsonc --message "Rollback BoosterFish"
```

## Cycle de vie R2

Le cycle de vie est appliqué seulement après les tests distants du Worker. Le
fichier conserve l'abandon des uploads multipartiels incomplets après 7 jours
et ajoute l'expiration de secours des photos communautaires après 14 jours :

```sh
npx --yes wrangler@latest r2 bucket lifecycle set boosterfish-community-photos --config wrangler.jsonc --file community_photos_lifecycle.json
npx --yes wrangler@latest r2 bucket lifecycle list boosterfish-community-photos --config wrangler.jsonc
```

Cette dernière commande est une mutation différée des données : elle ne doit
jamais être exécutée sans autorisation explicite et sans vérifier ensuite que
les deux règles sont actives.
